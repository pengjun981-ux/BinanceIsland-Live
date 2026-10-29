import Foundation
import SwiftUI
import UIKit

@MainActor
final class PriceStore: ObservableObject {
    // Persisted settings
    @Published var symbols: [String] { didSet { save(); restart() } }
    @Published var islandSymbol: String { didSet { save(); activity.switchSymbol(to: islandSymbol, ticker: tickers[islandSymbol], redUp: redUp) } }
    @Published var host: BinanceHost { didSet { save(); restart() } }
    @Published var redUp: Bool { didSet { save(); activity.switchSymbol(to: islandSymbol, ticker: tickers[islandSymbol], redUp: redUp, force: true) } }

    // Runtime
    @Published private(set) var tickers: [String: Ticker] = [:]
    @Published private(set) var connectionStatus: String = "未连接"

    let activity = LiveActivityManager()

    private var wsTask: URLSessionWebSocketTask?
    private var pollTask: Task<Void, Never>?
    private var receiveTask: Task<Void, Never>?
    private var wsFailures = 0
    private var bgTask: UIBackgroundTaskIdentifier = .invalid
    private let session = URLSession(configuration: .default)
    private let defaults = UserDefaults.standard

    init() {
        let d = UserDefaults.standard
        let syms = d.stringArray(forKey: "symbols") ?? ["BTCUSDT", "ETHUSDT"]
        symbols = syms.isEmpty ? ["BTCUSDT", "ETHUSDT"] : syms
        islandSymbol = d.string(forKey: "islandSymbol") ?? syms.first ?? "BTCUSDT"
        host = BinanceHost(rawValue: d.string(forKey: "host") ?? "") ?? .global
        redUp = d.object(forKey: "redUp") as? Bool ?? true
        activity.restoreExisting()
        start()
    }

    private func save() {
        defaults.set(symbols, forKey: "symbols")
        defaults.set(islandSymbol, forKey: "islandSymbol")
        defaults.set(host.rawValue, forKey: "host")
        defaults.set(redUp, forKey: "redUp")
    }

    // MARK: symbols
    func addSymbol(_ raw: String) {
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased().replacingOccurrences(of: "/", with: "")
        guard !s.isEmpty, s.allSatisfy({ $0.isLetter || $0.isNumber }), !symbols.contains(s) else { return }
        symbols.append(s)
    }

    func removeSymbols(at offsets: IndexSet) {
        var copy = symbols
        copy.remove(atOffsets: offsets)
        if copy.isEmpty { return }
        symbols = copy
        if !symbols.contains(islandSymbol), let f = symbols.first { islandSymbol = f }
    }

    // MARK: connection lifecycle
    func start() {
        stop()
        wsFailures = 0
        connectWebSocket()
    }

    func restart() { start() }

    func stop() {
        receiveTask?.cancel(); receiveTask = nil
        wsTask?.cancel(with: .goingAway, reason: nil); wsTask = nil
        pollTask?.cancel(); pollTask = nil
    }

    private func connectWebSocket() {
        let streams = symbols.map { "\($0.lowercased())@miniTicker" }.joined(separator: "/")
        guard let url = URL(string: "\(host.wsBase)/stream?streams=\(streams)") else { startPolling(); return }
        let task = session.webSocketTask(with: url)
        wsTask = task
        task.resume()
        connectionStatus = "WebSocket 连接中…"
        receiveTask = Task { [weak self] in
            await self?.receiveLoop(task)
        }
    }

    private func receiveLoop(_ task: URLSessionWebSocketTask) async {
        let decoder = JSONDecoder()
        while !Task.isCancelled {
            do {
                let msg = try await task.receive()
                let data: Data?
                switch msg {
                case .string(let s): data = s.data(using: .utf8)
                case .data(let d): data = d
                @unknown default: data = nil
                }
                if let data, let m = try? decoder.decode(CombinedStreamMessage.self, from: data), let t = m.data.ticker {
                    wsFailures = 0
                    connectionStatus = "WebSocket 实时 · \(host.rawValue)"
                    apply(t)
                }
            } catch {
                if Task.isCancelled || wsTask !== task { return }
                wsFailures += 1
                connectionStatus = "WebSocket 断开，切换 REST 轮询"
                wsTask = nil
                startPolling()
                return
            }
        }
    }

    private func startPolling() {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            var round = 0
            while !Task.isCancelled {
                guard let self else { return }
                await self.pollOnce()
                round += 1
                // every ~30s try WebSocket again
                if round % 15 == 0 && self.wsTask == nil {
                    self.connectWebSocket()
                }
                try? await Task.sleep(nanoseconds: 2_000_000_000)
            }
        }
    }

    private func pollOnce() async {
        let syms = symbols
        let base = host.restBase
        var ok = false
        await withTaskGroup(of: Ticker?.self) { group in
            for s in syms {
                group.addTask { [session] in
                    guard let url = URL(string: "\(base)/api/v3/ticker/24hr?symbol=\(s)") else { return nil }
                    guard let (data, resp) = try? await session.data(from: url),
                          (resp as? HTTPURLResponse)?.statusCode == 200,
                          let r = try? JSONDecoder().decode(RestTicker24h.self, from: data) else { return nil }
                    return r.ticker
                }
            }
            for await t in group {
                if let t { apply(t); ok = true }
            }
        }
        if wsTask == nil {
            connectionStatus = ok ? "REST 轮询 (2秒) · \(host.rawValue)" : "请求失败，请在设置中切换数据源"
        }
    }

    private func apply(_ t: Ticker) {
        tickers[t.symbol] = t
        if t.symbol == islandSymbol {
            activity.push(t, redUp: redUp)
        }
    }

    // MARK: Live Activity
    func startActivity() {
        let sym = islandSymbol
        if let t = tickers[sym] {
            activity.start(symbol: sym, ticker: t, redUp: redUp)
            return
        }
        Task {
            let t = await fetchREST(sym)
            if let t { tickers[sym] = t }
            activity.start(symbol: sym, ticker: t, redUp: redUp)
        }
    }

    private func fetchREST(_ s: String) async -> Ticker? {
        guard let url = URL(string: "\(host.restBase)/api/v3/ticker/24hr?symbol=\(s)"),
              let (data, resp) = try? await session.data(from: url),
              (resp as? HTTPURLResponse)?.statusCode == 200,
              let r = try? JSONDecoder().decode(RestTicker24h.self, from: data) else { return nil }
        return r.ticker
    }

    func stopActivity() {
        activity.endAll()
    }

    // MARK: Scene / background
    func handleScenePhase(_ phase: ScenePhase) {
        switch phase {
        case .active:
            endBackgroundTask()
            if wsTask == nil && pollTask == nil { start() }
        case .background:
            // iOS 只给有限的后台时间（通常约 30 秒）。之后应用挂起，实时更新需 APNs 推送。
            beginBackgroundTask()
        default:
            break
        }
    }

    private func beginBackgroundTask() {
        guard bgTask == .invalid else { return }
        bgTask = UIApplication.shared.beginBackgroundTask(withName: "PriceStream") { [weak self] in
            Task { @MainActor in
                self?.stop()
                self?.endBackgroundTask()
            }
        }
    }

    private func endBackgroundTask() {
        guard bgTask != .invalid else { return }
        UIApplication.shared.endBackgroundTask(bgTask)
        bgTask = .invalid
    }
}

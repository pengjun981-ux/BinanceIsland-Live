import Foundation
import ActivityKit

@MainActor
final class LiveActivityManager: ObservableObject {
    @Published private(set) var isRunning = false
    @Published var lastError: String?

    private var current: Activity<PriceActivityAttributes>?
    private var pending: PriceActivityAttributes.ContentState?
    private var lastSent: Date = .distantPast
    private var flushTask: Task<Void, Never>?
    private let minInterval: TimeInterval = 1.0

    var enabled: Bool { ActivityAuthorizationInfo().areActivitiesEnabled }

    func restoreExisting() {
        current = Activity<PriceActivityAttributes>.activities.first
        isRunning = current != nil
    }

    private func state(from t: Ticker?) -> PriceActivityAttributes.ContentState {
        PriceActivityAttributes.ContentState(
            price: t?.price ?? 0, changePercent: t?.changePercent ?? 0,
            high: t?.high ?? 0, low: t?.low ?? 0, updatedAt: t?.updatedAt ?? Date())
    }

    private func content(_ s: PriceActivityAttributes.ContentState) -> ActivityContent<PriceActivityAttributes.ContentState> {
        ActivityContent(state: s, staleDate: Date().addingTimeInterval(60))
    }

    func start(symbol: String, ticker: Ticker?, redUp: Bool) {
        guard enabled else {
            lastError = "实时活动未开启：设置 → 本应用 → 实时活动"
            return
        }
        let attrs = PriceActivityAttributes(symbol: symbol, redUp: redUp)
        let s = state(from: ticker)
        Task {
            await endAllAsync()
            do {
                current = try Activity.request(attributes: attrs, content: content(s), pushType: nil)
                isRunning = true
                lastError = nil
                lastSent = Date()
            } catch {
                lastError = "启动失败：\(error.localizedDescription)"
                isRunning = false
            }
        }
    }

    /// Attributes are immutable, so switching symbol / color convention restarts the activity.
    func switchSymbol(to symbol: String, ticker: Ticker?, redUp: Bool, force: Bool = false) {
        guard let current else { return }
        if force || current.attributes.symbol != symbol || current.attributes.redUp != redUp {
            start(symbol: symbol, ticker: ticker, redUp: redUp)
        }
    }

    /// Throttled to ~1 update / second.
    func push(_ t: Ticker, redUp: Bool) {
        guard let current, current.attributes.symbol == t.symbol else { return }
        pending = state(from: t)
        let elapsed = Date().timeIntervalSince(lastSent)
        if elapsed >= minInterval {
            flush()
        } else if flushTask == nil {
            let wait = minInterval - elapsed
            flushTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(wait * 1_000_000_000))
                self?.flushTask = nil
                self?.flush()
            }
        }
    }

    private func flush() {
        guard let current, let s = pending else { return }
        pending = nil
        lastSent = Date()
        let c = content(s)
        Task { await current.update(c) }
    }

    func endAll() {
        Task { await endAllAsync() }
    }

    private func endAllAsync() async {
        flushTask?.cancel(); flushTask = nil
        for a in Activity<PriceActivityAttributes>.activities {
            await a.end(nil, dismissalPolicy: .immediate)
        }
        current = nil
        isRunning = false
    }
}

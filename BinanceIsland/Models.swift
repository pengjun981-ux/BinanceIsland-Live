import Foundation

struct Ticker: Equatable {
    var symbol: String
    var price: Double
    var changePercent: Double
    var high: Double
    var low: Double
    var updatedAt: Date
}

enum BinanceHost: String, CaseIterable, Identifiable {
    case global = "binance.com"
    case vision = "data-api.binance.vision"
    case us = "binance.us"
    var id: String { rawValue }

    var restBase: String {
        switch self {
        case .global: return "https://api.binance.com"
        case .vision: return "https://data-api.binance.vision"
        case .us: return "https://api.binance.us"
        }
    }
    var wsBase: String {
        switch self {
        case .global: return "wss://stream.binance.com:9443"
        case .vision: return "wss://data-stream.binance.vision"
        case .us: return "wss://stream.binance.us:9443"
        }
    }
    var label: String {
        switch self {
        case .global: return "币安国际 (binance.com)"
        case .vision: return "公共数据 (binance.vision)"
        case .us: return "币安美国 (binance.us)"
        }
    }
}

// MARK: - JSON
struct CombinedStreamMessage: Decodable {
    let stream: String
    let data: MiniTicker
}

struct MiniTicker: Decodable {
    let s: String  // symbol
    let c: String  // close
    let o: String  // open
    let h: String
    let l: String

    var ticker: Ticker? {
        guard let c = Double(c), let o = Double(o), let h = Double(h), let l = Double(l) else { return nil }
        let pct = o == 0 ? 0 : (c - o) / o * 100
        return Ticker(symbol: s, price: c, changePercent: pct, high: h, low: l, updatedAt: Date())
    }
}

struct RestTicker24h: Decodable {
    let symbol: String
    let lastPrice: String
    let priceChangePercent: String
    let highPrice: String
    let lowPrice: String

    var ticker: Ticker? {
        guard let p = Double(lastPrice), let c = Double(priceChangePercent),
              let h = Double(highPrice), let l = Double(lowPrice) else { return nil }
        return Ticker(symbol: symbol, price: p, changePercent: c, high: h, low: l, updatedAt: Date())
    }
}

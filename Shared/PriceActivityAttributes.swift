import Foundation
import ActivityKit

public struct PriceActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var price: Double
        public var changePercent: Double
        public var high: Double
        public var low: Double
        public var updatedAt: Date
    }
    /// e.g. "BTCUSDT"
    public var symbol: String
    /// true = 中国习惯 红涨绿跌
    public var redUp: Bool
}

public enum PriceFormat {
    public static func base(_ symbol: String) -> String {
        for q in ["USDT", "FDUSD", "USDC", "BUSD", "USD", "BTC", "ETH", "BNB"] where symbol.hasSuffix(q) && symbol.count > q.count {
            return String(symbol.dropLast(q.count))
        }
        return symbol
    }
    public static func price(_ p: Double) -> String {
        let digits: Int = p >= 1000 ? 2 : (p >= 1 ? 3 : (p >= 0.01 ? 5 : 8))
        return String(format: "%.\(digits)f", p)
    }
    public static func short(_ p: Double) -> String {
        if p >= 100_000 { return String(format: "%.0fk", p / 1000) }
        if p >= 10_000 { return String(format: "%.1fk", p / 1000) }
        if p >= 100 { return String(format: "%.0f", p) }
        if p >= 1 { return String(format: "%.2f", p) }
        return String(format: "%.4f", p)
    }
    public static func percent(_ c: Double) -> String {
        String(format: "%@%.2f%%", c >= 0 ? "+" : "", c)
    }
}

import ActivityKit
import WidgetKit
import SwiftUI

private func tint(_ change: Double, redUp: Bool) -> Color {
    if change == 0 { return .white }
    let up = change > 0
    return (up == redUp) ? .red : .green
}

private struct CoinIcon: View {
    let symbol: String
    var body: some View {
        let b = PriceFormat.base(symbol)
        ZStack {
            Circle().fill(Color.orange)
            Text(String(b.prefix(1))).font(.system(size: 9, weight: .bold)).foregroundColor(.black)
        }
        .frame(width: 14, height: 14)
    }
}

struct PriceLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PriceActivityAttributes.self) { context in
            LockScreenView(attributes: context.attributes, state: context.state)
                .activityBackgroundTint(Color.black.opacity(0.85))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            let s = context.state
            let a = context.attributes
            let color = tint(s.changePercent, redUp: a.redUp)
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 4) {
                        CoinIcon(symbol: a.symbol)
                        Text(PriceFormat.base(a.symbol)).font(.headline)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(PriceFormat.percent(s.changePercent))
                        .font(.headline).foregroundColor(color)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(PriceFormat.price(s.price))
                        .font(.title2.monospacedDigit()).bold().foregroundColor(color)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Text("高 \(PriceFormat.price(s.high))")
                        Spacer()
                        Text("低 \(PriceFormat.price(s.low))")
                        Spacer()
                        Text(s.updatedAt, style: .time)
                    }
                    .font(.caption.monospacedDigit()).foregroundColor(.secondary)
                }
            } compactLeading: {
                HStack(spacing: 3) {
                    CoinIcon(symbol: a.symbol)
                    Text(PriceFormat.base(a.symbol)).font(.caption2).bold()
                }
            } compactTrailing: {
                Text(PriceFormat.price(s.price))
                    .font(.caption2.monospacedDigit()).bold().foregroundColor(color)
            } minimal: {
                Text(PriceFormat.short(s.price))
                    .font(.system(size: 10).monospacedDigit()).foregroundColor(color)
                    .minimumScaleFactor(0.5)
            }
        }
    }
}

struct LockScreenView: View {
    let attributes: PriceActivityAttributes
    let state: PriceActivityAttributes.ContentState
    var body: some View {
        let color = tint(state.changePercent, redUp: attributes.redUp)
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    CoinIcon(symbol: attributes.symbol)
                    Text(attributes.symbol).font(.headline).foregroundColor(.white)
                }
                Text("高 \(PriceFormat.price(state.high))  低 \(PriceFormat.price(state.low))")
                    .font(.caption.monospacedDigit()).foregroundColor(.gray)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(PriceFormat.price(state.price))
                    .font(.title2.monospacedDigit()).bold().foregroundColor(color)
                Text(PriceFormat.percent(state.changePercent))
                    .font(.caption.monospacedDigit()).foregroundColor(color)
            }
        }
        .padding()
    }
}

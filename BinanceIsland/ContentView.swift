import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: PriceStore
    @State private var newSymbol = ""

    var body: some View {
        NavigationView {
            Form {
                Section("灵动岛 / 锁屏实时活动") {
                    Picker("显示交易对", selection: $store.islandSymbol) {
                        ForEach(store.symbols, id: \.self) { Text($0).tag($0) }
                    }
                    ActivityButtons(manager: store.activity, store: store)
                }

                Section {
                    ForEach(store.symbols, id: \.self) { s in
                        PriceRow(symbol: s, ticker: store.tickers[s], redUp: store.redUp,
                                 selected: s == store.islandSymbol)
                            .contentShape(Rectangle())
                            .onTapGesture { store.islandSymbol = s }
                    }
                    .onDelete { store.removeSymbols(at: $0) }
                    HStack {
                        TextField("添加交易对，如 SOLUSDT", text: $newSymbol)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .onSubmit(add)
                        Button("添加", action: add).disabled(newSymbol.isEmpty)
                    }
                } header: {
                    Text("实时价格")
                } footer: {
                    Text(store.connectionStatus)
                }

                Section("设置") {
                    Picker("数据源", selection: $store.host) {
                        ForEach(BinanceHost.allCases) { Text($0.label).tag($0) }
                    }
                    Toggle("红涨绿跌（中国习惯）", isOn: $store.redUp)
                    Button("重新连接") { store.restart() }
                }

                Section {
                    Text("提示：应用切到后台约 30 秒后会被系统挂起，灵动岛价格将停止更新（显示为过期）。回到应用即恢复。持续后台更新需要 APNs 推送服务器。")
                        .font(.footnote).foregroundColor(.secondary)
                }
            }
            .navigationTitle("币安灵动岛")
        }
        .navigationViewStyle(.stack)
    }

    private func add() {
        store.addSymbol(newSymbol)
        newSymbol = ""
    }
}

private struct ActivityButtons: View {
    @ObservedObject var manager: LiveActivityManager
    let store: PriceStore
    var body: some View {
        HStack {
            Button("开始") { store.startActivity() }
                .buttonStyle(.borderedProminent)
            Button("停止") { store.stopActivity() }
                .buttonStyle(.bordered).tint(.red)
            Spacer()
            Text(manager.isRunning ? "运行中" : "未运行")
                .foregroundColor(manager.isRunning ? .green : .secondary)
        }
        if let e = manager.lastError {
            Text(e).font(.footnote).foregroundColor(.red)
        }
    }
}

private struct PriceRow: View {
    let symbol: String
    let ticker: Ticker?
    let redUp: Bool
    let selected: Bool
    var body: some View {
        let ch = ticker?.changePercent ?? 0
        let color: Color = ch == 0 ? .primary : ((ch > 0) == redUp ? .red : .green)
        HStack {
            Image(systemName: selected ? "largecircle.fill.circle" : "circle")
                .foregroundColor(selected ? .orange : .secondary)
            VStack(alignment: .leading) {
                Text(PriceFormat.base(symbol)).font(.headline)
                Text(symbol).font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing) {
                Text(ticker.map { PriceFormat.price($0.price) } ?? "--")
                    .font(.body.monospacedDigit()).bold().foregroundColor(color)
                Text(ticker.map { PriceFormat.percent($0.changePercent) } ?? "")
                    .font(.caption.monospacedDigit()).foregroundColor(color)
            }
        }
    }
}

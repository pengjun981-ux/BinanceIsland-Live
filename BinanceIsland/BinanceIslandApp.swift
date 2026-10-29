import SwiftUI

@main
struct BinanceIslandApp: App {
    @StateObject private var store = PriceStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView().environmentObject(store)
        }
        .onChange(of: scenePhase) { phase in
            store.handleScenePhase(phase)
        }
    }
}

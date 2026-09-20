import SwiftUI

@main
struct SkyPlateApp: App {
    @StateObject private var store = FlightStore()
    @Environment(\.scenePhase) private var phase
    var body: some Scene {
        WindowGroup {
            ContentView(store: store)
                .preferredColorScheme(.dark)
                .onAppear { store.start() }
                .onChange(of: phase) { _, phase in
                    // Permission dialogs temporarily make the scene inactive.
                    // Keep the request alive until the app actually backgrounds.
                    if phase == .active { store.start() }
                    else if phase == .background { store.stop() }
                }
        }
    }
}

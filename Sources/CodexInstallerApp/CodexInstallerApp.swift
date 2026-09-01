import SwiftUI

@main
struct CodexInstallerHelperApp: App {
    @StateObject private var viewModel = InstallerViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: viewModel)
        }
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}

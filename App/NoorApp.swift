import DesignSystem
import SwiftUI

@main
struct NoorApp: App {
    init() {
        FontRegistrar.registerQuranFont()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

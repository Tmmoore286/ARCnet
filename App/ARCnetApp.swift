import Foundation
import SwiftUI

@main
struct ARCnetApp: App {
    var body: some Scene {
        WindowGroup {
            MissionInputView(viewModel: MissionInputViewModel())
        }
    }
}

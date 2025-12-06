import SwiftUI

struct MissionInputView: View {
    @StateObject var viewModel: MissionInputViewModel

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("ARCnet")
                    .font(.largeTitle)
                TextField("Enter mission statement", text: $viewModel.missionStatement, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                Button("Start Mission") {
                    Task { await viewModel.start() }
                }
                if let cp = viewModel.lastCheckpoint {
                    Divider()
                    Text("Last Checkpoint: \(cp.stage) — \(cp.summary)")
                        .font(.callout)
                }
                Spacer()
            }
            .padding()
        }
    }
}

#if DEBUG
struct MissionInputView_Previews: PreviewProvider {
    static var previews: some View {
        MissionInputView(viewModel: MissionInputViewModel())
    }
}
#endif

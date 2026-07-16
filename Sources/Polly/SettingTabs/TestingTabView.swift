import SwiftUI

struct TestingTabView: View {
  @ObservedObject var viewModel: SettingsViewModel

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("testing.instruction".localized(viewModel.hotkey.display))
        .font(.subheadline)
        .foregroundColor(.secondary)

      TextEditor(text: $viewModel.testText)
        .font(.body)
        .frame(minHeight: 200)
    }
    .padding(20)
  }
}

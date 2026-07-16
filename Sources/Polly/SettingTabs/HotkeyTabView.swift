import SwiftUI

struct HotkeyTabView: View {
  @ObservedObject var viewModel: SettingsViewModel

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("hotkey.current".localized)
        .font(.headline)

      Text(viewModel.hotkey.display)
        .font(.system(size: 28, weight: .semibold))

      if !viewModel.hotkeyError.isEmpty {
        Text(viewModel.hotkeyError)
          .foregroundColor(.red)
      }

      HStack(spacing: 12) {
        Button(viewModel.isRecordingHotkey ? "hotkey.button.recording".localized : "hotkey.button.record".localized) {
          if viewModel.isRecordingHotkey {
            viewModel.stopRecordingHotkey()
          } else {
            viewModel.startRecordingHotkey()
          }
        }
        .buttonStyle(.borderedProminent)

        Button("hotkey.button.reset".localized) {
          viewModel.applyHotkey(Hotkey.default())
        }
      }

      Text("hotkey.instruction".localized)
        .font(.subheadline)
        .foregroundColor(.secondary)

      Spacer()
    }
    .padding(20)
    .frame(minHeight: 300)
  }
}

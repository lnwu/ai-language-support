import SwiftUI

struct PermissionsTabView: View {
  @ObservedObject var viewModel: SettingsViewModel

  var body: some View {
    VStack(spacing: 20) {
      Spacer()

      Image(systemName: viewModel.isTrusted ? "checkmark.shield.fill" : "lock.shield")
        .font(.system(size: 48))
        .foregroundColor(viewModel.isTrusted ? .green : .secondary)

      Text(viewModel.isTrusted ? "permission.granted".localized : "permission.required".localized)
        .font(.headline)

      Text(viewModel.isTrusted
        ? "permission.description.granted".localized
        : "permission.description.required".localized)
        .font(.subheadline)
        .foregroundColor(.secondary)
        .multilineTextAlignment(.center)
        .frame(maxWidth: 320)

      if !viewModel.isTrusted {
        Button(action: {
          viewModel.permissionManager.requestAccess()
        }) {
          Text("permission.button.request".localized)
            .frame(maxWidth: 200)
        }
        .controlSize(.large)
        .buttonStyle(.borderedProminent)
        .padding(.top, 16)
      }

      Spacer()
    }
    .frame(maxWidth: .infinity)
    .padding(20)
  }
}

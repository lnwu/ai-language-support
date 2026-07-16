import SwiftUI

struct GeneralTabView: View {
  @ObservedObject var viewModel: SettingsViewModel

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Form {
        Section("section.api".localized) {
          Picker("field.provider".localized, selection: $viewModel.apiProvider) {
            ForEach(APIProvider.allCases, id: \.self) { provider in
              Text(provider.displayName).tag(provider)
            }
          }

          SecureField("field.api_key".localized, text: $viewModel.apiKey)
          Text("info.keychain".localized)
            .font(.caption)
            .foregroundColor(.secondary)
          
          HStack {
            Picker("field.model".localized, selection: $viewModel.modelName) {
              ForEach(viewModel.models, id: \.self) { model in
                Text(model).tag(model)
              }
            }
            .disabled(viewModel.models.isEmpty)
            
            Button {
              viewModel.refreshModels()
            } label: {
              Image(systemName: "arrow.clockwise")
                .rotationEffect(.degrees(viewModel.isLoadingModels ? 360 : 0))
                .animation(
                  viewModel.isLoadingModels 
                    ? .linear(duration: 1).repeatForever(autoreverses: false)
                    : .default,
                  value: viewModel.isLoadingModels
                )
            }
            .disabled(viewModel.isLoadingModels)
            .help("button.refresh_models".localized)
          }
        }
        if !viewModel.errorText.isEmpty {
          Text(viewModel.errorText)
            .foregroundColor(.red)
        }
      }
    }
    .padding(20)
  }
}

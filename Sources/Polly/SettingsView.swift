import SwiftUI

@MainActor
struct SettingsView: View {
  @State private var selectedTab: SettingsTab = .permissions
  @StateObject private var viewModel = SettingsViewModel()

  var body: some View {
    TabView(selection: $selectedTab) {
      PermissionsTabView(viewModel: viewModel)
        .tabItem {
          Label("tab.permissions".localized, systemImage: "hand.raised.fill")
        }
        .tag(SettingsTab.permissions)

      GeneralTabView(viewModel: viewModel)
        .tabItem {
          Label("tab.general".localized, systemImage: "gearshape")
        }
        .tag(SettingsTab.general)

      TestingTabView(viewModel: viewModel)
        .tabItem {
          Label("tab.testing".localized, systemImage: "play.circle")
        }
        .tag(SettingsTab.testing)

      LogsTabView()
        .tabItem {
          Label("tab.logs".localized, systemImage: "doc.text")
        }
        .tag(SettingsTab.logs)

      HotkeyTabView(viewModel: viewModel)
        .tabItem {
          Label("tab.hotkey".localized, systemImage: "keyboard")
        }
        .tag(SettingsTab.hotkey)
    }
    .frame(width: 640, height: 520)
    .onAppear {
      viewModel.loadSettingsIfNeeded()
      viewModel.refreshPermissionStatus()
      viewModel.startPermissionPolling()
    }
    .onDisappear {
      viewModel.stopRecordingHotkey()
      viewModel.stopPermissionPolling()
    }
    .onChange(of: selectedTab) { _, newValue in
      if newValue == .permissions {
        viewModel.refreshPermissionStatus()
      }
    }
    .onChange(of: viewModel.apiBase) { _, _ in
      viewModel.scheduleModelsFetchIfNeeded()
      viewModel.persistCurrentConfig()
    }
    .onChange(of: viewModel.apiKey) { _, _ in
      viewModel.scheduleModelsFetchIfNeeded()
      viewModel.persistCurrentConfig()
    }
    .onChange(of: viewModel.modelName) { _, _ in
      viewModel.persistCurrentConfig()
    }
  }
}

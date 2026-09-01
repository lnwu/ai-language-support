import SwiftUI

@MainActor
struct LogsTabView: View {
  @State private var entries: [APILogEntry] = []
  @State private var appEntries: [AppLogEntry] = []
  @State private var expandedIds: Set<UUID> = []
  @State private var selectedLogType: LogType = .app
  @State private var appOnlyErrors = false

  private let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm:ss"
    return formatter
  }()

  var body: some View {
    VStack(spacing: 12) {
      HStack {
        Picker("logs.type.app".localized, selection: $selectedLogType) {
          Text("logs.type.app".localized).tag(LogType.app)
          Text("logs.type.api".localized).tag(LogType.api)
        }
        .pickerStyle(.segmented)

        Spacer()
      }

      HStack {
        Text(selectedLogType == .app ? "logs.header.app".localized : "logs.header.api".localized)
          .font(.headline)
        Spacer()
        if selectedLogType == .app {
          Toggle("logs.toggle.errors_only".localized, isOn: $appOnlyErrors)
            .toggleStyle(.switch)
          Button("logs.button.clear".localized) {
            AppLogStore.shared.clearAll()
            appEntries = AppLogStore.shared.entries
          }
          .disabled(appEntries.isEmpty)
        } else {
          Button("logs.button.clear".localized) {
            APILogStore.shared.clearAll()
            entries = APILogStore.shared.entries
          }
          .disabled(entries.isEmpty)
        }
      }

      logList
    }
    .padding(20)
    .onAppear {
      entries = APILogStore.shared.entries
      appEntries = AppLogStore.shared.entries
    }
    .onReceive(NotificationCenter.default.publisher(for: .apiLogUpdated)) { _ in
      entries = APILogStore.shared.entries
    }
    .onReceive(NotificationCenter.default.publisher(for: .appLogUpdated)) { _ in
      appEntries = AppLogStore.shared.entries
    }
  }

  private func toggleExpanded(_ id: UUID) {
    if expandedIds.contains(id) {
      expandedIds.remove(id)
    } else {
      expandedIds.insert(id)
    }
  }

  private var logList: some View {
    Group {
      if selectedLogType == .app {
        let filtered = appOnlyErrors ? appEntries.filter { $0.level == .error } : appEntries
        if filtered.isEmpty {
          Spacer()
          Text("logs.no_logs".localized)
            .foregroundColor(.secondary)
          Spacer()
        } else {
          List(filtered) { entry in
            AppLogEntryRow(
              entry: entry,
              isExpanded: expandedIds.contains(entry.id),
              dateFormatter: dateFormatter
            )
            .contentShape(Rectangle())
            .onTapGesture {
              toggleExpanded(entry.id)
            }
          }
          .listStyle(.plain)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
      } else {
        if entries.isEmpty {
          Spacer()
          Text("logs.no_logs".localized)
            .foregroundColor(.secondary)
          Spacer()
        } else {
          List(entries) { entry in
            LogEntryRow(
              entry: entry,
              isExpanded: expandedIds.contains(entry.id),
              dateFormatter: dateFormatter
            )
            .contentShape(Rectangle())
            .onTapGesture {
              toggleExpanded(entry.id)
            }
          }
          .listStyle(.plain)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
      }
    }
  }
}

enum LogType: String, Hashable {
  case app
  case api
}

struct AppLogEntryRow: View {
  let entry: AppLogEntry
  let isExpanded: Bool
  let dateFormatter: DateFormatter

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 8) {
        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
          .font(.caption)
          .foregroundColor(.secondary)
          .frame(width: 12)

        Text(dateFormatter.string(from: entry.timestamp))
          .font(.caption)
          .foregroundColor(.secondary)

        Image(systemName: levelIcon)
          .foregroundColor(levelColor)
          .font(.caption)

        Text("[\(entry.category)] \(entry.message)")
          .font(.body)
          .lineLimit(1)
          .textSelection(.enabled)

        Spacer()
      }

      if isExpanded {
        VStack(alignment: .leading, spacing: 12) {
          LogSection(title: "logs.section.level".localized, content: entry.level.rawValue)
          if let detail = entry.detail {
            LogSection(title: "logs.section.detail".localized, content: detail)
          }
        }
        .padding(.leading, 24)
      }
    }
    .padding(.vertical, 4)
  }

  private var levelIcon: String {
    switch entry.level {
    case .info: return "info.circle.fill"
    case .warning: return "exclamationmark.triangle.fill"
    case .error: return "xmark.octagon.fill"
    }
  }

  private var levelColor: Color {
    switch entry.level {
    case .info: return .blue
    case .warning: return .orange
    case .error: return .red
    }
  }
}

struct LogEntryRow: View {
  let entry: APILogEntry
  let isExpanded: Bool
  let dateFormatter: DateFormatter

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 8) {
        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
          .font(.caption)
          .foregroundColor(.secondary)
          .frame(width: 12)

        Text(dateFormatter.string(from: entry.timestamp))
          .font(.caption)
          .foregroundColor(.secondary)

        Image(systemName: entry.isSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
          .foregroundColor(entry.isSuccess ? .green : .red)
          .font(.caption)

        let seconds = Double(entry.responseTimeMs) / 1000.0
        Text(String(format: "%.1fs", seconds))
          .font(.caption)
          .foregroundColor(.secondary)

        Text(previewText)
          .font(.body)
          .lineLimit(1)
          .textSelection(.enabled)

        Spacer()
      }

      if isExpanded {
        VStack(alignment: .leading, spacing: 12) {
          LogSection(title: "logs.section.original".localized, content: entry.requestContent)
          LogSection(title: "logs.section.request".localized, content: entry.requestBody, isJSON: true)

          if let response = entry.responseContent {
            LogSection(title: "logs.section.response".localized, content: response)
          }

          if let error = entry.errorMessage {
            LogSection(title: "logs.section.error".localized, content: error, isError: true)
          }
        }
        .padding(.leading, 24)
      }
    }
    .padding(.vertical, 4)
  }

  private var previewText: String {
    let text = entry.requestContent
    if text.count > 30 {
      return String(text.prefix(30)) + "..."
    }
    return text
  }
}

struct LogSection: View {
  let title: String
  let content: String
  var isJSON: Bool = false
  var isError: Bool = false

  private var displayContent: String {
    guard isJSON,
          let data = content.data(using: .utf8),
          let object = try? JSONSerialization.jsonObject(with: data),
          let pretty = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]),
          let string = String(data: pretty, encoding: .utf8) else {
      return content
    }
    return string
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(title)
        .font(.caption.bold())
        .foregroundColor(isError ? .red : .secondary)

      Text(displayContent)
        .font(.system(.caption, design: .monospaced))
        .foregroundColor(isError ? .red : .primary)
        .textSelection(.enabled)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(Color(NSColor.textBackgroundColor))
        .cornerRadius(4)
    }
  }
}

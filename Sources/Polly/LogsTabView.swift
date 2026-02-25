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
                Picker("日志", selection: $selectedLogType) {
                    Text("应用日志").tag(LogType.app)
                    Text("API 日志").tag(LogType.api)
                }
                .pickerStyle(.segmented)

                Spacer()
            }

            HStack {
                Text(selectedLogType == .app ? "应用日志" : "API 调用日志")
                    .font(.headline)
                Spacer()
                if selectedLogType == .app {
                    Toggle("仅错误", isOn: $appOnlyErrors)
                        .toggleStyle(.switch)
                    Button("清空日志") {
                        AppLogStore.shared.clearAll()
                        appEntries = AppLogStore.shared.entries
                    }
                    .disabled(appEntries.isEmpty)
                } else {
                    Button("清空日志") {
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
                    Text("暂无日志")
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
                    Text("暂无日志")
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

                Text(dateFormatter.string(from: entry.timestamp))
                    .font(.caption)
                    .foregroundColor(.secondary)

                Image(systemName: levelIcon)
                    .foregroundColor(levelColor)
                    .font(.caption)

                Text("[\(entry.category)] \(entry.message)")
                    .font(.body)
                    .lineLimit(1)

                Spacer()
            }

            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    LogSection(title: "级别", content: entry.level.rawValue)
                    if let detail = entry.detail {
                        LogSection(title: "详情", content: detail)
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

                Spacer()
            }

            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    LogSection(title: "原始文本", content: entry.requestContent)
                    LogSection(title: "请求体", content: entry.requestBody, isJSON: true)

                    if let response = entry.responseContent {
                        LogSection(title: "响应", content: response)
                    }

                    if let error = entry.errorMessage {
                        LogSection(title: "错误", content: error, isError: true)
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

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.bold())
                .foregroundColor(isError ? .red : .secondary)

            Text(content)
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

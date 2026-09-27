import SwiftUI
import AppKit

/// 主窗口内容。
struct ContentView: View {

    @EnvironmentObject var store: HostsStore

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            preview
            Divider()
            footer
        }
        .frame(minWidth: 640, minHeight: 460)
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("数据源").font(.caption).foregroundColor(.secondary)
                Text(HostsFetcher.sourceURL.absoluteString)
                    .font(.footnote)
                    .textSelection(.enabled)
            }
            Spacer()
            Button {
                Task { await store.refresh() }
            } label: {
                if store.isBusy {
                    HStack(spacing: 6) {
                        ProgressView().controlSize(.small)
                        Text("获取最新")
                    }
                } else {
                    Text("获取最新")
                }
            }
            .disabled(store.isBusy)
        }
        .padding()
    }

    // MARK: - Preview

    private var preview: some View {
        ScrollView {
            Text(store.remoteContent.isEmpty ? "暂无内容，点击右上角「获取最新」。" : store.remoteContent)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .textBackgroundColor))
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(applyStateText)
                    .font(.subheadline)
                    .bold()
                    .foregroundColor(applyStateColor)
                Spacer()
                if let date = store.lastUpdated {
                    Text("更新时间：\(Self.dateFormatter.string(from: date))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("更新时间：—")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            if let error = store.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !store.statusMessage.isEmpty {
                Text(store.statusMessage)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            HStack {
                Spacer()
                Button("仅刷新 DNS") {
                    Task { await store.flushDNS() }
                }
                .disabled(store.isBusy)

                Button("应用到 hosts") {
                    Task { await store.applyToSystem() }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(store.remoteContent.isEmpty || store.isBusy)
            }
        }
        .padding()
    }

    private var applyStateText: String {
        switch store.applyState {
        case .notApplied: return "状态：未写入"
        case .upToDate:   return "状态：已写入 · 已是最新"
        case .outdated:   return "状态：已写入 · 有更新"
        }
    }

    private var applyStateColor: Color {
        switch store.applyState {
        case .notApplied: return .secondary
        case .upToDate:   return .green
        case .outdated:   return .orange
        }
    }
}

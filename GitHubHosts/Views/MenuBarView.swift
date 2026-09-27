import SwiftUI
import AppKit

/// 菜单栏菜单内容。
struct MenuBarView: View {

    @EnvironmentObject var store: HostsStore
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("打开主窗口") {
            openWindow(id: "main")
            NSApplication.shared.activate(ignoringOtherApps: true)
        }

        Divider()

        Button("立即更新并应用") {
            Task {
                await store.refresh()
                await store.applyToSystem()
            }
        }
        .disabled(store.isBusy)

        Button("仅刷新 DNS") {
            Task { await store.flushDNS() }
        }
        .disabled(store.isBusy)

        Divider()

        Button("退出") {
            NSApplication.shared.terminate(nil)
        }
    }
}

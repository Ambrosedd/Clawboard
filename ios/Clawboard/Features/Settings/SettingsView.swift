import SwiftUI

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("连接") {
                    Label("扫码配对", systemImage: "qrcode.viewfinder")
                    Label("节点管理", systemImage: "desktopcomputer")
                }

                Section("安全") {
                    Label("配对 Token", systemImage: "key")
                    Label("权限边界说明", systemImage: "lock.shield")
                }
            }
            .navigationTitle("设置")
        }
    }
}

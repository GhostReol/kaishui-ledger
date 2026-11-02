import SwiftUI

// MARK: - 手动记一笔

struct AddRecordView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var store = LedgerStore.shared

    @State private var amountText = ""
    @State private var merchant = ""
    @State private var category = "餐食"
    @State private var channel = "微信"
    @State private var date = Date()

    private var amountValid: Bool {
        (Double(amountText) ?? 0) > 0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("金额") {
                    TextField("0.00", text: $amountText)
                        .keyboardType(.decimalPad)
                        .font(.title2)
                        .monospacedDigit()
                }
                Section("详情") {
                    TextField("商户 / 备注", text: $merchant)
                    Picker("分类", selection: $category) {
                        ForEach(CategoryEngine.categories, id: \.self) { Text($0) }
                    }
                    Picker("渠道", selection: $channel) {
                        ForEach(CategoryEngine.channels, id: \.self) { Text($0) }
                    }
                    DatePicker("时间", selection: $date, displayedComponents: [.date, .hourAndMinute])
                }
            }
            .navigationTitle("记一笔")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .disabled(!amountValid)
                }
            }
        }
    }

    private func save() {
        guard let amount = Double(amountText), amount > 0 else { return }
        let record = LedgerRecord(
            amount: amount,
            merchant: merchant.isEmpty ? "手动记录" : merchant,
            channel: channel,
            category: category,
            date: date
        )
        store.add(record)
        dismiss()
    }
}

// MARK: - 设置页

struct SettingsView: View {
    @ObservedObject private var store = LedgerStore.shared
    @State private var confirmClear = false

    var body: some View {
        NavigationStack {
            Form {
                Section("数据") {
                    ShareLink("导出 CSV 账单", item: store.csvString())
                    Button("清空全部记录", role: .destructive) { confirmClear = true }
                }
                Section("自动记账") {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("支付完成后，轻点手机背面两下，快捷指令会自动截屏并识别支付页，把金额和商户直接写进本 App。")
                            .font(.footnote)
                        Text("配置方法：设置 → 辅助功能 → 触控 → 轻点背面 → 轻点两下 → 选择「记一笔」快捷指令。快捷指令的制作步骤见项目 README。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                Section("关于") {
                    LabeledContent("版本", value: "1.0.0")
                    LabeledContent("记录条数", value: "\(store.records.count)")
                }
            }
            .navigationTitle("设置")
            .confirmationDialog("确定清空所有记录？此操作不可恢复", isPresented: $confirmClear, titleVisibility: .visible) {
                Button("清空", role: .destructive) { store.clear() }
                Button("取消", role: .cancel) {}
            }
        }
    }
}

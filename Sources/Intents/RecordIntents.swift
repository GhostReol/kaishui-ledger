import Foundation
import AppIntents

// MARK: - 快捷指令入口 1：结构化记一笔（金额/商户/渠道 都准备好时用）

struct QuickRecordIntent: AppIntent {
    static var title: LocalizedStringResource = "记一笔支出"
    static var description = IntentDescription("把一笔支出直接写进开水记账")

    @Parameter(title: "金额") var amount: Double
    @Parameter(title: "商户", default: "") var merchant: String
    @Parameter(title: "渠道", default: "微信") var channel: String

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let record = LedgerRecord(
            amount: amount,
            merchant: merchant.isEmpty ? "快捷指令" : merchant,
            channel: channel
        )
        LedgerStore.shared.add(record)
        let msg = "已记 ¥" + String(format: "%.2f", amount) + " · " + record.category
        return .result(dialog: IntentDialog(stringLiteral: msg))
    }
}

// MARK: - 快捷指令入口 2：把 OCR 到的支付页文本整段丢进来，App 自己解析（推荐轻点背面用这个）

struct RecordFromTextIntent: AppIntent {
    static var title: LocalizedStringResource = "从支付页文本记账"
    static var description = IntentDescription("把 OCR 得到的支付成功页文本解析成一笔记录")

    @Parameter(title: "OCR文本") var text: String

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let amount = Self.parseAmount(text) else {
            return .result(dialog: IntentDialog(stringLiteral: "没识别到金额，重截一张支付页试试"))
        }
        let merchant = Self.parseMerchant(text)
        let channel = Self.parseChannel(text)
        let record = LedgerRecord(
            amount: amount,
            merchant: merchant.isEmpty ? "自动识别" : merchant,
            channel: channel
        )
        LedgerStore.shared.add(record)
        let msg = "已记 ¥" + String(format: "%.2f", amount) + " · " + record.merchant + " · " + record.category
        return .result(dialog: IntentDialog(stringLiteral: msg))
    }

    // MARK: 解析逻辑

    private static func firstGroup(_ pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let ns = text as NSString
        guard let match = regex.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)),
              match.range(at: 1).location != NSNotFound else { return nil }
        return ns.substring(with: match.range(at: 1))
    }

    static func parseAmount(_ text: String) -> Double? {
        // 优先带货币符号的：¥18.50 / ￥18.5
        if let s = firstGroup("[¥￥]\\s*([0-9]+(?:\\.[0-9]{1,2})?)", in: text),
           let v = Double(s), v > 0 { return v }
        // 退而求其次：18.50元
        if let s = firstGroup("([0-9]+(?:\\.[0-9]{1,2})?)\\s*元", in: text),
           let v = Double(s), v > 0 { return v }
        return nil
    }

    static func parseMerchant(_ text: String) -> String {
        let patterns = [
            "向([^，。\\n]{1,20}?)付款",
            "付款给([^，。\\n]{1,20}?)(?:\\n|$)",
            "收款方[:：]?([^\\n]{1,25})",
            "商家[:：]?([^\\n]{1,25})",
        ]
        for p in patterns {
            if let s = firstGroup(p, in: text) {
                let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { return trimmed }
            }
        }
        return ""
    }

    static func parseChannel(_ text: String) -> String {
        if text.contains("支付宝") { return "支付宝" }
        if text.contains("微信") { return "微信" }
        if text.contains("云闪付") || text.contains("银联") { return "银行卡" }
        return "其他"
    }
}

import Foundation
import Combine

// MARK: - 数据模型

public struct LedgerRecord: Codable, Identifiable, Hashable {
    public var id: UUID
    public var amount: Double
    public var merchant: String
    public var channel: String
    public var category: String
    public var note: String
    public var date: Date

    public init(id: UUID = UUID(),
                amount: Double,
                merchant: String,
                channel: String,
                category: String? = nil,
                note: String = "",
                date: Date = Date()) {
        self.id = id
        self.amount = amount
        self.merchant = merchant
        self.channel = channel
        self.category = category ?? CategoryEngine.categorize(merchant)
        self.note = note
        self.date = date
    }
}

public struct DayTotal: Identifiable {
    public var id: Date { day }
    public let day: Date
    public let total: Double
}

public struct CategoryTotal: Identifiable {
    public var id: String { category }
    public let category: String
    public let total: Double
}

// MARK: - 分类引擎：商户名关键词自动打标

public enum CategoryEngine {
    public static let categories = ["餐食", "交通", "购物", "娱乐", "居住", "通讯", "医疗", "其他"]
    public static let channels = ["微信", "支付宝", "银行卡", "现金"]

    static let rules: [(String, [String])] = [
        ("餐食", ["餐", "饭", "面", "米粉", "茶", "咖啡", "外卖", "饿了么", "美团", "肯德基", "麦当劳", "星巴克", "瑞幸", "库迪", "超市", "菜", "烧烤", "火锅", "零食", "烘焙", "面包", "奶茶", "食"]),
        ("交通", ["滴滴", "出租", "地铁", "公交", "火车", "12306", "机票", "航空", "加油", "停车", "骑行", "哈啰", "货拉拉", "高德"]),
        ("购物", ["淘宝", "京东", "拼多多", "天猫", "抖音商城", "唯品会", "商场", "便利店", "百货", "得物"]),
        ("娱乐", ["电影", "游戏", "音乐", "视频会员", "会员", "Steam", "腾讯视频", "爱奇艺", "哔哩", "B站", "网易云", "KTV", "网吧"]),
        ("居住", ["房租", "水费", "电费", "燃气", "物业", "宽带"]),
        ("通讯", ["话费", "移动", "联通", "电信", "流量"]),
        ("医疗", ["医院", "药店", "药房", "挂号", "诊所", "门诊"]),
    ]

    public static func categorize(_ merchant: String) -> String {
        for (cat, keywords) in rules where keywords.contains(where: merchant.contains) {
            return cat
        }
        return "其他"
    }
}

// MARK: - 存储层：App / 小组件 / 快捷指令 三端共用一份 JSON（App Group）

public final class LedgerStore: ObservableObject {
    public static let shared = LedgerStore()
    static let appGroupID = "group.com.kaishui.ledger"

    @Published public private(set) var records: [LedgerRecord] = []

    private let fileName = "ledger.json"

    private var fileURL: URL {
        let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Self.appGroupID)
        let dir = groupURL ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent(fileName)
    }

    private init() { load() }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let list = try? JSONDecoder().decode([LedgerRecord].self, from: data) else { return }
        records = list
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(records) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    public func add(_ record: LedgerRecord) {
        records.append(record)
        save()
    }

    public func delete(at offsets: IndexSet) {
        records.remove(atOffsets: offsets)
        save()
    }

    public func clear() {
        records.removeAll()
        save()
    }

    // MARK: 汇总

    public func totalToday() -> Double {
        let cal = Calendar.current
        return records.filter { cal.isDateInToday($0.date) }.reduce(0) { $0 + $1.amount }
    }

    public func totalThisMonth() -> Double {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month], from: Date())
        return records
            .filter { cal.dateComponents([.year, .month], from: $0.date) == comps }
            .reduce(0) { $0 + $1.amount }
    }

    public func dailyTotals(limit days: Int = 14) -> [DayTotal] {
        let cal = Calendar.current
        var result: [DayTotal] = []
        for offset in stride(from: days - 1, through: 0, by: -1) {
            guard let day = cal.date(byAdding: .day, value: -offset, to: cal.startOfDay(for: Date())) else { continue }
            let total = records
                .filter { cal.isDate($0.date, inSameDayAs: day) }
                .reduce(0) { $0 + $1.amount }
            result.append(DayTotal(day: day, total: total))
        }
        return result
    }

    public func categoryTotalsThisMonth() -> [CategoryTotal] {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month], from: Date())
        let monthRecords = records.filter { cal.dateComponents([.year, .month], from: $0.date) == comps }
        let dict = Dictionary(grouping: monthRecords, by: { $0.category })
            .mapValues { $0.reduce(0) { $0 + $1.amount } }
        return dict
            .map { CategoryTotal(category: $0.key, total: $0.value) }
            .sorted { $0.total > $1.total }
    }

    public func sortedByDateDesc() -> [LedgerRecord] {
        records.sorted { $0.date > $1.date }
    }

    // MARK: CSV 导出

    public func csvString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        var rows = ["日期,金额,商户,分类,渠道"]
        for r in sortedByDateDesc() {
            let merchant = r.merchant.contains(",") ? "\"\(r.merchant)\"" : r.merchant
            rows.append("\(formatter.string(from: r.date)),\(String(format: "%.2f", r.amount)),\(merchant),\(r.category),\(r.channel)")
        }
        return rows.joined(separator: "\n")
    }
}

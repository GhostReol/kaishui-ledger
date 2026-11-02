import WidgetKit
import SwiftUI

// MARK: - 桌面小组件：今日 / 本月支出概览

struct LedgerEntry: TimelineEntry {
    let date: Date
    let today: Double
    let month: Double
    let last: LedgerRecord?
}

struct Provider: TimelineProvider {
    private func makeEntry() -> LedgerEntry {
        let store = LedgerStore.shared
        let last = store.sortedByDateDesc().first
        return LedgerEntry(date: Date(), today: store.totalToday(), month: store.totalThisMonth(), last: last)
    }

    func placeholder(in context: Context) -> LedgerEntry {
        LedgerEntry(date: Date(), today: 86.50, month: 2318.40, last: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (LedgerEntry) -> Void) {
        completion(makeEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<LedgerEntry>) -> Void) {
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date().addingTimeInterval(1800)
        completion(Timeline(entries: [makeEntry()], policy: .after(next)))
    }
}

struct WidgetBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOSApplicationExtension 17.0, *) {
            content.containerBackground(.fill.tertiary, for: .widget)
        } else {
            content.padding(14)
        }
    }
}

struct LedgerWidgetEntryView: View {
    var entry: LedgerEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("今日支出")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("¥" + String(format: "%.2f", entry.today))
                .font(.system(.title2, design: .rounded))
                .bold()
                .monospacedDigit()
            Text("本月 ¥" + String(format: "%.2f", entry.month))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .monospacedDigit()
            if let last = entry.last {
                HStack(spacing: 4) {
                    Circle().fill(.orange).frame(width: 6, height: 6)
                    Text(last.merchant)
                        .font(.caption2)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(WidgetBackgroundModifier())
    }
}

struct LedgerWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "LedgerWidget", provider: Provider()) { entry in
            LedgerWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("开水记账")
        .description("今日与本月支出概览，每 30 分钟刷新")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct LedgerWidgetBundle: WidgetBundle {
    var body: some Widget {
        LedgerWidget()
    }
}

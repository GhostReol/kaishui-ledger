import SwiftUI
import Charts

struct ContentView: View {
    var body: some View {
        TabView {
            TodayView()
                .tabItem { Label("今日", systemImage: "chart.bar.fill") }
            RecordsView()
                .tabItem { Label("明细", systemImage: "list.bullet") }
            SettingsView()
                .tabItem { Label("设置", systemImage: "gearshape") }
        }
    }
}

// MARK: - 今日页

struct TodayView: View {
    @ObservedObject private var store = LedgerStore.shared
    @State private var showAdd = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // 总览卡片
                    VStack(alignment: .leading, spacing: 4) {
                        Text("今日支出")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("¥" + String(format: "%.2f", store.totalToday()))
                            .font(.system(size: 40, weight: .bold))
                            .monospacedDigit()
                        Text("本月累计 ¥" + String(format: "%.2f", store.totalThisMonth()))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(14)

                    // 近 14 天趋势
                    Chart(store.dailyTotals()) { d in
                        BarMark(
                            x: .value("日期", d.day, unit: .day),
                            y: .value("支出", d.total)
                        )
                        .foregroundStyle(Color.blue.gradient)
                        .cornerRadius(3)
                    }
                    .chartYAxis {
                        AxisMarks(position: .trailing)
                    }
                    .frame(height: 170)

                    // 本月分类
                    VStack(alignment: .leading, spacing: 10) {
                        Text("本月分类")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        if store.categoryTotalsThisMonth().isEmpty {
                            Text("这个月还没记过账，付款完轻点背面两下试试")
                                .font(.footnote)
                                .foregroundStyle(.tertiary)
                        }
                        ForEach(store.categoryTotalsThisMonth()) { c in
                            HStack {
                                Text(c.category)
                                Spacer()
                                Text("¥" + String(format: "%.2f", c.total))
                                    .monospacedDigit()
                            }
                            .font(.callout)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(14)
                }
                .padding()
            }
            .navigationTitle("开水记账")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showAdd = true } label: {
                        Image(systemName: "plus.circle.fill").font(.title3)
                    }
                }
            }
            .sheet(isPresented: $showAdd) { AddRecordView() }
        }
    }
}

// MARK: - 明细页

struct RecordsView: View {
    @ObservedObject private var store = LedgerStore.shared
    @State private var showAdd = false

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "M月d日 EEEE"
        f.locale = Locale(identifier: "zh_CN")
        return f
    }()

    private var grouped: [(day: Date, items: [LedgerRecord])] {
        let cal = Calendar.current
        let dict = Dictionary(grouping: store.sortedByDateDesc()) { cal.startOfDay(for: $0.date) }
        return dict.sorted { $0.key > $1.key }.map { (day: $0.key, items: $0.value) }
    }

    var body: some View {
        NavigationStack {
            List {
                if grouped.isEmpty {
                    Text("还没有记录")
                        .foregroundStyle(.secondary)
                }
                ForEach(grouped, id: \.day) { group in
                    Section(Self.dayFormatter.string(from: group.day)) {
                        ForEach(group.items) { r in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(r.merchant).font(.body)
                                    Text("\(r.channel) · \(r.category)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text("-¥" + String(format: "%.2f", r.amount))
                                    .bold()
                                    .monospacedDigit()
                            }
                        }
                        .onDelete { store.delete(at: $0) }
                    }
                }
            }
            .navigationTitle("明细")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showAdd = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $showAdd) { AddRecordView() }
        }
    }
}

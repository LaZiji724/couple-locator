import SwiftUI
import WidgetKit
import ActivityKit

// ───────── 桌面小组件（读取 home_widget 写入 App Group 的数据） ─────────
struct CoupleEntry: TimelineEntry {
    let date: Date
    let emoji: String
    let name: String
    let distance: String
    let battery: String
    let updated: String
}

struct CoupleProvider: TimelineProvider {
    private let group = "group.com.couple.coupleLocator"
    func placeholder(in context: Context) -> CoupleEntry {
        CoupleEntry(date: Date(), emoji: "💗", name: "TA", distance: "1.2 km", battery: "电量 80%", updated: "刚刚")
    }
    func getSnapshot(in context: Context, completion: @escaping (CoupleEntry) -> Void) { completion(load()) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<CoupleEntry>) -> Void) {
        completion(Timeline(entries: [load()], policy: .after(Date().addingTimeInterval(15 * 60))))
    }
    private func load() -> CoupleEntry {
        let d = UserDefaults(suiteName: group)
        return CoupleEntry(
            date: Date(),
            emoji: d?.string(forKey: "emoji") ?? "💗",
            name: d?.string(forKey: "name") ?? "TA",
            distance: d?.string(forKey: "distance") ?? "--",
            battery: d?.string(forKey: "battery") ?? "电量 --",
            updated: d?.string(forKey: "updated") ?? "等待更新")
    }
}

struct CoupleWidgetView: View {
    @Environment(\.widgetFamily) var family
    let entry: CoupleEntry
    var body: some View {
        let grad = LinearGradient(colors: [Color(red: 1, green: 0.42, blue: 0.54), Color(red: 1, green: 0.60, blue: 0.42), Color(red: 1, green: 0.82, blue: 0.40)], startPoint: .topLeading, endPoint: .bottomTrailing)
        let ink = Color(red: 0.23, green: 0.06, blue: 0.19)
        Group {
            if family == .systemSmall {
                VStack(spacing: 4) {
                    Text(entry.emoji).font(.system(size: 30))
                    Text(entry.distance).font(.system(size: 22, weight: .heavy, design: .rounded)).foregroundColor(ink)
                    Text(entry.updated).font(.system(size: 11)).foregroundColor(ink.opacity(0.75))
                }
            } else {
                HStack(spacing: 14) {
                    Text(entry.emoji).font(.system(size: 44))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.name).font(.system(size: 16, weight: .bold)).foregroundColor(ink)
                        Text(entry.distance).font(.system(size: 28, weight: .heavy, design: .rounded)).foregroundColor(ink)
                        Text(entry.battery).font(.system(size: 12)).foregroundColor(ink.opacity(0.8))
                        Text(entry.updated).font(.system(size: 12)).foregroundColor(ink.opacity(0.8))
                    }
                    Spacer()
                }.padding(.horizontal, 6)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(grad)
    }
}

struct CoupleWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "CoupleWidget", provider: CoupleProvider()) { entry in
            if #available(iOS 17.0, *) {
                CoupleWidgetView(entry: entry).containerBackground(.clear, for: .widget)
            } else {
                CoupleWidgetView(entry: entry)
            }
        }
        .configurationDisplayName("TA 在哪")
        .description("显示 TA 的距离、电量和最后更新时间")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// ───────── 锁屏实时活动（live_activities 插件约定的 Attributes） ─────────
struct LiveActivitiesAppAttributes: ActivityAttributes, Identifiable {
    public typealias LiveDeliveryData = ContentState
    public struct ContentState: Codable, Hashable { var appGroupId: String }
    var id = UUID()
}

extension LiveActivitiesAppAttributes {
    func prefixedKey(_ key: String) -> String { return "\(id)_\(key)" }
}

@available(iOS 16.1, *)
struct CoupleLiveActivity: Widget {
    private let group = "group.com.couple.coupleLocator"
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LiveActivitiesAppAttributes.self) { context in
            let d = UserDefaults(suiteName: group)
            HStack(spacing: 12) {
                Text(d?.string(forKey: context.attributes.prefixedKey("emoji")) ?? "💗").font(.system(size: 34))
                VStack(alignment: .leading) {
                    Text(d?.string(forKey: context.attributes.prefixedKey("distance")) ?? "--").font(.system(size: 24, weight: .heavy, design: .rounded))
                    Text(d?.string(forKey: context.attributes.prefixedKey("updated")) ?? "").font(.system(size: 12)).opacity(0.8)
                }
                Spacer()
                Text(d?.string(forKey: context.attributes.prefixedKey("battery")) ?? "").font(.system(size: 13, weight: .semibold))
            }
            .padding(16)
            .activityBackgroundTint(Color(red: 1, green: 0.60, blue: 0.42))
        } dynamicIsland: { context in
            let d = UserDefaults(suiteName: group)
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) { Text(d?.string(forKey: context.attributes.prefixedKey("emoji")) ?? "💗").font(.title) }
                DynamicIslandExpandedRegion(.trailing) { Text(d?.string(forKey: context.attributes.prefixedKey("distance")) ?? "--").font(.headline) }
                DynamicIslandExpandedRegion(.bottom) { Text(d?.string(forKey: context.attributes.prefixedKey("updated")) ?? "").font(.caption) }
            } compactLeading: { Text("💗") } compactTrailing: {
                Text(d?.string(forKey: context.attributes.prefixedKey("distance")) ?? "--").font(.caption2)
            } minimal: { Text("💗") }
        }
    }
}

@main
struct CoupleWidgetBundle: WidgetBundle {
    var body: some Widget {
        CoupleWidget()
        if #available(iOS 16.1, *) { CoupleLiveActivity() }
    }
}

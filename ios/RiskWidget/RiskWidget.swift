import WidgetKit
import SwiftUI

// MARK: - TimelineProvider

struct Provider: TimelineProvider {
    let groupId = "group.health-predictor"

    func placeholder(in context: Context) -> RiskEntry {
        RiskEntry(date: Date(), riskPercent: "45%", riskLabel: "やや注意", confidence: "medium")
    }

    func getSnapshot(in context: Context, completion: @escaping (RiskEntry) -> ()) {
        let entry = readEntry()
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<RiskEntry>) -> ()) {
        let entry = readEntry()
        // 30分後にリフレッシュ
        let nextRefresh = Calendar.current.date(byAdding: .minute, value: 30, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextRefresh))
        completion(timeline)
    }

    private func readEntry() -> RiskEntry {
        let defaults = UserDefaults(suiteName: groupId)
        let riskPercent = defaults?.string(forKey: "riskPercent") ?? "--%"
        let riskLabel = defaults?.string(forKey: "riskLabel") ?? "---"
        let confidence = defaults?.string(forKey: "confidence") ?? ""
        return RiskEntry(
            date: Date(),
            riskPercent: riskPercent,
            riskLabel: riskLabel,
            confidence: confidence
        )
    }
}

// MARK: - Timeline Entry

struct RiskEntry: TimelineEntry {
    let date: Date
    let riskPercent: String
    let riskLabel: String
    let confidence: String
}

// MARK: - Widget View

struct RiskWidgetView: View {
    var entry: RiskEntry

    /// リスク値に応じた色
    private var riskColor: Color {
        guard let numStr = entry.riskPercent.replacingOccurrences(of: "%", with: ""),
              let value = Int(numStr) else {
            return .gray
        }
        if value >= 60 { return .red }
        if value >= 40 { return .orange }
        if value >= 20 { return Color(red: 0.3, green: 0.6, blue: 0.9) }
        return .green
    }

    /// リスク値に応じた背景グラデーション
    private var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [riskColor.opacity(0.08), riskColor.opacity(0.02)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var body: some View {
        VStack(spacing: 6) {
            // ヘッダー
            HStack {
                Image(systemName: "heart.text.square.fill")
                    .font(.system(size: 12))
                    .foregroundColor(riskColor)
                Text("体調リスク")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                Spacer()
            }

            Spacer()

            // リスクパーセント（メイン表示）
            Text(entry.riskPercent)
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundColor(riskColor)
                .minimumScaleFactor(0.6)

            // リスクラベル
            Text(entry.riskLabel)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(riskColor)

            Spacer()

            // 信頼度
            if !entry.confidence.isEmpty {
                HStack(spacing: 4) {
                    let label = confidenceLabel(entry.confidence)
                    Text("信頼度: \(label)")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            ContainerRelativeShape()
                .fill(backgroundGradient)
        )
    }

    private func confidenceLabel(_ raw: String) -> String {
        switch raw {
        case "high": return "高"
        case "medium": return "中"
        case "low": return "低"
        default: return raw
        }
    }
}

// MARK: - Widget Configuration

@main
struct RiskWidget: Widget {
    let kind: String = "RiskWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            if #available(iOS 17.0, *) {
                RiskWidgetView(entry: entry)
                    .containerBackground(.fill.tertiary, for: .widget)
            } else {
                RiskWidgetView(entry: entry)
                    .padding()
                    .background()
            }
        }
        .configurationDisplayName("体調リスク")
        .description("今日の不調リスクをホーム画面に表示します")
        .supportedFamilies([.systemSmall])
    }
}

// MARK: - Preview

#if DEBUG
struct RiskWidget_Previews: PreviewProvider {
    static var previews: some View {
        RiskWidgetView(entry: RiskEntry(
            date: Date(),
            riskPercent: "45%",
            riskLabel: "やや注意",
            confidence: "medium"
        ))
        .previewContext(WidgetPreviewContext(family: .systemSmall))
    }
}
#endif

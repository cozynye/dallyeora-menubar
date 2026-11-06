import DallyeoraCore
import SwiftUI

struct CleanupView: View {
    @Bindable var model: CleanupModel
    /// 강제 종료 확인 창은 AppKit NSAlert로 띄운다(SwiftUI alert보다 메뉴 막대 앱에서 안정적).
    let confirmForceQuit: (CleanupModel.Row) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("지표", selection: $model.metric) {
                ForEach(Metric.allCases, id: \.self) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 180)

            Text(model.totalText).font(.headline)

            if model.failed {
                Spacer()
                Text("프로세스 정보를 읽을 수 없습니다").frame(maxWidth: .infinity)
                Spacer()
            } else {
                List(model.rows) { row in
                    RowView(row: row, quit: { model.quit(row) }, forceQuit: { confirmForceQuit(row) })
                        .listRowSeparator(.visible)
                }
                .listStyle(.inset)
            }
        }
        .padding()
        .frame(minWidth: 480, minHeight: 360)
    }
}

private struct RowView: View {
    let row: CleanupModel.Row
    let quit: () -> Void
    let forceQuit: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            iconView.frame(width: 32, height: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(row.title).font(.body.weight(.semibold))
                Text(row.summary).font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Text(row.usageText).font(.body.monospacedDigit()).frame(minWidth: 72, alignment: .trailing)
            badge.frame(width: 92)
            quitButton.frame(width: 84)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder private var iconView: some View {
        if let icon = row.icon {
            Image(nsImage: icon).resizable()
        } else {
            Image(systemName: "gearshape").resizable().scaledToFit().foregroundStyle(.secondary).padding(5)
        }
    }

    private var badge: some View {
        let (text, color): (String, Color) = switch row.badge {
        case .quittable: ("끌 수 있음", .green)
        case .background: ("내 백그라운드", .gray)
        case .system: ("시스템", .orange)
        case .others: ("그 외", .gray)
        }
        return Text(text).font(.caption2).padding(.horizontal, 6).padding(.vertical, 2)
            .background(color.opacity(0.15), in: Capsule()).foregroundStyle(color)
    }

    @ViewBuilder private var quitButton: some View {
        if row.badge == .quittable {
            switch row.quitState {
            case .idle: Button("종료", action: quit)
            case .requested: Button("종료 중…") {}.disabled(true)
            case .force: Button("강제 종료", role: .destructive, action: forceQuit)
            }
        }
    }
}

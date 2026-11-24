import DallyeoraCore
import SwiftUI

struct CleanupView: View {
    @Bindable var model: CleanupModel
    /// 확인 창은 AppKit NSAlert로 띄운다(SwiftUI alert보다 메뉴 막대 앱에서 안정적).
    let confirmForceQuit: (CleanupModel.Row) -> Void
    let confirmQuitMember: (CleanupModel.Row.Member) -> Void
    /// 펼쳐 둔 줄. 갱신으로 줄이 다시 만들어져도 id가 같아 유지된다.
    @State private var expanded: Set<String> = []
    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Picker("지표", selection: $model.metric) {
                    ForEach(Metric.allCases, id: \.self) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 180)
                Spacer()
                TextField("검색", text: $model.query)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 180)
                    .focused($searchFocused)
                    .onExitCommand { model.query = "" }
            }

            Text(model.totalText).font(.headline)

            // 누르려는 줄이 갱신 때문에 움직이지 않게, 마우스가 올라가 있는 동안에는 순서를 붙잡는다.
            // 목록이 안내 글자로 바뀌어도 벗어남을 놓치지 않도록 늘 있는 바깥 뷰에 건다.
            ZStack {
                if model.failed {
                    placeholder("프로세스 정보를 읽을 수 없습니다")
                } else if let emptyText = model.emptyText {
                    placeholder(emptyText)
                } else {
                    List(model.rows) { row in
                        if row.members.isEmpty {
                            header(row)
                        } else {
                            DisclosureGroup(isExpanded: isExpanded(row.id)) {
                                MemberList(members: row.members, quit: confirmQuitMember)
                            } label: {
                                header(row)
                            }
                        }
                    }
                    .listStyle(.inset)
                }
            }
            .onHover { model.isHovering = $0 }

            // 비어 있을 때도 한 줄을 차지해 목록 높이가 흔들리지 않게 한다.
            Text(model.notice ?? " ").font(.caption).foregroundStyle(.secondary).lineLimit(1)
        }
        .padding()
        .frame(minWidth: 480, minHeight: 360)
        // ⌘F로 검색 칸에 포커스를 준다. 보이지 않는 버튼에 단축키만 건다.
        .background {
            Button("검색") { searchFocused = true }
                .keyboardShortcut("f")
                .opacity(0)
                .accessibilityHidden(true)
        }
    }

    private func placeholder(_ text: String) -> some View {
        VStack {
            Spacer()
            Text(text).frame(maxWidth: .infinity)
            Spacer()
        }
    }

    private func header(_ row: CleanupModel.Row) -> some View {
        RowView(row: row, quit: { model.quit(row) }, forceQuit: { confirmForceQuit(row) })
            .listRowSeparator(.visible)
    }

    private func isExpanded(_ id: String) -> Binding<Bool> {
        Binding(
            get: { expanded.contains(id) },
            set: { open in if open { expanded.insert(id) } else { expanded.remove(id) } })
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
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(row.title).font(.body.weight(.semibold))
                    if row.windowCount >= 2 {
                        Text("창 \(row.windowCount)개").font(.caption).foregroundStyle(.secondary)
                    }
                }
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

/// 펼친 줄 안의 프로세스 목록. 하나씩 끌 수 있지만 그 앱의 일부가 깨질 수 있다.
private struct MemberList: View {
    let members: [CleanupModel.Row.Member]
    let quit: (CleanupModel.Row.Member) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("프로세스 하나만 끄면 그 앱의 탭·창·확장 같은 일부가 깨질 수 있다. 앱 전체를 끄려면 위의 종료 버튼을 쓴다.")
                .font(.caption2).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 2)
            ForEach(members) { member in
                HStack(spacing: 8) {
                    Text(member.name).font(.callout)
                    Text("pid \(member.pid)").font(.caption2).foregroundStyle(.secondary)
                    Spacer(minLength: 8)
                    Text(member.usageText).font(.callout.monospacedDigit()).frame(minWidth: 72, alignment: .trailing)
                    Button("종료") { quit(member) }.controlSize(.small).frame(width: 84)
                }
            }
        }
        .padding(.leading, 42)
        .padding(.vertical, 4)
    }
}

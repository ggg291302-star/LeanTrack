import SwiftUI

/// The four real tabs. The center "+" is an action, not a tab.
enum AppTab: String, CaseIterable, Identifiable {
    case home, diary, progress, more

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: "Home"
        case .diary: "Diary"
        case .progress: "Progress"
        case .more: "More"
        }
    }

    var systemImage: String {
        switch self {
        case .home: "house.fill"
        case .diary: "list.bullet.clipboard"
        case .progress: "chart.line.uptrend.xyaxis"
        case .more: "line.3.horizontal"
        }
    }
}

/// Bottom bar from the design reference: Home, Diary, big blue "+", Progress, More.
struct LTTabBar: View {
    @Binding var selection: AppTab
    var onAdd: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            item(.home)
            item(.diary)
            addButton
            item(.progress)
            item(.more)
        }
        .padding(.top, 6)
        .padding(.bottom, 2)
        .background(alignment: .top) {
            Theme.tabBarBackground
                .ignoresSafeArea(edges: .bottom)
                .overlay(alignment: .top) {
                    Rectangle().fill(Theme.separator).frame(height: 0.5)
                }
        }
    }

    private func item(_ tab: AppTab) -> some View {
        let isSelected = selection == tab
        return Button {
            selection = tab
        } label: {
            VStack(spacing: 3) {
                Image(systemName: tab.systemImage)
                    .font(.system(size: 21, weight: .regular))
                    .frame(height: 26)
                Text(tab.title)
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundStyle(isSelected ? Theme.accent : Theme.textSecondary)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        .accessibilityIdentifier("tab.\(tab.rawValue)")
    }

    private var addButton: some View {
        Button(action: onAdd) {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 46, height: 46)
                .background(Theme.accent, in: Circle())
                .shadow(color: Theme.accent.opacity(0.35), radius: 6, y: 2)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add food")
        .accessibilityIdentifier("tab.add")
    }
}

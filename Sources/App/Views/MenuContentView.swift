import SwiftUI
import Domain

/// The main menu content view showing quota metrics.
struct MenuContentView: View {
    let monitor: QuotaMonitor
    let appState: AppState

    @State private var selectedProvider: AIProvider = .claude

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            Divider()

            // Metrics Grid for selected provider
            if let snapshot = appState.snapshots[selectedProvider] {
                metricsGridView(snapshot: snapshot)
            } else if appState.isRefreshing {
                loadingView
            } else {
                noDataView
            }

            Divider()

            // Provider Switcher
            providerSwitcherRow

            Divider()

            // Action Rows
            actionRowsView

            Divider()

            // Footer
            footerView
        }
        .frame(width: 340)
        .task {
            await refresh()
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(spacing: 12) {
            // App Icon
            Image(systemName: "chart.bar.fill")
                .font(.title)
                .foregroundStyle(.primary)

            Text("ClaudeBar")
                .font(.headline)

            Spacer()

            // Status Badge
            statusBadge
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var statusBadge: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(appState.overallStatus.displayColor)
                .frame(width: 8, height: 8)

            Text(statusText)
                .font(.caption)
                .foregroundStyle(appState.overallStatus.displayColor)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(appState.overallStatus.displayColor.opacity(0.15))
        .cornerRadius(12)
    }

    private var statusText: String {
        if appState.isRefreshing { return "Refreshing" }
        switch appState.overallStatus {
        case .healthy: return "Healthy"
        case .warning: return "Warning"
        case .critical: return "Critical"
        case .depleted: return "Depleted"
        }
    }

    // MARK: - Metrics Grid

    private func metricsGridView(snapshot: UsageSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Provider indicator
            HStack(spacing: 6) {
                Circle()
                    .fill(snapshot.overallStatus.displayColor)
                    .frame(width: 8, height: 8)

                Text(snapshot.provider.name)
                    .font(.subheadline)
                    .fontWeight(.medium)

                if let email = snapshot.accountEmail {
                    Spacer()
                    Text(email)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            // Quota Cards Grid (3 per row)
            LazyVGrid(columns: gridColumns, spacing: 8) {
                ForEach(snapshot.quotas, id: \.quotaType) { quota in
                    MetricCardView(quota: quota)
                }
            }
            .padding(.horizontal, 12)

            // Updated timestamp
            HStack {
                Text("Updated \(snapshot.ageDescription)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                if snapshot.isStale {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
    }

    private var gridColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: 8),
            GridItem(.flexible(), spacing: 8),
            GridItem(.flexible(), spacing: 8),
        ]
    }

    // MARK: - Loading / Empty States

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Loading...")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(height: 120)
    }

    private var noDataView: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.bar.xaxis")
                .font(.title2)
                .foregroundStyle(.secondary)

            Text("No data available")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("Install \(selectedProvider.name) CLI")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(height: 120)
    }

    // MARK: - Provider Switcher

    private var providerSwitcherRow: some View {
        Menu {
            ForEach(availableProviders, id: \.self) { provider in
                Button {
                    selectedProvider = provider
                } label: {
                    HStack {
                        Text(provider.name)
                        if provider == selectedProvider {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            ActionRow(
                icon: "arrow.triangle.swap",
                title: "Switch Provider",
                value: selectedProvider.name,
                showChevron: true
            )
        }
        .buttonStyle(.plain)
    }

    private var availableProviders: [AIProvider] {
        // Show all providers, highlight available ones
        AIProvider.allCases
    }

    // MARK: - Action Rows

    private var actionRowsView: some View {
        VStack(spacing: 0) {
            // Open Dashboard
            Button {
                if let url = selectedProvider.dashboardURL {
                    NSWorkspace.shared.open(url)
                }
            } label: {
                ActionRow(
                    icon: "safari",
                    title: "Open Dashboard",
                    shortcut: "D"
                )
            }
            .buttonStyle(.plain)
            .keyboardShortcut("d")

            Divider().padding(.horizontal, 16)

            // Refresh
            Button {
                Task { await refresh() }
            } label: {
                ActionRow(
                    icon: "arrow.clockwise",
                    title: "Refresh",
                    shortcut: "R"
                )
            }
            .buttonStyle(.plain)
            .keyboardShortcut("r")
        }
    }

    // MARK: - Footer

    private var footerView: some View {
        Button {
            NSApplication.shared.terminate(nil)
        } label: {
            ActionRow(
                icon: "xmark.circle",
                title: "Quit ClaudeBar",
                shortcut: "Q",
                isDestructive: true
            )
        }
        .buttonStyle(.plain)
        .keyboardShortcut("q")
    }

    // MARK: - Actions

    private func refresh() async {
        appState.isRefreshing = true
        defer { appState.isRefreshing = false }

        do {
            appState.snapshots = try await monitor.refreshAll()
            appState.lastError = nil

            // Auto-select first available provider if current has no data
            if appState.snapshots[selectedProvider] == nil,
               let first = appState.snapshots.keys.first {
                selectedProvider = first
            }
        } catch {
            appState.lastError = error.localizedDescription
        }
    }
}

// MARK: - Metric Card

struct MetricCardView: View {
    let quota: UsageQuota

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Icon + Label
            HStack(spacing: 4) {
                Image(systemName: iconName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Text(quota.quotaType.displayName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            // Value
            Text("\(Int(quota.percentRemaining))%")
                .font(.system(.title3, design: .rounded))
                .fontWeight(.semibold)
                .foregroundStyle(quota.status.displayColor)

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.primary.opacity(0.1))
                        .frame(height: 3)

                    RoundedRectangle(cornerRadius: 2)
                        .fill(quota.status.displayColor)
                        .frame(width: geometry.size.width * quota.percentRemaining / 100, height: 3)
                }
            }
            .frame(height: 3)
        }
        .padding(10)
        .background(Color.primary.opacity(0.05))
        .cornerRadius(8)
    }

    private var iconName: String {
        switch quota.quotaType {
        case .session: return "clock"
        case .weekly: return "calendar"
        case .modelSpecific: return "cpu"
        }
    }
}

// MARK: - Action Row

struct ActionRow: View {
    let icon: String
    let title: String
    var value: String? = nil
    var shortcut: String? = nil
    var showChevron: Bool = false
    var isDestructive: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(isDestructive ? .red : .secondary)
                .frame(width: 20)

            Text(title)
                .foregroundStyle(isDestructive ? .red : .primary)

            Spacer()

            if let value {
                Text(value)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            if let shortcut {
                Text("⌘\(shortcut)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .background(Color.clear)
    }
}

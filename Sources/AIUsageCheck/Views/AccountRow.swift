import SwiftUI

struct AccountRow: View {
    let account: Account
    let status: FetchStatus

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(account.displayName)
                    .font(.system(size: 12, weight: .medium))
                Spacer()
                statusBadge
            }
            content
        }
    }

    @ViewBuilder
    private var content: some View {
        switch status {
        case .idle, .loading:
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text(status == .loading ? "Refreshing…" : "Waiting…")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        case .failed(let msg):
            Text(msg)
                .font(.system(size: 11))
                .foregroundStyle(.red)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        case .ok(let snapshot):
            VStack(spacing: 4) {
                row(label: "5h", window: snapshot.fiveHour, accent: account.provider.brandColor)
                row(label: "wk", window: snapshot.sevenDay, accent: account.provider.brandColor)
            }
        }
    }

    private func row(label: String, window: UsageWindow?, accent: Color) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .frame(width: 22, alignment: .leading)
                .foregroundStyle(.tertiary)
            if let window {
                UsageBar(utilization: window.utilization, accent: accent)
                Text(percentWithRemaining(window))
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .frame(width: 110, alignment: .trailing)
                    .foregroundStyle(.secondary)
            } else {
                Text("no data")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                Spacer()
            }
        }
    }

    private func percentWithRemaining(_ window: UsageWindow) -> String {
        let pct = "\(window.percentInt)%"
        if let r = Formatting.remainingTime(window.resetAt) {
            return "\(pct) (\(r))"
        }
        return pct
    }

    private var statusBadge: some View {
        Group {
            switch status {
            case .ok:        Circle().fill(.green).frame(width: 6, height: 6)
            case .loading:   Circle().fill(.blue).frame(width: 6, height: 6)
            case .failed:    Circle().fill(.red).frame(width: 6, height: 6)
            case .idle:      Circle().fill(.gray).frame(width: 6, height: 6)
            }
        }
    }
}

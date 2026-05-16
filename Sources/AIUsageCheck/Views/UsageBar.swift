import SwiftUI

/// Horizontal usage bar. Tints with the provider's brand color until the user
/// crosses 80%, then ramps to red so over-limit risk is visually obvious.
struct UsageBar: View {
    let utilization: Double
    var accent: Color = .accentColor

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(Color.primary.opacity(0.10))
                Capsule(style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: gradientColors,
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(3, geo.size.width * clamped))
            }
        }
        .frame(height: 6)
    }

    private var clamped: Double { min(max(utilization, 0), 1) }

    private var gradientColors: [Color] {
        switch clamped {
        case ..<0.5:  return [accent.opacity(0.85), accent]
        case ..<0.8:  return [accent, .orange]
        default:      return [.orange, .red]
        }
    }
}

import SwiftUI

struct PillTag: View {
    let title: String
    var icon: String? = nil
    var tint: Color = AppTheme.Colors.secondary
    var filled: Bool = false

    var body: some View {
        HStack(spacing: 6) {
            if let icon {
                Image(systemName: icon)
            }

            Text(title)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(filled ? Color.white : tint)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(filled ? tint : Color.white)
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.Metrics.chipRadius, style: .continuous)
                .stroke(filled ? tint : AppTheme.Colors.stroke)
        }
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Metrics.chipRadius, style: .continuous))
    }
}

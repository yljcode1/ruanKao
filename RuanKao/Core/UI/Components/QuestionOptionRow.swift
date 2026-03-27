import SwiftUI

struct QuestionOptionRow: View {
    let option: QuestionOption
    let isSelected: Bool
    let isCorrect: Bool?
    let action: () -> Void

    private var badgeForegroundColor: Color {
        if let isCorrect {
            if isCorrect {
                return .white
            }

            return isSelected ? .white : AppTheme.Colors.textSecondary
        }

        return isSelected ? .white : AppTheme.Colors.textSecondary
    }

    private var badgeBackgroundColor: Color {
        if let isCorrect {
            if isCorrect {
                return AppTheme.Colors.primary
            }

            return isSelected ? AppTheme.Colors.secondary : AppTheme.Colors.muted
        }

        return isSelected ? AppTheme.Colors.primary : AppTheme.Colors.muted
    }

    private var borderColor: Color {
        if let isCorrect {
            if isCorrect {
                return AppTheme.Colors.primary.opacity(0.18)
            }

            return isSelected ? AppTheme.Colors.secondary.opacity(0.22) : AppTheme.Colors.stroke
        }

        return isSelected ? AppTheme.Colors.primary.opacity(0.18) : AppTheme.Colors.stroke
    }

    private var backgroundColor: Color {
        if let isCorrect {
            if isCorrect {
                return AppTheme.Colors.primary.opacity(0.05)
            }

            return isSelected ? AppTheme.Colors.secondary.opacity(0.05) : AppTheme.Colors.card
        }

        return isSelected ? AppTheme.Colors.primary.opacity(0.04) : AppTheme.Colors.card
    }

    private var trailingIconName: String? {
        if let isCorrect {
            if isCorrect {
                return "checkmark"
            }

            return isSelected ? "xmark" : nil
        }

        return isSelected ? "checkmark" : nil
    }

    private var trailingIconColor: Color {
        if let isCorrect {
            return isCorrect ? AppTheme.Colors.primary : AppTheme.Colors.secondary
        }

        return AppTheme.Colors.primary
    }

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                Text(option.label)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(badgeForegroundColor)
                    .frame(width: 28, height: 28)
                    .background(badgeBackgroundColor)
                    .clipShape(Circle())

                HStack(alignment: .top, spacing: 10) {
                    Text(option.content)
                        .font(.body)
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .multilineTextAlignment(.leading)

                    if let trailingIconName {
                        Image(systemName: trailingIconName)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(trailingIconColor)
                            .padding(.top, 2)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 15)
            .background(backgroundColor)
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.Metrics.controlRadius, style: .continuous)
                    .stroke(borderColor, lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Metrics.controlRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.18), value: isSelected)
        .animation(.easeInOut(duration: 0.18), value: isCorrect)
    }
}

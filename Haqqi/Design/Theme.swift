import SwiftUI
import UIKit

enum Theme {
    static let navy = Color(uiColor: UIColor { t in
        t.userInterfaceStyle == .dark ? UIColor(red: 0.47, green: 0.62, blue: 0.95, alpha: 1)
                                      : UIColor(red: 0.086, green: 0.204, blue: 0.471, alpha: 1)
    })
    static let navyDeep = Color(red: 0.059, green: 0.125, blue: 0.314)
    static let gold = Color(red: 0.961, green: 0.706, blue: 0.157)
    static let green = Color(red: 0.086, green: 0.6, blue: 0.4)
    static let red = Color(red: 0.86, green: 0.2, blue: 0.2)
    static let orange = Color(red: 0.93, green: 0.5, blue: 0.1)

    static let navyFixed = Color(red: 0.086, green: 0.204, blue: 0.471)
    static var heroGradient: LinearGradient {
        LinearGradient(colors: [navyDeep, navyFixed], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    static let corner: CGFloat = 20
}

extension Font {
    static func plex(_ size: CGFloat, _ weight: Font.Weight = .regular, relativeTo style: Font.TextStyle = .body) -> Font {
        let name: String
        switch weight {
        case .bold, .heavy, .black: name = "IBMPlexSansArabic-Bold"
        case .semibold: name = "IBMPlexSansArabic-SemiBold"
        case .medium: name = "IBMPlexSansArabic-Medium"
        default: name = "IBMPlexSansArabic-Regular"
        }
        return Font.custom(name, size: size, relativeTo: style)
    }
    static var hTitle: Font { plex(30, .bold, relativeTo: .largeTitle) }
    static var hHeadline: Font { plex(20, .semibold, relativeTo: .headline) }
    static var hBody: Font { plex(18, .regular, relativeTo: .body) }
    static var hCaption: Font { plex(15, .medium, relativeTo: .caption) }
}

struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 4)
    }
}

extension View {
    func card() -> some View { modifier(CardStyle()) }
}

struct PrimaryButtonStyle: ButtonStyle {
    var color: Color = Theme.navy
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.hHeadline)
            .foregroundStyle(Color.white)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(color))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

enum Haptics {
    static func tap() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func warn() { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
}

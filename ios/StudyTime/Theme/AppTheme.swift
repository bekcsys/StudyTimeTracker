import SwiftUI

enum AppTheme: String, CaseIterable {
    case light
    case dark

    var colorScheme: ColorScheme {
        switch self {
        case .light: return .light
        case .dark: return .dark
        }
    }

    mutating func toggle() {
        self = self == .light ? .dark : .light
    }
}

/// Brand palette — iPhone Timer–style warm orange.
enum BrandColor {
    /// Semi-orange used for timer digits, play/pause, and chart series.
    static let timer = Color(red: 1.0, green: 0.62, blue: 0.04)
}

@Observable
final class ThemeStore {
    private let key = "theme"

    var theme: AppTheme {
        didSet {
            UserDefaults.standard.set(theme.rawValue, forKey: key)
        }
    }

    init() {
        if let raw = UserDefaults.standard.string(forKey: key),
           let stored = AppTheme(rawValue: raw) {
            theme = stored
        } else {
            theme = .light
        }
    }
}

extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&int)
        let r, g, b: UInt64
        switch cleaned.count {
        case 6:
            (r, g, b) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (r, g, b) = (0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: 1
        )
    }
}

struct ThemeToggleButton: View {
    @Environment(ThemeStore.self) private var themeStore

    var body: some View {
        Button {
            var transaction = Transaction(animation: nil)
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                themeStore.theme.toggle()
            }
        } label: {
            VStack(spacing: 3) {
                Image(systemName: themeStore.theme == .dark ? "sun.max" : "moon")
                    .font(.system(size: 18, weight: .regular))
                Text(themeStore.theme == .dark ? "Light" : "Dark")
                    .font(.system(size: 10))
            }
            .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(themeStore.theme == .dark ? "Switch to light mode" : "Switch to dark mode")
    }
}

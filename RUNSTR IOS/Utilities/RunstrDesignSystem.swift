import SwiftUI

// RUNSTR Design System - Black & White Minimalistic Theme
extension Color {
    // Core black and white colors
    static let runstrBlack = Color.black
    static let runstrWhite = Color.white
    
    // Gray shades for hierarchy and depth
    static let runstrGray = Color(white: 0.5)        // Medium gray (#808080)
    static let runstrGrayLight = Color(white: 0.88)  // Light gray (#E0E0E0)
    static let runstrGrayDark = Color(white: 0.25)   // Dark gray (#404040)
    
    // Background colors
    static let runstrBackground = Color.black
    static let runstrCardBackground = Color(white: 0.08) // Very dark gray for cards
    static let runstrDark = Color.black
    
    // Legacy mappings for compatibility
    static let runstrAccent = Color.white  // Previously blue/purple
    static let runstrOrange = Color.white  // Previously orange
    
    // Activity type colors - all monochrome
    static let runstrRunning = Color.white
    static let runstrWalking = Color(white: 0.9)  // Slightly dimmed white
    static let runstrCycling = Color(white: 0.85) // More dimmed white
    
    // Initialize color from hex string
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// Typography system
extension Font {
    // RUNSTR font hierarchy
    static let runstrTitle = Font.system(size: 24, weight: .bold, design: .default)
    static let runstrTitle2 = Font.system(size: 22, weight: .bold, design: .default)
    static let runstrTitle3 = Font.system(size: 20, weight: .semibold, design: .default)
    static let runstrHeadline = Font.system(size: 20, weight: .semibold, design: .default)
    static let runstrSubheadline = Font.system(size: 18, weight: .medium, design: .default)
    static let runstrBody = Font.system(size: 16, weight: .regular, design: .default)
    static let runstrBodyMedium = Font.system(size: 16, weight: .medium, design: .default)
    static let runstrCaption = Font.system(size: 14, weight: .regular, design: .default)
    static let runstrCaptionMedium = Font.system(size: 14, weight: .medium, design: .default)
    static let runstrSmall = Font.system(size: 12, weight: .regular, design: .default)
    static let runstrSmallMedium = Font.system(size: 12, weight: .medium, design: .default)
    
    // Monospace for metrics
    static let runstrMetric = Font.system(size: 28, weight: .bold, design: .monospaced)
    static let runstrMetricMedium = Font.system(size: 20, weight: .bold, design: .monospaced)
    static let runstrMetricSmall = Font.system(size: 16, weight: .bold, design: .monospaced)
}

// Spacing system
enum RunstrSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
}

// Corner radius system
enum RunstrRadius {
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
}

// Card styling
struct RunstrCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color.runstrCardBackground)
            .cornerRadius(RunstrRadius.md)
    }
}

// Button styles
struct RunstrPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.runstrBodyMedium)
            .foregroundColor(.runstrBackground)
            .padding(.horizontal, RunstrSpacing.lg)
            .padding(.vertical, RunstrSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: RunstrRadius.sm)
                    .fill(Color.runstrWhite)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
    }
}

struct RunstrSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.runstrBodyMedium)
            .foregroundColor(.runstrWhite)
            .padding(.horizontal, RunstrSpacing.lg)
            .padding(.vertical, RunstrSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: RunstrRadius.sm)
                    .stroke(Color.runstrGray, lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
    }
}

struct RunstrPrimaryButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.runstrBodyMedium)
            .foregroundColor(.runstrWhite)
            .padding(.horizontal, RunstrSpacing.lg)
            .padding(.vertical, RunstrSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: RunstrRadius.sm)
                    .stroke(Color.runstrWhite, lineWidth: 2)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
    }
}

struct RunstrSecondaryButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.runstrBodyMedium)
            .foregroundColor(.runstrWhite)
            .padding(.horizontal, RunstrSpacing.lg)
            .padding(.vertical, RunstrSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: RunstrRadius.sm)
                    .fill(Color.runstrCardBackground)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
    }
}

struct RunstrActivityButton: ButtonStyle {
    let isSelected: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.runstrCaptionMedium)
            .foregroundColor(isSelected ? .black : .runstrWhite)
            .padding(.horizontal, RunstrSpacing.md)
            .padding(.vertical, RunstrSpacing.sm)
            .background(
                RoundedRectangle(cornerRadius: RunstrRadius.sm)
                    .fill(isSelected ? Color.runstrWhite : Color.runstrCardBackground)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
    }
}

// View modifiers
extension View {
    func runstrCard() -> some View {
        modifier(RunstrCard())
    }
}
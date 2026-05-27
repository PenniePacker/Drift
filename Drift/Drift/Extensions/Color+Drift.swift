import SwiftUI

extension Color {
    static let driftPurple         = Color(hex: "5936D9")
    static let driftIndigo         = Color(hex: "5234BF")
    static let driftBlue           = Color(hex: "5274D9")
    static let driftCyan           = Color(hex: "55A6D9")
    static let driftBG             = Color(hex: "0D0D14")
    static let driftCard           = Color(hex: "1C1C26")
    static let driftElevated       = Color(hex: "313240")
    static let driftBorder         = Color(hex: "3D3D52")
    static let driftTextPrimary    = Color.white
    static let driftTextSecondary  = Color(hex: "8888AA")
    static let driftTextTertiary   = Color(hex: "555570")
    static let driftSuccess        = Color(hex: "34D399")
    static let driftWarning        = Color(hex: "F59E0B")
    static let driftSilence        = Color(hex: "6B7280")
    static let driftGradientStart  = Color(hex: "5936D9")
    static let driftGradientEnd    = Color(hex: "55A6D9")

    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }
}

extension LinearGradient {
    static let driftGradient = LinearGradient(
        colors: [.driftGradientStart, .driftGradientEnd],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

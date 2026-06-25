import SwiftUI
import UIKit

struct AppearanceTintColorView: View {
    @AppStorage("APP.userTintColor") private var selectedColorHex: String = "#007AFF"
    @State private var selectedColor = Color(hex: "#007AFF")

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Text("整体颜色")
                    .font(.headline)
                    .foregroundColor(.primary)

                Spacer()

                HStack(spacing: 12) {
                    Circle()
                        .fill(selectedColor)
                        .frame(width: 32, height: 32)
                        .overlay(
                            Circle()
                                .strokeBorder(Color.primary.opacity(0.2), lineWidth: 2)
                        )

                    Text(selectedColorHex)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 20)

            VStack(alignment: .leading, spacing: 12) {
                Text(verbatim: "快速选择")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 20)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(presetColors, id: \.self) { color in
                            Circle()
                                .fill(color)
                                .frame(width: 44, height: 44)
                                .overlay(
                                    Circle()
                                        .strokeBorder(
                                            selectedColor == color ? Color.primary : Color.clear,
                                            lineWidth: 3
                                        )
                                )
                                .overlay(
                                    selectedColor == color ?
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(.white)
                                        .background(
                                            Circle()
                                                .fill(Color.black.opacity(0.4))
                                                .frame(width: 24, height: 24)
                                        ) : nil
                                )
                                .onTapGesture {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        selectedColor = color
                                    }

                                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                    impactFeedback.impactOccurred()
                                }
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
        .padding(.vertical, 16)
        .onChange(of: selectedColor) { newValue in
            selectedColorHex = newValue.toHex()
        }
        .onChange(of: selectedColorHex) { newValue in
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                for window in windowScene.windows {
                    window.tintColor = UIColor(Color(hex: newValue))
                }
            }

            ThemeManager.shared.objectWillChange.send()
        }
        .onAppear {
            selectedColor = Color(hex: selectedColorHex)
        }
    }

    private let presetColorHexes: [String] = [
        "#B496DC", "#848ef9", "#ff7a83", "#4161F1", "#FF00FF",
        "#4CD964", "#FF2D55", "#FF9500", "#4860e8", "#5394F7",
        "#e18aab", "#00CED1", "#228B22", "#FF6347", "#191970",
        "#FFB6C1", "#98FB98", "#E6E6FA", "#FF7F50", "#50C878"
    ]

    private var presetColors: [Color] {
        presetColorHexes.map { Color(hex: $0) }
    }
}

extension Color {
    func toHex() -> String {
        let uiColor = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        let rgb: Int = (Int)(red * 255) << 16 | (Int)(green * 255) << 8 | (Int)(blue * 255) << 0

        return String(format: "#%06x", rgb).uppercased()
    }

    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
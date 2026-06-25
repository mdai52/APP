import SwiftUI
import UIKit

struct AltIcon: Identifiable {
	var displayName: String
	var author: String
	var key: String?
	var image: UIImage
	var id: String { key ?? displayName }

	init(displayName: String, author: String, key: String? = nil) {
		self.displayName = displayName
		self.author = author
		self.key = key
		self.image = AppIconView.loadIcon(key)
	}
}

extension Image {
    func appIconStyle() -> some View {
        self
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 64, height: 64)
            .cornerRadius(13)
            .shadow(radius: 3)
            .padding(8)
    }
}

extension AppIconView {

	static func loadIcon(_ name: String?) -> UIImage {
		if let iconName = name {

			if let path = Bundle.main.path(forResource: iconName, ofType: "png", inDirectory: "AppIcons") {
				if let image = UIImage(contentsOfFile: path) {
					return image
				}
			}

			if let image = UIImage(named: iconName) {
				return image
			}

			let rootPath = Bundle.main.bundleURL.appendingPathComponent("\(iconName).png")
			if let image = UIImage(contentsOfFile: rootPath.path) {
				return image
			}
		}

		if let defaultIcon = UIImage(named: "AppIcon") {
			return defaultIcon
		}
		if let systemIcon = UIImage(systemName: "app") {
			return systemIcon
		}
		return UIImage()
	}

	static func getAllIconsFromFolder() -> [AltIcon] {
		var icons: [AltIcon] = []

		let iconInfo: [String: (displayName: String, author: String)] = [
			"app": ("默认", "图标"),
			"kana_love": ("Love", "图标"),
			"kana_peek": ("Peek", "图标")
		]

		for (key, info) in iconInfo {
			let icon = AltIcon(displayName: info.displayName, author: info.author, key: key)

			if !icon.image.isSymbolImage && icon.image.size.width > 1 {
				icons.append(icon)
			}
		}

		return icons
	}
}

struct AppIconView: View {
	@Binding var currentIcon: String?
	@State private var showingSuccess = false
	@State private var isLoading = false

	var allIcons: [AltIcon] {
		let allIcons = AppIconView.getAllIconsFromFolder()

		var icons: [AltIcon] = []

		let defaultIcon = AltIcon(displayName: "默认", author: "图标", key: "app")
		icons.append(defaultIcon)

		let alternateIcons = allIcons.filter { $0.key != "app" }
		icons.append(contentsOf: alternateIcons)

		if alternateIcons.isEmpty {
			icons.append(contentsOf: [
				AltIcon(displayName: "Love", author: "图标", key: "kana_love"),
				AltIcon(displayName: "Peek", author: "图标", key: "kana_peek")
			])
		}

		return icons
	}

	var body: some View {
		ScrollView {
			VStack(spacing: 20) {

				LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
					ForEach(allIcons) { icon in
						_icon(icon: icon)
					}
				}
				.padding(.horizontal, 16)
			}
			.padding(.bottom, 30)
		}
		.navigationTitle("图标")
		.onAppear {
			currentIcon = UIApplication.shared.alternateIconName
		}
		.overlay {
			if isLoading {
				ProgressView()
					.background(Color.black.opacity(0.5))
					.ignoresSafeArea()
			}
		}
	}
}

extension AppIconView {
	@ViewBuilder
	private func _icon(
		icon: AltIcon
	) -> some View {
		Button {

			isLoading = true

			let iconNameToSet = icon.key == "app" ? nil : icon.key

			UIApplication.shared.setAlternateIconName(iconNameToSet) { error in
				DispatchQueue.main.async {
					isLoading = false
					currentIcon = UIApplication.shared.alternateIconName
					if error == nil {
						showingSuccess = true
					} else {
						print("❌ [AppIcon] 设置图标失败: \(error!.localizedDescription)")
					}
				}
			}
		} label: {
			VStack(alignment: .center, spacing: 10) {
				ZStack {
					Image(uiImage: icon.image)
						.appIconStyle()

					if (icon.key == "app" && currentIcon == nil) || currentIcon == icon.key {
						Color.clear
							.frame(width: 100, height: 100)
							.overlay(
								RoundedRectangle(cornerRadius: 20)
									.stroke(Color.blue, lineWidth: 3)
							)
							.overlay(
								Image(systemName: "checkmark.circle.fill")
									.resizable()
									.frame(width: 24, height: 24)
									.foregroundColor(.blue)
									.position(x: 85, y: 15)
							)
					}
				}

				VStack(alignment: .center, spacing: 2) {
					Text(icon.displayName)
						.font(.system(size: 15, weight: .semibold))
						.multilineTextAlignment(.center)
					Text(icon.author)
						.font(.caption2)
						.foregroundColor(.secondary)
						.multilineTextAlignment(.center)
				}
				.frame(maxWidth: .infinity)
			}
			.padding()
			.background(Color(.systemBackground))
			.cornerRadius(16)
			.shadow(radius: 2)
		}
		.buttonStyle(.plain)
	}
}

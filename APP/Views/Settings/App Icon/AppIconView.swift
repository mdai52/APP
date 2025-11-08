
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
	
	/// 优化的图标加载方法，支持从多个位置加载图标
	static func loadIcon(_ name: String?) -> UIImage {
		if let iconName = name {
			// 从AppIcons文件夹加载（优先使用）
			if let path = Bundle.main.path(forResource: iconName, ofType: "png", inDirectory: "AppIcons") {
				if let image = UIImage(contentsOfFile: path) {
					return image
				}
			}
			
			// 直接从Bundle加载
			if let image = UIImage(named: iconName) {
				return image
			}
			
			// 从Bundle根目录加载
			let rootPath = Bundle.main.bundleURL.appendingPathComponent("\(iconName).png")
			if let image = UIImage(contentsOfFile: rootPath.path) {
				return image
			}
		}
		
		// 如果都找不到，返回默认图标
		if let defaultIcon = UIImage(named: "AppIcon") {
			return defaultIcon
		}
		if let systemIcon = UIImage(systemName: "app") {
			return systemIcon
		}
		return UIImage()
	}
	
	/// 获取AppIcons文件夹中的所有图标
	static func getAllIconsFromFolder() -> [AltIcon] {
		var icons: [AltIcon] = []
		
		// 定义已知图标信息
		let iconInfo: [String: (displayName: String, author: String)] = [
			"app": ("默认", "图标"),
			"kana_love": ("Love", "图标"),
			"kana_peek": ("Peek", "图标")
		]
		
		// 遍历已知图标
		for (key, info) in iconInfo {
			let icon = AltIcon(displayName: info.displayName, author: info.author, key: key)
			// 验证图标是否成功加载
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
	
	// 动态从AppIcons文件夹加载所有可用图标
	var allIcons: [AltIcon] {
		let allIcons = AppIconView.getAllIconsFromFolder()
		
		// 合并所有图标到一个数组中
		var icons: [AltIcon] = []
		
		// 添加默认图标
		let defaultIcon = AltIcon(displayName: "默认", author: "图标", key: "app")
		icons.append(defaultIcon)
		
		// 添加备用图标（从allIcons中排除默认图标）
		let alternateIcons = allIcons.filter { $0.key != "app" }
		icons.append(contentsOf: alternateIcons)
		
		// 如果没有备用图标，添加预定义的备用图标
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
				// 使用合并后的图标列表
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
			// 添加加载状态
			isLoading = true
			
			// 处理图标切换逻辑
			// 对于默认图标，我们应该使用nil来恢复默认图标
			let iconNameToSet = icon.key == "app" ? nil : icon.key
			
			// 执行图标切换
			UIApplication.shared.setAlternateIconName(iconNameToSet) { error in
				DispatchQueue.main.async {
					isLoading = false
					currentIcon = UIApplication.shared.alternateIconName
					showingSuccess = true
				}
			}
		} label: {
			VStack(alignment: .center, spacing: 10) {
				ZStack {
					Image(uiImage: icon.image)
						.appIconStyle()
						
					// 选中状态指示器
					// 对于默认图标，currentIcon为nil
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
						.font(.subheadline)
						.fontWeight(.semibold)
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

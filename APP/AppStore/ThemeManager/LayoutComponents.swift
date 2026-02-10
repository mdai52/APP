//
//  LayoutComponents.swift
//  APP
//
//  Created by pxx917144686 on 2026/02/10.
//

import SwiftUI

// MARK: - 响应式布局系统
struct ResponsiveLayout {
    static func columns(for geometry: GeometryProxy, minItemWidth: CGFloat = 150, spacing: CGFloat = 16) -> Int {
        let availableWidth = geometry.size.width - spacing * 2 // 减去左右边距
        let columns = Int(floor(availableWidth / (minItemWidth + spacing)))
        return max(1, columns)
    }
    
    static func spacing(for geometry: GeometryProxy, minItemWidth: CGFloat = 150, spacing: CGFloat = 16) -> CGFloat {
        let columns = ResponsiveLayout.columns(for: geometry, minItemWidth: minItemWidth, spacing: spacing)
        let availableWidth = geometry.size.width - spacing * 2 // 减去左右边距
        let totalItemWidth = CGFloat(columns) * minItemWidth
        let remainingSpace = availableWidth - totalItemWidth
        return remainingSpace / CGFloat(columns + 1)
    }
    
    static func itemWidth(for geometry: GeometryProxy, minItemWidth: CGFloat = 150, spacing: CGFloat = 16) -> CGFloat {
        let columns = ResponsiveLayout.columns(for: geometry, minItemWidth: minItemWidth, spacing: spacing)
        let actualSpacing = ResponsiveLayout.spacing(for: geometry, minItemWidth: minItemWidth, spacing: spacing)
        let availableWidth = geometry.size.width - spacing * 2 // 减去左右边距
        return (availableWidth - actualSpacing * CGFloat(columns + 1)) / CGFloat(columns)
    }
}

// MARK: - 响应式网格视图
struct ResponsiveGrid<Item: Identifiable, Content: View>: View {
    let items: [Item]
    let content: (Item, CGFloat) -> Content
    let minItemWidth: CGFloat
    let spacing: CGFloat
    let showEmptyState: Bool
    let emptyStateContent: () -> Content
    
    init(
        items: [Item],
        minItemWidth: CGFloat = 150,
        spacing: CGFloat = 16,
        showEmptyState: Bool = true,
        @ViewBuilder emptyStateContent: @escaping () -> Content = { EmptyView() as! Content },
        @ViewBuilder content: @escaping (Item, CGFloat) -> Content
    ) {
        self.items = items
        self.content = content
        self.minItemWidth = minItemWidth
        self.spacing = spacing
        self.showEmptyState = showEmptyState
        self.emptyStateContent = emptyStateContent
    }
    
    var body: some View {
        GeometryReader {
            let columns = ResponsiveLayout.columns(for: $0, minItemWidth: minItemWidth, spacing: spacing)
            let actualSpacing = ResponsiveLayout.spacing(for: $0, minItemWidth: minItemWidth, spacing: spacing)
            let itemWidth = ResponsiveLayout.itemWidth(for: $0, minItemWidth: minItemWidth, spacing: spacing)
            
            ScrollView {
                if items.isEmpty && showEmptyState {
                    VStack(alignment: .center) {
                        emptyStateContent()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(spacing * 2)
                } else {
                    LazyVGrid(
                        columns: Array(repeating: GridItem(.fixed(itemWidth), spacing: actualSpacing), count: columns),
                        spacing: actualSpacing
                    ) {
                        ForEach(items) {
                            content($0, itemWidth)
                        }
                    }
                    .padding(.horizontal, spacing)
                    .padding(.vertical, spacing)
                }
            }
        }
    }
}

// MARK: - 高级卡片组件
struct PremiumCard<Content: View>: View {
    let content: Content
    let cornerRadius: CGFloat
    let padding: CGFloat
    let isPressable: Bool
    @State private var isPressed: Bool
    
    init(
        cornerRadius: CGFloat = 24,
        padding: CGFloat = 20,
        isPressable: Bool = true,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.isPressable = isPressable
        self._isPressed = State(initialValue: false)
    }
    
    var body: some View {
        ZStack {
            // 阴影层
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(Color.black.opacity(0.1))
                .offset(y: isPressed ? 4 : 8)
                .blur(radius: isPressed ? 8 : 16)
                .opacity(isPressable ? 1 : 0)
            
            // 主卡片
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(Color(.systemBackground))
                .overlay(
                    content
                        .padding(padding)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.accentColor.opacity(0.3),
                                    Color.accentColor.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        }
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(Animation.spring(response: 0.3), value: isPressed)
        .onLongPressGesture(minimumDuration: 0, pressing: { pressing in
            if isPressable {
                withAnimation(Animation.spring(response: 0.3)) {
                    isPressed = pressing
                }
            }
        }, perform: {})
    }
}

// MARK: - 高级按钮组件
struct PremiumButton<Content: View>: View {
    let action: () -> Void
    let content: Content
    let style: ButtonStyle
    let cornerRadius: CGFloat
    let padding: EdgeInsets
    let isLoading: Bool
    let disabled: Bool
    
    enum ButtonStyle {
        case primary
        case secondary
        case outline
        case text
    }
    
    init(
        action: @escaping () -> Void,
        style: ButtonStyle = .primary,
        cornerRadius: CGFloat = 16,
        padding: EdgeInsets = EdgeInsets(top: 12, leading: 24, bottom: 12, trailing: 24),
        isLoading: Bool = false,
        disabled: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.action = action
        self.content = content()
        self.style = style
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.isLoading = isLoading
        self.disabled = disabled
    }
    
    var body: some View {
        Button(action: action, label: {
            ZStack {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                } else {
                    content
                }
            }
            .frame(maxWidth: .infinity)
            .padding(padding)
            .background(backgroundColor)
            .foregroundColor(foregroundColor)
            .cornerRadius(cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(borderColor, lineWidth: borderWidth)
            )
        })
        .disabled(disabled || isLoading)
        .buttonStyle(PlainButtonStyle())
        .animation(AnimationSystem.smooth, value: isLoading)
        .animation(AnimationSystem.smooth, value: disabled)
    }
    
    private var backgroundColor: Color {
        switch style {
        case .primary:
            return Color.accentColor
        case .secondary:
            return Color(.secondarySystemBackground)
        case .outline:
            return Color.clear
        case .text:
            return Color.clear
        }
    }
    
    private var foregroundColor: Color {
        switch style {
        case .primary:
            return Color.white
        case .secondary:
            return Color.primary
        case .outline:
            return Color.accentColor
        case .text:
            return Color.accentColor
        }
    }
    
    private var borderColor: Color {
        switch style {
        case .outline:
            return Color.accentColor
        default:
            return Color.clear
        }
    }
    
    private var borderWidth: CGFloat {
        switch style {
        case .outline:
            return 1
        default:
            return 0
        }
    }
}

// MARK: - 渐变文本
struct GradientText: View {
    let text: String
    let gradient: LinearGradient
    let font: Font
    let weight: Font.Weight
    
    init(
        _ text: String,
        gradient: LinearGradient = LinearGradient(
            colors: [Color.accentColor, Color.purple],
            startPoint: .leading,
            endPoint: .trailing
        ),
        font: Font = .system(size: 28),
        weight: Font.Weight = .bold
    ) {
        self.text = text
        self.gradient = gradient
        self.font = font
        self.weight = weight
    }
    
    var body: some View {
        Text(text)
            .font(font)
            .fontWeight(weight)
            .foregroundColor(.clear)
            .background(gradient.mask(Text(text).font(font).fontWeight(weight)))
    }
}



// MARK: - 加载状态组件
struct LoadingStateView: View {
    let message: String
    let isFullScreen: Bool
    
    init(
        message: String = "正在加载...",
        isFullScreen: Bool = true
    ) {
        self.message = message
        self.isFullScreen = isFullScreen
    }
    
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(Color.accentColor)
            
            if !message.isEmpty {
                Text(message)
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
            }
        }
        .frame(
            maxWidth: isFullScreen ? .infinity : nil,
            maxHeight: isFullScreen ? .infinity : nil
        )
        .padding(isFullScreen ? 32 : 16)
    }
}

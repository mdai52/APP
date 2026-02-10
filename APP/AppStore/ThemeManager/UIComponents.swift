//
//  UIComponents.swift
//  APP
//
//  Created by pxx917144686 on 2026/02/10.
//

import SwiftUI

// MARK: - 高级玻璃态效果
struct AdvancedGlassView: UIViewRepresentable {
    var style: UIBlurEffect.Style = .systemUltraThinMaterial
    var intensity: CGFloat = 1.0
    var tintColor: UIColor? = nil
    
    func makeUIView(context: Context) -> UIVisualEffectView {
        let blurEffect = UIBlurEffect(style: style)
        let blurView = UIVisualEffectView(effect: blurEffect)
        
        if let tintColor = tintColor {
            blurView.backgroundColor = tintColor.withAlphaComponent(0.1)
        }
        
        return blurView
    }
    
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = UIBlurEffect(style: style)
        if let tintColor = tintColor {
            uiView.backgroundColor = tintColor.withAlphaComponent(0.1)
        }
    }
}

// MARK: - 玻璃态修饰符扩展
extension View {
    func advancedGlassEffect(
        style: UIBlurEffect.Style = .systemUltraThinMaterial,
        intensity: CGFloat = 1.0,
        tintColor: Color? = nil,
        cornerRadius: CGFloat = 20,
        shadowRadius: CGFloat = 20,
        shadowOpacity: CGFloat = 0.1
    ) -> some View {
        self.background(
            ZStack {
                // 背景模糊
                AdvancedGlassView(
                    style: style,
                    intensity: intensity,
                    tintColor: tintColor.map { UIColor($0) }
                )
                .cornerRadius(cornerRadius)
                
                // 渐变叠加
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.1 * intensity),
                        Color.white.opacity(0.05 * intensity)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .cornerRadius(cornerRadius)
                
                // 边框高光
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.3 * intensity),
                                Color.white.opacity(0.1 * intensity)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
        )
        .cornerRadius(cornerRadius)
        .shadow(color: .black.opacity(shadowOpacity), radius: shadowRadius, x: 0, y: 10)
        .compositingGroup()
    }
}

// MARK: - 统一动画系统
struct AnimationSystem {
    static let spring = Animation.spring(
        response: 0.35,
        dampingFraction: 0.75,
        blendDuration: 0
    )
    
    static let smooth = Animation.easeInOut(
        duration: 0.3
    )
    
    static let bouncy = Animation.spring(
        response: 0.5,
        dampingFraction: 0.6
    )
    
    static let fast = Animation.easeInOut(
        duration: 0.15
    )
    
    static let slow = Animation.easeInOut(
        duration: 0.5
    )
}

// MARK: - 动画修饰符扩展
extension View {
    func withSpringAnimation<Value: Equatable>(
        value: Value,
        response: Double = 0.35,
        dampingFraction: Double = 0.75
    ) -> some View {
        self.animation(
            Animation.spring(
                response: response,
                dampingFraction: dampingFraction
            ),
            value: value
        )
    }
    
    func withSmoothAnimation<Value: Equatable>(
        value: Value,
        duration: Double = 0.3
    ) -> some View {
        self.animation(
            Animation.easeInOut(duration: duration),
            value: value
        )
    }
    
    func withBouncyAnimation<Value: Equatable>(
        value: Value
    ) -> some View {
        self.animation(
            AnimationSystem.bouncy,
            value: value
        )
    }
    
    func withTransition(
        insertion: AnyTransition = .scale(scale: 0.9).combined(with: .opacity),
        removal: AnyTransition = .scale(scale: 1.1).combined(with: .opacity)
    ) -> some View {
        self.transition(
            .asymmetric(
                insertion: insertion,
                removal: removal
            )
        )
    }
}

// MARK: - 骨架屏组件
struct SkeletonView<Content: View, SkeletonContent: View>: View {
    let isLoading: Bool
    let content: () -> Content
    let skeleton: () -> SkeletonContent
    
    var body: some View {
        Group {
            if isLoading {
                skeleton()
            } else {
                content()
            }
        }
    }
}

extension View {
    func skeletonable<SkeletonContent: View>(
        isLoading: Bool,
        skeleton: @escaping () -> SkeletonContent
    ) -> some View {
        SkeletonView(
            isLoading: isLoading,
            content: { self },
            skeleton: skeleton
        )
    }
}

// MARK: - 骨架屏默认样式
extension View {
    func defaultSkeleton(
        isLoading: Bool,
        cornerRadius: CGFloat = 8
    ) -> some View {
        self.skeletonable(
            isLoading: isLoading,
            skeleton: {
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(Color.gray.opacity(0.2))
                    
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.gray.opacity(0.1),
                                    Color.gray.opacity(0.3),
                                    Color.gray.opacity(0.1)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .mask(
                            Rectangle()
                                .frame(maxWidth: .infinity)
                                .offset(x: isLoading ? 300 : -300)
                                .animation(
                                    Animation.linear(duration: 1.5)
                                        .repeatForever(autoreverses: false),
                                    value: isLoading
                                )
                        )
                }
            }
        )
    }
}

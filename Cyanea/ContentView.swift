//
//  ContentView.swift
//  Cyanea
//
//  Created by Chengxin Zhao on 27/02/2025.
//

import SwiftUI

struct ContentView: View {
    @State private var dragStartLocation: CGPoint = .zero
    @State private var lastDragLocation: CGPoint = .zero
    @State private var lastDragTime: Date = Date()
    @State private var gesturePoints: [GesturePoint] = []
    @State private var showingLogs = false
    @State private var showingTutorial = true
    @State private var longPressProgress: CGFloat = 0
    
    // 添加模式选择状态
    @State private var selectedMode: BrowsingMode = .normal
    
    let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 背景
                Color.white.ignoresSafeArea()
                
                // 手势轨迹层 - 移到VStack下方，确保不会覆盖UI元素
                Canvas { context, size in
                    for point in gesturePoints {
                        let rect = CGRect(x: point.position.x - 5,
                                        y: point.position.y - 5,
                                        width: 10,
                                        height: 10)
                        
                        context.opacity = point.opacity
                        
                        switch point.type {
                        case .tap:
                            context.stroke(Circle().path(in: rect),
                                         with: .color(.blue))
                        case .drag:
                            context.fill(Circle().path(in: rect),
                                       with: .color(.red))
                        }
                    }
                }
                .allowsHitTesting(false) // 禁止Canvas接收点击事件
                
                // UI层 - 放在最上层
                VStack(spacing: 0) {
                    // 模式选择器 - 缩小高度
                    ModeSelector(selectedMode: $selectedMode, showingLogs: $showingLogs)
                        .padding(.top, 8)
                        .padding(.horizontal, 12)
                        .frame(height: 44) // 减小高度
                    
                    Spacer()
                }
                
                // 教程提示层
                if showingTutorial {
                    TutorialOverlay(isVisible: $showingTutorial)
                }
            }
            .onChange(of: selectedMode) { newMode in
                // 更新 GestureLogger 中的模式
                GestureLogger.shared.currentMode = newMode
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        // 忽略顶部区域的手势，防止与模式选择器冲突
                        if value.location.y < 60 {
                            return
                        }
                        
                        let currentTime = Date()
                        if value.translation == .zero {
                            dragStartLocation = value.location
                            lastDragLocation = value.location
                            lastDragTime = currentTime
                            GestureLogger.shared.startDragSession(at: value.location)
                        } else {
                            if GestureLogger.shared.updateDragSession(at: value.location) {
                                let newPoint = GesturePoint(position: value.location,
                                                           type: .drag,
                                                           opacity: 1.0)
                                gesturePoints.append(newPoint)
                                GestureImageRenderer.shared.addGesture([newPoint])
                            }
                            lastDragLocation = value.location
                            lastDragTime = currentTime
                        }
                    }
                    .onEnded { value in
                        // 忽略顶部区域的手势，防止与模式选择器冲突
                        if value.location.y < 60 {
                            return
                        }
                        
                        if value.translation == .zero {
                            let newPoint = GesturePoint(position: value.location,
                                                       type: .tap,
                                                       opacity: 1.0)
                            gesturePoints.append(newPoint)
                            GestureImageRenderer.shared.addGesture([newPoint])
                            
                            GestureLogger.shared.logGesture(
                                type: .tap,
                                x1: value.location.x,
                                y1: value.location.y,
                                screenSize: geometry.size
                            )
                        } else {
                            GestureLogger.shared.endDragSession(
                                at: value.location,
                                screenSize: geometry.size
                            )
                        }
                    }
            )
            .onReceive(timer) { _ in
                gesturePoints = gesturePoints.compactMap { point in
                    var updatedPoint = point
                    let age = Date().timeIntervalSince(point.timestamp)
                    if age > 2.0 {
                        return nil
                    }
                    updatedPoint.opacity = max(0, 1 - (age / 2.0))
                    return updatedPoint
                }
            }
            .sheet(isPresented: $showingLogs) {
                LogViewer()
            }
        }
    }
}

// 模式选择器组件 - 缩小并移除文字
struct ModeSelector: View {
    @Binding var selectedMode: BrowsingMode
    @Binding var showingLogs: Bool
    
    var body: some View {
        HStack(spacing: 0) {
            // 模式选择按钮
            HStack(spacing: 0) {
                ForEach(BrowsingMode.allCases) { mode in
                    Button(action: {
                        selectedMode = mode
                    }) {
                        Image(systemName: mode.icon)
                            .font(.system(size: 20))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(selectedMode == mode ? Color.blue.opacity(0.1) : Color.clear)
                            .foregroundColor(selectedMode == mode ? .blue : .gray)
                            .cornerRadius(8)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            
            // 分隔线
            Divider()
                .frame(height: 24)
                .padding(.horizontal, 2)
            
            // 日志按钮
            Button(action: {
                showingLogs = true
            }) {
                Image(systemName: "list.bullet.clipboard")
                    .font(.system(size: 20))
                    .frame(width: 40)
                    .padding(.vertical, 6)
                    .background(Color.blue.opacity(0.2))
                    .foregroundColor(.blue)
                    .cornerRadius(8)
            }
        }
        .padding(6) // 减小内边距
        .background(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                .background(Color.white.opacity(0.9))
        )
        .cornerRadius(8)
    }
}

#Preview {
    ContentView()
}

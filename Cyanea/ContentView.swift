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
    @State private var isLongPressing = false
    @State private var longPressLocation: CGPoint = .zero
    @State private var longPressStartTime: Date = Date()
    @State private var potentialLongPressLocation: CGPoint = .zero
    @State private var potentialLongPressStartTime: Date = Date()
    @State private var isPotentialLongPress = false
    
    // 添加模式选择状态
    @State private var selectedMode: BrowsingMode = .normal
    
    // 长按配置
    private let longPressDuration: TimeInterval = 1.0  // 降低到1秒
    private let longPressMoveTolerance: CGFloat = 20.0 // 允许20像素的移动
    
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
                        case .longPress:
                            // 长按使用黄色，绘制一个大一点的圆圈
                            let largerRect = CGRect(x: point.position.x - 10,
                                                  y: point.position.y - 10,
                                                  width: 20,
                                                  height: 20)
                            context.stroke(Circle().path(in: largerRect),
                                         with: .color(.yellow))
                            context.fill(Circle().path(in: rect),
                                       with: .color(.yellow.opacity(0.5)))
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
                
                // 长按指示器 - 添加延迟显示逻辑
                if isPotentialLongPress {
                    let pressDuration = Date().timeIntervalSince(potentialLongPressStartTime)
                    // 只有当按压超过0.5秒时才显示
                    if pressDuration >= 0.5 {
                        ZStack {
                            // 外圈 - 显示允许移动的范围
                            Circle()
                                .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
                                .frame(width: longPressMoveTolerance * 2 + 20, height: longPressMoveTolerance * 2 + 20)
                            
                            // 进度环 - 显示长按进度
                            Circle()
                                .trim(from: 0, to: min(1.0, (pressDuration - 0.5) / (longPressDuration - 0.5))) // 调整进度计算
                                .stroke(Color.yellow, lineWidth: 4)
                                .frame(width: 80, height: 80)
                                .rotationEffect(.degrees(-90))
                            
                            // 内圈 - 固定圆形
                            Circle()
                                .stroke(Color.yellow.opacity(0.5), lineWidth: 1)
                                .frame(width: 80, height: 80)
                        }
                        .position(potentialLongPressLocation)
                        .opacity(min(1.0, (pressDuration - 0.5) * 2)) // 渐入效果
                    }
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
                        
                        // 检查是否在长按状态
                        if isPotentialLongPress {
                            // 计算与长按起始位置的距离
                            let distance = sqrt(
                                pow(value.location.x - potentialLongPressLocation.x, 2) +
                                pow(value.location.y - potentialLongPressLocation.y, 2)
                            )
                            
                            // 如果移动超出容差范围，取消长按
                            if distance > longPressMoveTolerance {
                                isPotentialLongPress = false
                                
                                // 开始拖动
                                if dragStartLocation == .zero {
                                    dragStartLocation = value.location
                                    lastDragLocation = value.location
                                    lastDragTime = currentTime
                                    GestureLogger.shared.startDragSession(at: value.location)
                                }
                            } else {
                                // 检查是否已经达到长按时间
                                let pressDuration = currentTime.timeIntervalSince(potentialLongPressStartTime)
                                if pressDuration >= longPressDuration && !isLongPressing {
                                    isLongPressing = true
                                    longPressLocation = value.location // 使用当前位置，而不是起始位置
                                    longPressStartTime = potentialLongPressStartTime
                                    
                                    // 注意：这里不记录长按，因为我们希望在手指抬起时记录
                                }
                            }
                        } else if value.translation == .zero {
                            // 新的触摸点，可能是长按的开始
                            isPotentialLongPress = true
                            potentialLongPressLocation = value.location
                            potentialLongPressStartTime = currentTime
                            longPressProgress = 0
                            
                            // 不再使用 withAnimation，因为我们会在渲染时计算进度
                        } else {
                            // 正常的拖动处理
                            if !isLongPressing {
                                if dragStartLocation == .zero {
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
                                        GestureVideoRecorder.shared.addGesturePoint(point: value.location, type: .drag)
                                    }
                                    lastDragLocation = value.location
                                    lastDragTime = currentTime
                                }
                            }
                        }
                    }
                    .onEnded { value in
                        // 忽略顶部区域的手势，防止与模式选择器冲突
                        if value.location.y < 60 {
                            return
                        }
                        
                        // 处理长按结束
                        if isLongPressing {
                            let duration = Date().timeIntervalSince(longPressStartTime)
                            
                            // 添加长按点
                            let newPoint = GesturePoint(position: longPressLocation,
                                                      type: .longPress,
                                                      opacity: 1.0)
                            gesturePoints.append(newPoint)
                            GestureImageRenderer.shared.addGesture([newPoint])
                            GestureVideoRecorder.shared.addGesturePoint(point: longPressLocation, type: .longPress)
                            
                            // 记录长按
                            GestureLogger.shared.logLongPress(
                                x: longPressLocation.x,
                                y: longPressLocation.y,
                                duration: duration,
                                screenSize: geometry.size
                            )
                        }
                        // 处理潜在的长按结束 - 检查是否达到了长按时间但没有移动
                        else if isPotentialLongPress {
                            let pressDuration = Date().timeIntervalSince(potentialLongPressStartTime)
                            
                            // 如果已经达到长按时间，但isLongPressing没有被设置（可能因为没有移动触发onChanged）
                            if pressDuration >= longPressDuration {
                                // 添加长按点
                                let newPoint = GesturePoint(position: potentialLongPressLocation,
                                                          type: .longPress,
                                                          opacity: 1.0)
                                gesturePoints.append(newPoint)
                                GestureImageRenderer.shared.addGesture([newPoint])
                                GestureVideoRecorder.shared.addGesturePoint(point: potentialLongPressLocation, type: .longPress)
                                
                                // 记录长按
                                GestureLogger.shared.logLongPress(
                                    x: potentialLongPressLocation.x,
                                    y: potentialLongPressLocation.y,
                                    duration: pressDuration,
                                    screenSize: geometry.size
                                )
                            }
                            // 如果是短按（小于长按时间）
                            else if pressDuration < longPressDuration {
                                let newPoint = GesturePoint(position: value.location,
                                                           type: .tap,
                                                           opacity: 1.0)
                                gesturePoints.append(newPoint)
                                GestureImageRenderer.shared.addGesture([newPoint])
                                GestureVideoRecorder.shared.addGesturePoint(point: value.location, type: .tap)
                                
                                GestureLogger.shared.logGesture(
                                    type: .tap,
                                    x1: value.location.x,
                                    y1: value.location.y,
                                    screenSize: geometry.size
                                )
                            }
                        }
                        // 处理拖动结束
                        else if dragStartLocation != .zero {
                            GestureLogger.shared.endDragSession(
                                at: value.location,
                                screenSize: geometry.size
                            )
                        }
                        
                        // 重置状态
                        isPotentialLongPress = false
                        isLongPressing = false
                        dragStartLocation = .zero
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
        .onAppear {
            GestureLogger.shared.startVideoRecording()
        }
        .onDisappear {
            GestureLogger.shared.stopVideoRecording()
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

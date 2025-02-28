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
    
    let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 背景和主要内容
                Color.white.ignoresSafeArea()
                
                // 手势轨迹层
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
                
                // 教程提示层
                if showingTutorial {
                    TutorialOverlay(isVisible: $showingTutorial)
                }
                
                // 长按进度指示器
                if longPressProgress > 0 {
                    ProgressView(value: longPressProgress)
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(1.5)
                }
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
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
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 3.0, maximumDistance: 50)
                    .simultaneously(with: SpatialTapGesture(count: 3))
                    .onChanged { _ in
                        withAnimation {
                            longPressProgress = min(1.0, longPressProgress + 0.1)
                        }
                    }
                    .onEnded { value in
                        if let isPressing = value.first, isPressing {
                            showingLogs = true
                        }
                        withAnimation {
                            longPressProgress = 0
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

#Preview {
    ContentView()
}

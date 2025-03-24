import Foundation
import AVFoundation
import UIKit

class GestureVideoRecorder {
    static let shared = GestureVideoRecorder()
    
    // 存储手势序列，包括位置、类型和时间戳
    private var gestureSequence: [(point: CGPoint, type: GesturePoint.PointType, timestamp: Date)] = []
    private var startTimestamp: Date?
    private var isRecording = false
    
    // 开始记录
    func startRecording() {
        gestureSequence.removeAll()
        startTimestamp = Date()
        isRecording = true
    }
    
    // 停止记录
    func stopRecording() {
        isRecording = false
    }
    
    // 添加手势点
    func addGesturePoint(point: CGPoint, type: GesturePoint.PointType) {
        if isRecording {
            gestureSequence.append((point, type, Date()))
        }
    }
    
    // 生成视频
    func generateVideo(completion: @escaping (URL?) -> Void) {
        guard let startTime = startTimestamp, !gestureSequence.isEmpty else {
            completion(nil)
            return
        }
        
        // 创建临时文件URL
        let tempDir = FileManager.default.temporaryDirectory
        let outputURL = tempDir.appendingPathComponent("gesture_\(Date().timeIntervalSince1970).mp4")
        
        // 视频设置
        let screenSize = UIScreen.main.bounds.size
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: screenSize.width,
            AVVideoHeightKey: screenSize.height
        ]
        
        // 创建AVAssetWriter
        guard let assetWriter = try? AVAssetWriter(outputURL: outputURL, fileType: .mp4) else {
            completion(nil)
            return
        }
        
        // 添加视频输入
        let writerInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        writerInput.expectsMediaDataInRealTime = true
        
        // 设置像素缓冲区适配器
        let pixelBufferAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
            kCVPixelBufferWidthKey as String: screenSize.width,
            kCVPixelBufferHeightKey as String: screenSize.height
        ]
        
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: writerInput,
            sourcePixelBufferAttributes: pixelBufferAttributes
        )
        
        assetWriter.add(writerInput)
        
        // 开始写入会话
        assetWriter.startWriting()
        assetWriter.startSession(atSourceTime: CMTime.zero)
        
        // 获取总时长
        let endTime = gestureSequence.last?.timestamp ?? Date()
        let totalDuration = endTime.timeIntervalSince(startTime)
        
        // 创建渲染队列
        let renderQueue = DispatchQueue(label: "com.cyanea.videoRenderQueue")
        
        // 在队列中异步渲染
        renderQueue.async {
            // 帧率设置 (30fps)
            let fps: Int32 = 30
            let frameDuration = CMTimeMake(value: 1, timescale: fps)
            let frameCount = Int(totalDuration * Double(fps)) + 1
            
            // 创建上下文池
            let poolAttributes = [kCVPixelBufferPoolMinimumBufferCountKey as String: frameCount]
            var pixelBufferPool: CVPixelBufferPool?
            CVPixelBufferPoolCreate(nil, poolAttributes as CFDictionary, pixelBufferAttributes as CFDictionary, &pixelBufferPool)
            
            guard let pool = pixelBufferPool else {
                completion(nil)
                return
            }
            
            // 渲染每一帧
            for frameIndex in 0..<frameCount {
                // 计算当前帧时间点
                let frameTime = Double(frameIndex) / Double(fps)
                let currentTime = startTime.addingTimeInterval(frameTime)
                
                // 等待写入队列准备好
                while !writerInput.isReadyForMoreMediaData {
                    Thread.sleep(forTimeInterval: 0.01)
                }
                
                // 创建当前帧的像素缓冲区
                var pixelBuffer: CVPixelBuffer?
                let status = CVPixelBufferPoolCreatePixelBuffer(nil, pool, &pixelBuffer)
                
                if status != kCVReturnSuccess {
                    continue
                }
                
                guard let buffer = pixelBuffer else { continue }
                
                // 锁定像素缓冲区进行写入
                CVPixelBufferLockBaseAddress(buffer, [])
                
                // 创建CG上下文
                let context = CGContext(
                    data: CVPixelBufferGetBaseAddress(buffer),
                    width: CVPixelBufferGetWidth(buffer),
                    height: CVPixelBufferGetHeight(buffer),
                    bitsPerComponent: 8,
                    bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
                    space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
                )
                
                // 清除为透明背景
                context?.clear(CGRect(x: 0, y: 0, width: screenSize.width, height: screenSize.height))
                
                // 绘制该帧中应该显示的所有手势点
                self.drawGesturesForFrame(at: currentTime, in: context, screenSize: screenSize)
                
                // 解锁像素缓冲区
                CVPixelBufferUnlockBaseAddress(buffer, [])
                
                // 将帧附加到视频
                let presentationTime = CMTimeMultiply(frameDuration, multiplier: Int32(frameIndex))
                adaptor.append(buffer, withPresentationTime: presentationTime)
            }
            
            // 完成写入
            writerInput.markAsFinished()
            assetWriter.finishWriting {
                if assetWriter.status == .completed {
                    DispatchQueue.main.async {
                        completion(outputURL)
                    }
                } else {
                    DispatchQueue.main.async {
                        completion(nil)
                    }
                }
            }
        }
    }
    
    // 为特定时间点绘制手势轨迹
    private func drawGesturesForFrame(at time: Date, in context: CGContext?, screenSize: CGSize) {
        guard let context = context else { return }
        
        // 过滤出当前时间之前的手势点
        let visibleGestures = gestureSequence.filter { $0.timestamp <= time }
        
        // 保存最后一个拖动点的位置，用于绘制连接线
        var lastDragPoint: CGPoint?
        
        // 绘制所有可见的手势点
        for (index, gesture) in visibleGestures.enumerated() {
            // 计算点的年龄，用于淡出效果
            let age = time.timeIntervalSince(gesture.timestamp)
            let opacity = max(0, min(1.0, 1.0 - (age / 2.0))) // 2秒内淡出
            
            // 如果点已经完全淡出，跳过
            if opacity <= 0 {
                continue
            }
            
            // 根据手势类型绘制不同样式
            switch gesture.type {
            case .tap:
                // 绘制点击点（蓝色圆圈）
                let rect = CGRect(x: gesture.point.x - 5, y: gesture.point.y - 5, width: 10, height: 10)
                context.setStrokeColor(UIColor.blue.withAlphaComponent(CGFloat(opacity)).cgColor)
                context.setLineWidth(2)
                context.strokeEllipse(in: rect)
                
            case .drag:
                // 绘制拖动点（红色点）
                let rect = CGRect(x: gesture.point.x - 5, y: gesture.point.y - 5, width: 10, height: 10)
                context.setFillColor(UIColor.red.withAlphaComponent(CGFloat(opacity) * 0.2).cgColor)
                context.fillEllipse(in: rect)
                
                // 如果有前一个拖动点，绘制连接线
                if let lastPoint = lastDragPoint {
                    context.setStrokeColor(UIColor.red.withAlphaComponent(CGFloat(opacity) * 0.2).cgColor)
                    context.setLineWidth(2)
                    context.move(to: lastPoint)
                    context.addLine(to: gesture.point)
                    context.strokePath()
                }
                lastDragPoint = gesture.point
                
            case .longPress:
                // 绘制长按点（黄色圆圈）
                let largerRect = CGRect(x: gesture.point.x - 10, y: gesture.point.y - 10, width: 20, height: 20)
                context.setStrokeColor(UIColor.yellow.withAlphaComponent(CGFloat(opacity)).cgColor)
                context.setLineWidth(2)
                context.strokeEllipse(in: largerRect)
                
                let smallerRect = CGRect(x: gesture.point.x - 5, y: gesture.point.y - 5, width: 10, height: 10)
                context.setFillColor(UIColor.yellow.withAlphaComponent(CGFloat(opacity) * 0.3).cgColor)
                context.fillEllipse(in: smallerRect)
            }
        }
    }
    
    // 检查是否有记录的手势
    func hasRecordedGestures() -> Bool {
        return !gestureSequence.isEmpty
    }
} 

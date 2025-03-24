import Foundation
import CoreMotion
import UIKit

class GestureLogger {
    static let shared = GestureLogger()
    private let fileManager = FileManager.default
    private var temporaryCSVData: [String] = []
    private var savedEntries: Set<String> = []  // 用于追踪已保存的条目
    private var lastGestureType: Int = -1 // -1表示没有上一个手势
    private let motionManager = CMMotionManager()
    
    // 添加当前浏览模式
    @Published var currentMode: BrowsingMode = .normal
    
    struct LogEntry: Identifiable {
        let id = UUID()
        let timestamp: Date
        let type: EntryType
        let data: String
        let details: GestureDetails
        
        enum EntryType {
            case tap
            case drag
            case longPress
        }
    }
    
    @Published private(set) var entries: [LogEntry] = []
    private var currentDragSession: (startTime: Date, startPoint: CGPoint, lastPoint: CGPoint, lastVelocity: CGPoint, lastUpdateTime: Date)?
    
    init() {
        // 初始化CSV头，添加模式字段
        temporaryCSVData.append("start_time,end_time,type,start_x,start_y,end_x,end_y,velocity_x,velocity_y,acceleration_x,acceleration_y,total_distance,duration,orientation,motion_x,motion_y,motion_z,gesture_area,previous_gesture,browsing_mode")
        
        // 启动设备运动更新
        if motionManager.isDeviceMotionAvailable {
            motionManager.deviceMotionUpdateInterval = 1.0 / 60.0
            motionManager.startDeviceMotionUpdates()
        }
    }
    
    deinit {
        motionManager.stopDeviceMotionUpdates()
    }
    
    private func getCurrentDeviceMotion() -> (x: Double, y: Double, z: Double) {
        if let motion = motionManager.deviceMotion {
            return (
                motion.gravity.x,
                motion.gravity.y,
                motion.gravity.z
            )
        }
        return (0, 0, 0)
    }
    
    private func getDeviceOrientation() -> Int {
        let orientation = UIDevice.current.orientation
        switch orientation {
        case .portrait: return 0
        case .portraitUpsideDown: return 1
        case .landscapeLeft: return 2
        case .landscapeRight: return 3
        default: return 0
        }
    }
    
    func saveLogs() -> URL? {
        guard let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = dateFormatter.string(from: Date())
        
        // 使用固定位置以便在文件应用中可见
        let folderName = "gesture_data_\(timestamp)"
        let folderURL = documentsDirectory.appendingPathComponent(folderName)
        
        do {
            // 创建文件夹
            try fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true, attributes: nil)
            
            // 保存CSV文件
            let csvURL = folderURL.appendingPathComponent("gesture_data.csv")
            let csvContent = temporaryCSVData.joined(separator: "\n")
            try csvContent.write(to: csvURL, atomically: true, encoding: .utf8)
            
            // 保存图像
            if let image = GestureImageRenderer.shared.getCurrentImage(),
               let imageData = image.pngData() {
                let imageURL = folderURL.appendingPathComponent("gesture_visualization.png")
                try imageData.write(to: imageURL)
            }
            
            // 生成并保存视频（使用完成回调以确保文件已完成写入）
            let videoSemaphore = DispatchSemaphore(value: 0)
            GestureVideoRecorder.shared.generateVideo { videoURL in
                defer { videoSemaphore.signal() }
                
                if let videoURL = videoURL, let videoData = try? Data(contentsOf: videoURL) {
                    let finalVideoURL = folderURL.appendingPathComponent("gesture_playback.mp4")
                    try? videoData.write(to: finalVideoURL)
                }
            }
            
            // 等待视频生成完成，但设置超时以避免无限等待
            _ = videoSemaphore.wait(timeout: .now() + 10)
            
            // 添加说明文件，使文件夹的用途更加明确
            let readmeURL = folderURL.appendingPathComponent("README.txt")
            let readmeContent = """
            Cyanea 手势记录数据
            
            此文件夹包含以下文件：
            - gesture_data.csv：记录的所有手势数据
            - gesture_visualization.png：手势轨迹图像
            - gesture_playback.mp4：手势播放视频（透明背景）
            
            时间戳: \(timestamp)
            """
            try readmeContent.write(to: readmeURL, atomically: true, encoding: .utf8)
            
            // 不再尝试修改URL属性，iOS会自动使Documents目录中的文件在文件应用中可见
            
            // 显示分享控制器
            DispatchQueue.main.async {
                self.documentController = UIDocumentInteractionController(url: folderURL)
            }
            
            return folderURL
        } catch {
            print("保存失败: \(error)")
            return nil
        }
    }
    
    func clearLogs() {
        entries.removeAll()
        // 更新CSV头，包含模式字段
        temporaryCSVData = ["start_time,end_time,type,start_x,start_y,end_x,end_y,velocity_x,velocity_y,acceleration_x,acceleration_y,total_distance,duration,orientation,motion_x,motion_y,motion_z,gesture_area,previous_gesture,browsing_mode"]
        savedEntries.removeAll()
        GestureImageRenderer.shared.clearImage()
    }
    
    func logGesture(type: LogEntry.EntryType, x1: CGFloat, y1: CGFloat, screenSize: CGSize) {
        let timestamp = Date()
        let gestureTypeValue = type == .tap ? 0 : 1
        let motion = getCurrentDeviceMotion()
        let area = GestureArea.determineArea(point: CGPoint(x: x1, y: y1), in: screenSize).rawValue
        
        // 添加模式到CSV行
        let csvLine = "\(timestamp.timeIntervalSince1970),\(timestamp.timeIntervalSince1970),\(gestureTypeValue),\(x1),\(y1),\(x1),\(y1),0,0,0,0,0,0,\(getDeviceOrientation()),\(motion.x),\(motion.y),\(motion.z),\(area),\(lastGestureType),\(currentMode.rawValue)"
        
        if !savedEntries.contains(csvLine) {
            temporaryCSVData.append(csvLine)
            savedEntries.insert(csvLine)
            
            let readableLog = "Tap"  // 改为英文
            let entry = LogEntry(
                timestamp: timestamp,
                type: type,
                data: readableLog,
                details: GestureDetails(
                    orientation: getDeviceOrientation(),
                    motion: motion,
                    area: area,
                    previousGesture: lastGestureType,
                    position: nil,
                    velocity: nil,
                    acceleration: nil,
                    distance: nil,
                    duration: nil,
                    browsingMode: currentMode.rawValue
                )
            )
            entries.append(entry)
        }
        
        lastGestureType = gestureTypeValue
    }
    
    func startDragSession(at point: CGPoint) {
        let now = Date()
        currentDragSession = (now, point, point, .zero, now)
    }
    
    func updateDragSession(at point: CGPoint) -> Bool {
        guard let session = currentDragSession else { return false }
        
        let now = Date()
        let deltaTime = now.timeIntervalSince(session.lastUpdateTime)
        let deltaX = point.x - session.lastPoint.x
        let deltaY = point.y - session.lastPoint.y
        
        // 计算当前速度
        let currentVelocity = CGPoint(
            x: deltaX / CGFloat(deltaTime),
            y: deltaY / CGFloat(deltaTime)
        )
        
        // 计算加速度
        let acceleration = CGPoint(
            x: (currentVelocity.x - session.lastVelocity.x) / CGFloat(deltaTime),
            y: (currentVelocity.y - session.lastVelocity.y) / CGFloat(deltaTime)
        )
        
        // 更新会话
        currentDragSession = (
            session.startTime,
            session.startPoint,
            point,
            currentVelocity,
            now
        )
        
        // 如果超过1.5秒，结束会话
        if now.timeIntervalSince(session.startTime) > 1.5 {
            endDragSession(at: point, screenSize: UIScreen.main.bounds.size)
            return false
        }
        
        return true
    }
    
    func endDragSession(at endPoint: CGPoint, screenSize: CGSize) {
        guard let session = currentDragSession else { return }
        
        let endTime = Date()
        let totalTime = endTime.timeIntervalSince(session.startTime)
        let totalDistance = GestureSession.calculateDistance(from: session.startPoint, to: endPoint)
        let motion = getCurrentDeviceMotion()
        let startArea = GestureArea.determineArea(point: session.startPoint, in: screenSize).rawValue
        
        let avgVelocity = CGPoint(
            x: (endPoint.x - session.startPoint.x) / CGFloat(totalTime),
            y: (endPoint.y - session.startPoint.y) / CGFloat(totalTime)
        )
        
        let avgAcceleration = CGPoint(
            x: (session.lastVelocity.x - 0) / CGFloat(totalTime),
            y: (session.lastVelocity.y - 0) / CGFloat(totalTime)
        )
        
        // 添加模式到CSV行
        let csvLine = """
        \(session.startTime.timeIntervalSince1970),\
        \(endTime.timeIntervalSince1970),\
        1,\
        \(session.startPoint.x),\
        \(session.startPoint.y),\
        \(endPoint.x),\
        \(endPoint.y),\
        \(avgVelocity.x),\
        \(avgVelocity.y),\
        \(avgAcceleration.x),\
        \(avgAcceleration.y),\
        \(totalDistance),\
        \(totalTime),\
        \(getDeviceOrientation()),\
        \(motion.x),\
        \(motion.y),\
        \(motion.z),\
        \(startArea),\
        \(lastGestureType),\
        \(currentMode.rawValue)
        """
        
        if !savedEntries.contains(csvLine) {
            temporaryCSVData.append(csvLine)
            savedEntries.insert(csvLine)
            
            let readableLog = "Swipe"  // 改为英文
            
            let entry = LogEntry(
                timestamp: session.startTime,
                type: .drag,
                data: readableLog,
                details: GestureDetails(
                    orientation: getDeviceOrientation(),
                    motion: motion,
                    area: startArea,
                    previousGesture: lastGestureType,
                    position: (session.startPoint, endPoint),
                    velocity: avgVelocity,
                    acceleration: avgAcceleration,
                    distance: totalDistance,
                    duration: totalTime,
                    browsingMode: currentMode.rawValue
                )
            )
            entries.append(entry)
        }
        
        lastGestureType = 1
        currentDragSession = nil
    }
    
    func logLongPress(x: CGFloat, y: CGFloat, duration: TimeInterval, screenSize: CGSize) {
        let timestamp = Date()
        let motion = getCurrentDeviceMotion()
        let area = GestureArea.determineArea(point: CGPoint(x: x, y: y), in: screenSize).rawValue
        
        // 添加长按类型 (2 表示长按)
        let csvLine = "\(timestamp.timeIntervalSince1970),\(timestamp.timeIntervalSince1970 + duration),2,\(x),\(y),\(x),\(y),0,0,0,0,0,\(duration),\(getDeviceOrientation()),\(motion.x),\(motion.y),\(motion.z),\(area),\(lastGestureType),\(currentMode.rawValue)"
        
        if !savedEntries.contains(csvLine) {
            temporaryCSVData.append(csvLine)
            savedEntries.insert(csvLine)
            
            // 在可读日志中包含长按时间
            let readableLog = "Long Press (\(String(format: "%.1f", duration))s)"
            let entry = LogEntry(
                timestamp: timestamp,
                type: .longPress,
                data: readableLog,
                details: GestureDetails(
                    orientation: getDeviceOrientation(),
                    motion: motion,
                    area: area,
                    previousGesture: lastGestureType,
                    position: (CGPoint(x: x, y: y), CGPoint(x: x, y: y)),
                    velocity: nil,
                    acceleration: nil,
                    distance: nil,
                    duration: duration,
                    browsingMode: currentMode.rawValue
                )
            )
            entries.append(entry)
            
            // 更新上一个手势类型 (2 表示长按)
            lastGestureType = 2
        }
    }
    
    func startVideoRecording() {
        GestureVideoRecorder.shared.startRecording()
    }
    
    func stopVideoRecording() {
        GestureVideoRecorder.shared.stopRecording()
    }
    
    func generateVideo(completion: @escaping (URL?) -> Void) {
        GestureVideoRecorder.shared.generateVideo(completion: completion)
    }
    
    // 添加共享文件夹的方法
    func shareLogFolder(from viewController: UIViewController, completion: ((Bool) -> Void)? = nil) {
        guard let documentController = documentController else {
            completion?(false)
            return
        }
        
        documentController.delegate = FileShareDelegate.shared
        FileShareDelegate.shared.completionHandler = completion
        
        // 显示共享选项
        if !documentController.presentOpenInMenu(from: .zero, in: viewController.view, animated: true) {
            if !documentController.presentOptionsMenu(from: .zero, in: viewController.view, animated: true) {
                completion?(false)
            }
        }
    }
    
    // 文件共享代理
    private var documentController: UIDocumentInteractionController?
} 
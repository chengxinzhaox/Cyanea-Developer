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
    
    struct LogEntry: Identifiable {
        let id = UUID()
        let timestamp: Date
        let type: EntryType
        let data: String
        let details: GestureDetails
        
        enum EntryType {
            case tap
            case drag
        }
    }
    
    @Published private(set) var entries: [LogEntry] = []
    private var currentDragSession: (startTime: Date, startPoint: CGPoint, lastPoint: CGPoint, lastVelocity: CGPoint, lastUpdateTime: Date)?
    
    init() {
        // 初始化CSV头
        temporaryCSVData.append("start_time,end_time,type,start_x,start_y,end_x,end_y,velocity_x,velocity_y,acceleration_x,acceleration_y,total_distance,duration,orientation,motion_x,motion_y,motion_z,gesture_area,previous_gesture")
        
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
        
        // 创建时间戳文件夹
        let folderURL = documentsDirectory.appendingPathComponent("gesture_data_\(timestamp)")
        
        do {
            try fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true)
            
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
            
            return folderURL
        } catch {
            print("保存失败: \(error)")
            return nil
        }
    }
    
    func clearLogs() {
        entries.removeAll()
        temporaryCSVData = ["start_time,end_time,type,start_x,start_y,end_x,end_y,velocity_x,velocity_y,acceleration_x,acceleration_y,total_distance,duration,orientation,motion_x,motion_y,motion_z,gesture_area,previous_gesture"]
        savedEntries.removeAll()
        GestureImageRenderer.shared.clearImage()
    }
    
    func logGesture(type: LogEntry.EntryType, x1: CGFloat, y1: CGFloat, screenSize: CGSize) {
        let timestamp = Date()
        let gestureTypeValue = type == .tap ? 0 : 1
        let motion = getCurrentDeviceMotion()
        let area = GestureArea.determineArea(point: CGPoint(x: x1, y: y1), in: screenSize).rawValue
        
        let csvLine = "\(timestamp.timeIntervalSince1970),\(timestamp.timeIntervalSince1970),\(gestureTypeValue),\(x1),\(y1),\(x1),\(y1),0,0,0,0,0,0,\(getDeviceOrientation()),\(motion.x),\(motion.y),\(motion.z),\(area),\(lastGestureType)"
        
        if !savedEntries.contains(csvLine) {
            temporaryCSVData.append(csvLine)
            savedEntries.insert(csvLine)
            
            let readableLog = "触摸"  // 简化基本信息显示
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
                    duration: nil
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
        \(lastGestureType)
        """
        
        if !savedEntries.contains(csvLine) {
            temporaryCSVData.append(csvLine)
            savedEntries.insert(csvLine)
            
            let readableLog = "滑动"  // 简化基本信息显示
            
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
                    duration: totalTime
                )
            )
            entries.append(entry)
        }
        
        lastGestureType = 1
        currentDragSession = nil
    }
} 
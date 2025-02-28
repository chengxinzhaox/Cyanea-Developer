import Foundation

struct GestureSession {
    let startTime: Date
    let endTime: Date
    let startPoint: CGPoint
    let endPoint: CGPoint
    let velocity: CGPoint
    let acceleration: CGPoint
    let totalDistance: CGFloat
    
    static func calculateDistance(from start: CGPoint, to end: CGPoint) -> CGFloat {
        let deltaX = end.x - start.x
        let deltaY = end.y - start.y
        return sqrt(deltaX * deltaX + deltaY * deltaY)
    }
} 
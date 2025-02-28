import Foundation

enum GestureArea: Int {
    case topLeft = 0
    case topCenter = 1
    case topRight = 2
    case middleLeft = 3
    case middleCenter = 4
    case middleRight = 5
    case bottomLeft = 6
    case bottomCenter = 7
    case bottomRight = 8
    
    static func determineArea(point: CGPoint, in size: CGSize) -> GestureArea {
        let xSection = Int(3 * point.x / size.width)
        let ySection = Int(3 * point.y / size.height)
        
        let areaIndex = min(max(ySection * 3 + xSection, 0), 8)
        return GestureArea(rawValue: areaIndex) ?? .middleCenter
    }
} 
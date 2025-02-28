import SwiftUI

struct GesturePoint: Identifiable {
    let id = UUID()
    let position: CGPoint
    let type: PointType
    var opacity: Double
    let timestamp = Date()
    
    enum PointType {
        case tap
        case drag
    }
} 
import Foundation

enum GestureDescriptions {
    static func orientationDescription(_ value: Int) -> String {
        switch value {
        case 0: return "Portrait"
        case 1: return "Portrait Upside Down"
        case 2: return "Landscape Left"
        case 3: return "Landscape Right"
        default: return "Unknown"
        }
    }
    
    static func gestureTypeDescription(_ value: Int) -> String {
        switch value {
        case -1: return "None"
        case 0: return "Tap"
        case 1: return "Swipe"
        default: return "Unknown"
        }
    }
    
    static func areaDescription(_ value: Int) -> String {
        switch value {
        case 0: return "Top Left"
        case 1: return "Top"
        case 2: return "Top Right"
        case 3: return "Left"
        case 4: return "Center"
        case 5: return "Right"
        case 6: return "Bottom Left"
        case 7: return "Bottom"
        case 8: return "Bottom Right"
        default: return "Unknown"
        }
    }
} 
import Foundation

enum BrowsingMode: Int, CaseIterable, Identifiable {
    case shortVideo = 1
    case waterfall = 2
    case normal = 3
    
    var id: Int { rawValue }
    
    var name: String {
        switch self {
        case .shortVideo: return "Short Video"
        case .waterfall: return "Waterfall"
        case .normal: return "Normal"
        }
    }
    
    var icon: String {
        switch self {
        case .shortVideo: return "video.fill"
        case .waterfall: return "square.grid.3x3.fill"
        case .normal: return "doc.text.fill"
        }
    }
} 
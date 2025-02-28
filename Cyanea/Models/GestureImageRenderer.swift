import SwiftUI
import UIKit

class GestureImageRenderer {
    static let shared = GestureImageRenderer()
    private var currentImage: UIImage?
    private let imageSize: CGSize
    private var lastDragPoint: CGPoint?
    
    init() {
        imageSize = UIScreen.main.bounds.size
        clearImage()
    }
    
    func clearImage() {
        UIGraphicsBeginImageContextWithOptions(imageSize, false, 0.0)
        currentImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        lastDragPoint = nil
    }
    
    func addGesture(_ points: [GesturePoint]) {
        UIGraphicsBeginImageContextWithOptions(imageSize, false, 0.0)
        
        currentImage?.draw(at: .zero)
        
        if let context = UIGraphicsGetCurrentContext() {
            for point in points {
                let rect = CGRect(x: point.position.x - 5,
                                y: point.position.y - 5,
                                width: 10,
                                height: 10)
                
                if point.type == .tap {
                    context.setFillColor(UIColor.green.withAlphaComponent(0.5).cgColor)
                    context.fillEllipse(in: rect)
                } else {
                    // 滑动点
                    context.setFillColor(UIColor.red.withAlphaComponent(0.2).cgColor)
                    context.fillEllipse(in: rect)
                    
                    // 绘制连接线
                    if let lastPoint = lastDragPoint {
                        context.setStrokeColor(UIColor.red.withAlphaComponent(0.2).cgColor)
                        context.setLineWidth(2)
                        context.move(to: lastPoint)
                        context.addLine(to: point.position)
                        context.strokePath()
                    }
                    lastDragPoint = point.position
                }
            }
        }
        
        currentImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
    }
    
    func getCurrentImage() -> UIImage? {
        return currentImage
    }
    
    func saveCurrentImage() -> URL? {
        guard let image = currentImage,
              let data = image.pngData(),
              let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = dateFormatter.string(from: Date())
        
        let fileURL = documentsDirectory.appendingPathComponent("gesture_image_\(timestamp).png")
        
        do {
            try data.write(to: fileURL)
            return fileURL
        } catch {
            print("Failed to save image: \(error)")
            return nil
        }
    }
} 
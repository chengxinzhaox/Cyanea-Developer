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
                
                switch point.type {
                case .tap:
                    context.setFillColor(UIColor.green.withAlphaComponent(0.5).cgColor)
                    context.fillEllipse(in: rect)
                case .drag:
                    context.setFillColor(UIColor.red.withAlphaComponent(0.2).cgColor)
                    context.fillEllipse(in: rect)
                    
                    // 如果是滑动，绘制连接线
                    if let lastPoint = lastDragPoint {
                        context.setStrokeColor(UIColor.red.withAlphaComponent(0.2).cgColor)
                        context.setLineWidth(2)
                        context.move(to: lastPoint)
                        context.addLine(to: point.position)
                        context.strokePath()
                    }
                    lastDragPoint = point.position
                case .longPress:
                    // 长按使用黄色，绘制一个大一点的圆圈
                    let largerRect = CGRect(x: point.position.x - 10,
                                          y: point.position.y - 10,
                                          width: 20,
                                          height: 20)
                    context.setStrokeColor(UIColor.yellow.withAlphaComponent(0.7).cgColor)
                    context.setLineWidth(2)
                    context.strokeEllipse(in: largerRect)
                    
                    // 填充内部小圆
                    context.setFillColor(UIColor.yellow.withAlphaComponent(0.3).cgColor)
                    context.fillEllipse(in: rect)
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
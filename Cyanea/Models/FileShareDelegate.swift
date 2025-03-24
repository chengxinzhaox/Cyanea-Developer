import UIKit

class FileShareDelegate: NSObject, UIDocumentInteractionControllerDelegate {
    static let shared = FileShareDelegate()
    
    var completionHandler: ((Bool) -> Void)?
    
    // 当用户取消分享时调用
    func documentInteractionControllerDidDismissOpenInMenu(_ controller: UIDocumentInteractionController) {
        completionHandler?(false)
    }
    
    // 当用户成功分享文件时调用
    func documentInteractionController(_ controller: UIDocumentInteractionController, didEndSendingToApplication application: String?) {
        completionHandler?(true)
    }
    
    // 提供视图控制器用于显示界面
    func documentInteractionControllerViewControllerForPreview(_ controller: UIDocumentInteractionController) -> UIViewController {
        // 获取当前活动的视图控制器
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            return UIViewController()
        }
        
        // 如果存在模态视图控制器，则使用它
        if let presented = rootViewController.presentedViewController {
            return presented
        }
        
        return rootViewController
    }
} 
import SwiftUI
import Photos

struct GestureImagePreview: View {
    @Environment(\.dismiss) private var dismiss
    @State private var toastMessage: String? = nil
    @State private var isExporting = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black
                    .ignoresSafeArea()
                
                if let image = GestureImageRenderer.shared.getCurrentImage() {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                } else {
                    Text("No Gesture Data")
                        .foregroundColor(.white)
                }
                
                if let message = toastMessage {
                    VStack {
                        Text(message)
                            .padding()
                            .background(.ultraThinMaterial)
                            .cornerRadius(10)
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                if isExporting {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                        .frame(width: 100, height: 100)
                        .background(.ultraThinMaterial)
                        .cornerRadius(10)
                }
            }
            .navigationTitle("Gesture Visualization")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save to Album") {
                        saveImageToAlbum()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    // 保存图像到相册
    private func saveImageToAlbum() {
        guard let image = GestureImageRenderer.shared.getCurrentImage() else { return }
        
        isExporting = true
        
        PHPhotoLibrary.requestAuthorization { status in
            guard status == .authorized else {
                DispatchQueue.main.async {
                    isExporting = false
                    withAnimation {
                        toastMessage = "No permission to access photo library"
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation {
                                toastMessage = nil
                            }
                        }
                    }
                }
                return
            }
            
            UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
            
            DispatchQueue.main.async {
                isExporting = false
                withAnimation {
                    toastMessage = "Image saved to photo library"
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation {
                            toastMessage = nil
                        }
                    }
                }
            }
        }
    }
} 
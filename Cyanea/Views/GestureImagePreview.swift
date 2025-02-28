import SwiftUI

struct GestureImagePreview: View {
    @Environment(\.dismiss) private var dismiss
    @State private var toastMessage: String? = nil
    
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
                    Text("No gesture data")
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
            }
            .navigationTitle("Gesture Visualization")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        if let url = GestureImageRenderer.shared.saveCurrentImage() {
                            withAnimation {
                                toastMessage = "Saved to: \(url.lastPathComponent)"
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    withAnimation {
                                        toastMessage = nil
                                    }
                                }
                            }
                        }
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
} 
import SwiftUI

struct TutorialOverlay: View {
    @Binding var isVisible: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "hand.draw.fill")
                .font(.system(size: 40))
            Text("Swipe to record gestures")
                .font(.headline)
            Text("Long press with three fingers to view logs")
                .font(.subheadline)
        }
        .padding(30)
        .background(.ultraThinMaterial)
        .cornerRadius(20)
        .opacity(isVisible ? 1 : 0)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation {
                    isVisible = false
                }
            }
        }
    }
} 
import SwiftUI
import AVKit
import Photos

struct VideoPreview: View {
    let videoURL: URL?
    @State private var player: AVPlayer?
    @State private var isPlaying = false
    @Environment(\.dismiss) private var dismiss
    @State private var toastMessage: String? = nil
    @State private var isExporting = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black
                    .ignoresSafeArea()
                
                if let videoURL = videoURL, let player = player {
                    VideoPlayer(player: player)
                        .onAppear {
                            player.play()
                            isPlaying = true
                        }
                        .ignoresSafeArea()
                } else {
                    Text("No video available")
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
            .navigationTitle("Gesture Playback")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        player?.pause()
                        dismiss()
                    }) {
                        Text("Close")
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        if isPlaying {
                            player?.pause()
                        } else {
                            player?.play()
                        }
                        isPlaying.toggle()
                    }) {
                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        player?.seek(to: .zero)
                        player?.play()
                        isPlaying = true
                    }) {
                        Image(systemName: "arrow.counterclockwise")
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        saveVideoToAlbum()
                    }) {
                        Image(systemName: "square.and.arrow.down")
                    }
                }
            }
        }
        .onAppear {
            if let url = videoURL {
                player = AVPlayer(url: url)
            }
        }
        .onDisappear {
            player?.pause()
            player = nil
        }
    }
    
    private func saveVideoToAlbum() {
        guard let videoURL = videoURL else { return }
        
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
            
            PHPhotoLibrary.shared().performChanges {
                PHAssetCreationRequest.forAsset().addResource(with: .video, fileURL: videoURL, options: nil)
            } completionHandler: { success, error in
                DispatchQueue.main.async {
                    isExporting = false
                    withAnimation {
                        if success {
                            toastMessage = "Video saved to photo library"
                        } else {
                            toastMessage = "Save failed: \(error?.localizedDescription ?? "Unknown error")"
                        }
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
} 
import SwiftUI
import UIKit

struct GestureLogItem: Identifiable {
    let id: UUID
    let timestamp: Date
    let type: GestureLogger.LogEntry.EntryType
    let basicInfo: String
    let detailInfo: GestureDetails
}

struct GestureDetails {
    let orientation: Int
    let motion: (x: Double, y: Double, z: Double)
    let area: Int
    let previousGesture: Int
    let position: (start: CGPoint, end: CGPoint)?
    let velocity: CGPoint?
    let acceleration: CGPoint?
    let distance: CGFloat?
    let duration: TimeInterval?
    let browsingMode: Int
}

struct LogViewer: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showingClearConfirmation = false
    @State private var toastMessage: String? = nil
    @State private var expandedItems: Set<UUID> = []
    @State private var showingImagePreview = false
    @State private var showingShareSheet = false
    @State private var savedURL: URL? = nil
    
    // 添加保存进度指示器状态
    @State private var isSaving = false
    // 添加标识表示是否需要显示空状态
    @State private var showEmptyState = false
    
    var body: some View {
        NavigationView {
            ZStack {
                List {
                    if GestureLogger.shared.entries.isEmpty && showEmptyState {
                        Text("No Gesture Records")
                            .foregroundColor(.gray)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding()
                            .listRowBackground(Color.clear)
                    } else {
                        ForEach(GestureLogger.shared.entries) { entry in
                            GestureLogItemView(
                                item: GestureLogItem(
                                    id: entry.id,
                                    timestamp: entry.timestamp,
                                    type: entry.type,
                                    basicInfo: entry.data,
                                    detailInfo: entry.details
                                ),
                                isExpanded: expandedItems.contains(entry.id)
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation {
                                    if expandedItems.contains(entry.id) {
                                        expandedItems.remove(entry.id)
                                    } else {
                                        expandedItems.insert(entry.id)
                                    }
                                }
                            }
                        }
                    }
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
                
                // 保存进度指示器
                if isSaving {
                    ZStack {
                        Color.black.opacity(0.4)
                            .edgesIgnoringSafeArea(.all)
                        
                        VStack {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(1.5)
                            
                            Text("Saving...")
                                .foregroundColor(.white)
                                .padding(.top, 16)
                        }
                        .padding(30)
                        .background(.ultraThinMaterial)
                        .cornerRadius(10)
                    }
                }
            }
            .onAppear {
                showEmptyState = GestureLogger.shared.entries.isEmpty
            }
            .navigationTitle("Gesture Log")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Clear") {
                        showingClearConfirmation = true
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        Button(action: {
                            showingImagePreview = true
                        }) {
                            Image(systemName: "photo")
                        }
                        
                        Menu {
                            Button("Save") {
                                saveData()
                            }
                            
                            Button("Save & Share") {
                                saveAndShareData()
                            }
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                        }
                        
                        Button("Close") {
                            dismiss()
                        }
                    }
                }
            }
            .alert("Confirm Clear", isPresented: $showingClearConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Clear", role: .destructive) {
                    GestureLogger.shared.clearLogs()
                    showEmptyState = true
                }
            }
            .sheet(isPresented: $showingImagePreview) {
                GestureImagePreview()
            }
            .background(
                ShareSheetView(isPresented: $showingShareSheet, items: [savedURL].compactMap { $0 })
            )
        }
    }
    
    // 保存数据方法
    private func saveData() {
        isSaving = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            let url = GestureLogger.shared.saveLogs()
            
            DispatchQueue.main.async {
                isSaving = false
                
                if let url = url {
                    savedURL = url
                    // 保存后清除数据
                    GestureLogger.shared.clearLogs()
                    showEmptyState = true
                    
                    withAnimation {
                        toastMessage = "Saved to folder: \(url.lastPathComponent)"
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
    
    // 保存并分享数据
    private func saveAndShareData() {
        isSaving = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            let url = GestureLogger.shared.saveLogs()
            
            DispatchQueue.main.async {
                isSaving = false
                
                if let url = url {
                    savedURL = url
                    // 保存后清除数据
                    GestureLogger.shared.clearLogs()
                    showEmptyState = true
                    showingShareSheet = true
                }
            }
        }
    }
}

// 分享表单视图
struct ShareSheetView: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    var items: [Any]
    
    func makeUIViewController(context: Context) -> UIViewController {
        let controller = UIViewController()
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        if isPresented {
            let activityVC = UIActivityViewController(
                activityItems: items,
                applicationActivities: nil
            )
            
            activityVC.completionWithItemsHandler = { _, _, _, _ in
                isPresented = false
            }
            
            DispatchQueue.main.async {
                uiViewController.present(activityVC, animated: true, completion: nil)
            }
        }
    }
}

struct GestureLogItemView: View {
    let item: GestureLogItem
    let isExpanded: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Basic info row
            HStack {
                Image(systemName: item.type == .tap ? "hand.point.up.fill" : 
                         (item.type == .drag ? "hand.draw.fill" : "hand.tap.fill"))
                    .foregroundColor(item.type == .tap ? .blue : 
                                     (item.type == .drag ? .red : .yellow))
                
                Text(item.basicInfo)
                    .foregroundColor(.gray)
                
                Text(DateFormatter.localizedString(from: item.timestamp, dateStyle: .none, timeStyle: .medium))
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Spacer()
                
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .foregroundColor(.gray)
                    .rotationEffect(.degrees(isExpanded ? 0 : -90))
                    .animation(.spring(response: 0.3), value: isExpanded)
            }
            
            // Detailed info
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {                    
                    // Basic Properties
                    VStack(alignment: .leading, spacing: 4) {
                        DetailRow(title: "Device Orientation", value: GestureDescriptions.orientationDescription(item.detailInfo.orientation))
                        DetailRow(title: "Screen Area", value: GestureDescriptions.areaDescription(item.detailInfo.area))
                        DetailRow(title: "Previous Gesture", value: GestureDescriptions.gestureTypeDescription(item.detailInfo.previousGesture))
                        DetailRow(title: "Browsing Mode", value: getBrowsingModeName(item.detailInfo.browsingMode))
                    }
                    
                    // Position Info
                    if let position = item.detailInfo.position {
                        SectionHeader(title: "Position")
                        VStack(alignment: .leading, spacing: 4) {
                            DetailRow(title: "Start", value: formatPosition(position.start))
                            DetailRow(title: "End", value: formatPosition(position.end))
                        }
                    }
                    
                    // Motion Info
                    if let velocity = item.detailInfo.velocity {
                        SectionHeader(title: "Motion")
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading) {
                                    Text("Velocity")
                                        .foregroundColor(.gray)
                                    Text("Acceleration")
                                        .foregroundColor(.gray)
                                }
                                .frame(width: 100, alignment: .leading)
                                
                                VStack(alignment: .leading) {
                                    Text(formatVelocity(velocity))
                                    if let acceleration = item.detailInfo.acceleration {
                                        Text(formatAcceleration(acceleration))
                                    }
                                }
                            }
                            
                            if let distance = item.detailInfo.distance {
                                DetailRow(title: "Distance", value: "\(String(format: "%.1f", distance))px")
                            }
                            if let duration = item.detailInfo.duration {
                                DetailRow(title: "Duration", value: "\(String(format: "%.2f", duration))s")
                            }
                        }
                    }
                    
                    // Device Motion
                    SectionHeader(title: "Device Motion")
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("X")
                                .foregroundColor(.gray)
                                .frame(width: 20)
                            Text("\(String(format: "%.2f", item.detailInfo.motion.x))G")
                        }
                        HStack {
                            Text("Y")
                                .foregroundColor(.gray)
                                .frame(width: 20)
                            Text("\(String(format: "%.2f", item.detailInfo.motion.y))G")
                        }
                        HStack {
                            Text("Z")
                                .foregroundColor(.gray)
                                .frame(width: 20)
                            Text("\(String(format: "%.2f", item.detailInfo.motion.z))G")
                        }
                    }
                }
                .padding(.leading)
                .font(.system(.callout, design: .monospaced))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.vertical, 4)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isExpanded)
    }
    
    private func formatPosition(_ point: CGPoint) -> String {
        "L: \(String(format: "%.0f", point.x))px, T: \(String(format: "%.0f", point.y))px"
    }
    
    private func formatVelocity(_ velocity: CGPoint) -> String {
        "H: \(String(format: "%.1f", abs(velocity.x)))px/s, V: \(String(format: "%.1f", abs(velocity.y)))px/s"
    }
    
    private func formatAcceleration(_ acceleration: CGPoint) -> String {
        "H: \(String(format: "%.1f", abs(acceleration.x)))px/s², V: \(String(format: "%.1f", abs(acceleration.y)))px/s²"
    }
    
    private func getBrowsingModeName(_ value: Int) -> String {
        switch value {
        case 1: return "Short Video"
        case 2: return "Waterfall"
        case 3: return "Normal"
        default: return "Unknown"
        }
    }
}

struct SectionHeader: View {
    let title: String
    
    var body: some View {
        Text(title)
            .font(.system(.subheadline, design: .rounded))
            .fontWeight(.medium)
            .foregroundColor(.gray)
            .padding(.top, 8)
    }
}

struct DetailRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack(alignment: .top) {
            Text(title)
                .foregroundColor(.gray)
                .frame(width: 100, alignment: .leading)
            Text(value)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
} 
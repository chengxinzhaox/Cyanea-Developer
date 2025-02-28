import SwiftUI

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
}

struct LogViewer: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showingClearConfirmation = false
    @State private var toastMessage: String? = nil
    @State private var expandedItems: Set<UUID> = []
    @State private var showingImagePreview = false
    
    var body: some View {
        NavigationView {
            ZStack {
                List {
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
            .navigationTitle("Gesture Log")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Clear") {
                        showingClearConfirmation = true
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Preview") {
                        showingImagePreview = true
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        if let url = GestureLogger.shared.saveLogs() {
                            withAnimation {
                                toastMessage = "Saved to folder: \(url.lastPathComponent)"
                                GestureLogger.shared.clearLogs()
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
            .alert("Confirm Clear", isPresented: $showingClearConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Clear", role: .destructive) {
                    GestureLogger.shared.clearLogs()
                }
            }
            .sheet(isPresented: $showingImagePreview) {
                GestureImagePreview()
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
                Image(systemName: item.type == .tap ? "hand.point.up.fill" : "hand.draw.fill")
                    .foregroundColor(item.type == .tap ? .blue : .red)
                    .frame(width: 24)
                
                Text(item.type == .tap ? "Tap" : "Swipe")
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
import SwiftUI
import Charts

struct ActivityView: View {
    @EnvironmentObject var appState: AppState
    @State private var stats = ActivityStats()
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                Text("Activity Dashboard")
                    .font(.title)
                    .fontWeight(.bold)
                    .padding(.horizontal)
                
                // Stats cards
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 16) {
                    StatCard(
                        title: "Total Transcripts",
                        value: "\(appState.transcripts.count)",
                        icon: "doc.text.fill",
                        color: .blue
                    )
                    
                    StatCard(
                        title: "This Week",
                        value: "\(stats.thisWeek)",
                        icon: "calendar",
                        color: .green
                    )
                    
                    StatCard(
                        title: "Avg Confidence",
                        value: "\(Int(stats.avgConfidence * 100))%",
                        icon: "chart.bar.fill",
                        color: .orange
                    )
                }
                .padding(.horizontal)
                
                // Recent activity
                VStack(alignment: .leading, spacing: 12) {
                    Text("Recent Activity")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    VStack(spacing: 8) {
                        ForEach(appState.transcripts.prefix(10)) { transcript in
                            HStack {
                                Image(systemName: "waveform.circle.fill")
                                    .foregroundColor(.blue)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(transcript.title)
                                        .font(.subheadline)
                                    Text(relativeDate(transcript.date))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                if let confidence = transcript.confidence {
                                    ConfidenceBadge(confidence: confidence)
                                }
                            }
                            .padding()
                            .background(Color(nsColor: .controlBackgroundColor))
                            .cornerRadius(8)
                        }
                    }
                    .padding(.horizontal)
                }
                
                // Context stats
                VStack(alignment: .leading, spacing: 12) {
                    Text("Context Knowledge")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 12) {
                        ContextStatCard(
                            title: "People",
                            count: appState.contextData.people.count,
                            icon: "person.2.fill"
                        )
                        
                        ContextStatCard(
                            title: "Projects",
                            count: appState.contextData.projects.count,
                            icon: "folder.fill"
                        )
                        
                        ContextStatCard(
                            title: "Companies",
                            count: appState.contextData.companies.count,
                            icon: "building.2.fill"
                        )
                        
                        ContextStatCard(
                            title: "Terms",
                            count: appState.contextData.terms.count,
                            icon: "text.book.closed.fill"
                        )
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .onAppear {
            calculateStats()
        }
    }
    
    func calculateStats() {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        stats.thisWeek = appState.transcripts.filter { $0.date > weekAgo }.count
        
        let confidences = appState.transcripts.compactMap { $0.confidence }
        if !confidences.isEmpty {
            stats.avgConfidence = confidences.reduce(0, +) / Double(confidences.count)
        }
    }
    
    func relativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color.gradient)
                Spacer()
            }
            
            Text(value)
                .font(.system(size: 32, weight: .bold))
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
    }
}

struct ContextStatCard: View {
    let title: String
    let count: Int
    let icon: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("\(count)")
                    .font(.title2)
                    .fontWeight(.bold)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }
}

struct ActivityStats {
    var thisWeek: Int = 0
    var avgConfidence: Double = 0.0
}

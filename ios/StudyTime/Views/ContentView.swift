import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Topic.name) private var topics: [Topic]
    @Query private var sessions: [StudySession]

    @State private var selectedTab = 0
    @State private var selectedTopicId: UUID?
    @State private var canSelectTopic = true
    @State private var refreshTick = 0
    @State private var errorMessage: String?

    private var timerService: TimerService {
        TimerService(modelContext: modelContext)
    }

    private var stats: AppStats {
        _ = refreshTick
        return StatisticsService.getStats(
            topics: topics,
            sessions: sessions
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            Group {
                if selectedTab == 0 {
                    trackerTab
                } else {
                    StatisticsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            bottomTabBar
        }
        .background(Color(.systemBackground))
        .onAppear {
            if selectedTopicId == nil {
                selectedTopicId = topics.first?.id
            }
        }
        .onChange(of: topics.map(\.id)) { _, ids in
            if let selectedTopicId, ids.contains(selectedTopicId) { return }
            selectedTopicId = topics.first?.id
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                refreshTick += 1
            }
        }
        .alert("Error", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var bottomTabBar: some View {
        HStack(spacing: 0) {
            tabBarItem(title: "Tracker", systemImage: "timer", tag: 0)
            tabBarItem(title: "Statistics", systemImage: "chart.xyaxis.line", tag: 1)
            ThemeToggleButton()
                .frame(maxWidth: .infinity)
        }
        .padding(.top, 8)
        .padding(.bottom, 4)
        .background(
            Color(.secondarySystemBackground)
                .overlay(alignment: .top) {
                    Divider()
                }
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private func tabBarItem(title: String, systemImage: String, tag: Int) -> some View {
        Button {
            selectedTab = tag
        } label: {
            VStack(spacing: 3) {
                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .regular))
                Text(title)
                    .font(.system(size: 10))
            }
            .foregroundStyle(selectedTab == tag ? Color.accentColor : Color.secondary)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    private var trackerTab: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(spacing: 16) {
                        StudyTimerView(
                            topics: topics,
                            selectedTopicId: Binding(
                                get: { selectedTopicId ?? topics.first?.id },
                                set: { selectedTopicId = $0 }
                            ),
                            canSelectTopic: $canSelectTopic,
                            timerService: timerService,
                            onChange: { refreshTick += 1 }
                        )

                        Divider()
                            .padding(.horizontal, 4)

                        TrackerYearHeatmap(
                            year: TimeUtils.chicagoTodayParts().year,
                            days: stats.days,
                            todayKey: TimeUtils.chicagoTodayParts().todayKey
                        )
                    }
                    .padding(18)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.10), lineWidth: 1)
                    )

                    TopicHoursView(
                        topicStats: stats.topics,
                        selectedTopicId: Binding(
                            get: { selectedTopicId ?? topics.first?.id },
                            set: { selectedTopicId = $0 }
                        ),
                        canChangeSelection: canSelectTopic,
                        timerService: timerService,
                        onChange: { refreshTick += 1 }
                    )
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(
                LinearGradient(
                    colors: [
                        Color(.systemGroupedBackground),
                        Color(.systemGroupedBackground),
                        Color.accentColor.opacity(0.05),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .navigationTitle("Activity Logger")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    ContentView()
        .environment(ThemeStore())
        .modelContainer(for: [Topic.self, StudySession.self], inMemory: true)
}

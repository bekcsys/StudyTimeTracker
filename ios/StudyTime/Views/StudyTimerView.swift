import SwiftUI
import SwiftData

struct StudyTimerView: View {
    let topics: [Topic]
    @Binding var selectedTopicId: UUID?
    @Binding var canSelectTopic: Bool
    let timerService: TimerService
    let onChange: () -> Void

    @State private var status = "idle"
    @State private var baseElapsedSeconds = 0
    @State private var syncedAt: Date?
    @State private var displayMicros: Int64 = 0
    @State private var busy = false
    @State private var errorText: String?
    @State private var tick = 0
    @State private var pulse = false

    private var isIdle: Bool { status == "idle" }
    private var isActive: Bool { status == "active" }
    private var isPaused: Bool { status == "paused" }

    private var parts: (hours: String, minutes: String, seconds: String, micros: String) {
        _ = tick
        return FormatDuration.timerParts(totalMicroseconds: displayMicros)
    }

    private var selectedTopic: Topic? {
        topics.first { $0.id == selectedTopicId }
    }

    private var topicAccent: Color {
        if let selectedTopic {
            return Color(hex: selectedTopic.color)
        }
        return Color.accentColor
    }

    var body: some View {
        VStack(spacing: 14) {
            displayWell

            if let errorText {
                Text(errorText)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .onAppear {
            sync()
            if isActive {
                withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                    pulse = true
                }
            }
        }
        .onChange(of: status) { _, newStatus in
            if newStatus == "active" {
                withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                    pulse = true
                }
            } else {
                withAnimation(.easeOut(duration: 0.2)) {
                    pulse = false
                }
            }
        }
        .onReceive(Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()) { _ in
            updateDisplay()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            sync()
        }
    }

    private var displayWell: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.92),
                            Color(red: 0.08, green: 0.10, blue: 0.14),
                            Color.black.opacity(0.88),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Circle()
                .fill(topicAccent.opacity(isActive ? 0.28 : 0.12))
                .frame(width: 160, height: 160)
                .blur(radius: 36)
                .scaleEffect(pulse ? 1.08 : 1)
                .allowsHitTesting(false)

            VStack(spacing: 18) {
                Text("\(parts.hours):\(parts.minutes):\(parts.seconds).\(parts.micros)")
                    .font(.system(size: 36, weight: .medium, design: .monospaced))
                    .foregroundStyle(BrandColor.timer)
                    .monospacedDigit()
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .accessibilityLabel("\(parts.hours):\(parts.minutes):\(parts.seconds).\(parts.micros)")

                HStack(spacing: 20) {
                    // Play ↔ Pause
                    iconCircle(
                        systemImage: isActive ? "pause.fill" : "play.fill",
                        fill: startFill,
                        iconColor: startText,
                        ring: startRing,
                        enabled: !busy && (isActive || isPaused || (selectedTopicId != nil && !topics.isEmpty)),
                        accessibilityLabel: isActive ? "Pause" : "Play"
                    ) {
                        if isActive {
                            runAction { try timerService.pause() }
                        } else if isPaused {
                            runAction { try timerService.resume() }
                        } else {
                            guard let selectedTopicId else { return }
                            runAction { try timerService.start(topicId: selectedTopicId) }
                        }
                    }

                    // Stop & save
                    iconCircle(
                        systemImage: "xmark",
                        fill: stopFill,
                        iconColor: stopText,
                        ring: stopRing,
                        enabled: !busy && !isIdle,
                        accessibilityLabel: "Stop and save"
                    ) {
                        runAction { try timerService.stop() }
                    }
                }
                .padding(.top, 4)
            }
            .padding(.vertical, 18)
            .padding(.horizontal, 12)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private var startFill: Color { Color.clear }
    private var startText: Color { BrandColor.timer }
    private var startRing: Color { Color.white.opacity(0.14) }

    private var stopFill: Color { Color.clear }
    private var stopText: Color { Color(red: 1.0, green: 0.42, blue: 0.42) }
    private var stopRing: Color { Color.white.opacity(0.14) }

    private func iconCircle(
        systemImage: String,
        fill: Color,
        iconColor: Color,
        ring: Color,
        enabled: Bool,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
                    .frame(width: 40, height: 40)

                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(iconColor)
                    .shadow(color: iconColor.opacity(0.35), radius: 0, y: 0)
            }
            .frame(width: 40, height: 40)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.4)
        .accessibilityLabel(accessibilityLabel)
    }

    private func sync() {
        do {
            let state = try timerService.timerState()
            apply(state)
        } catch {
            errorText = "Could not load timer"
        }
    }

    private func apply(_ state: TimerState) {
        status = state.status
        canSelectTopic = state.status == "idle"
        baseElapsedSeconds = state.elapsedSeconds
        syncedAt = .now
        if let topicId = state.topicId {
            selectedTopicId = topicId
        }
        if state.status == "idle" && state.elapsedSeconds == 0 {
            displayMicros = 0
        } else if state.status == "active" {
            displayMicros = Int64(state.elapsedSeconds) * 1_000_000
        } else {
            let whole = Int64(state.elapsedSeconds) * 1_000_000
            displayMicros = whole + (displayMicros % 1_000_000)
        }
        errorText = nil
        tick += 1
    }

    private func updateDisplay() {
        guard isActive, let syncedAt else { return }
        let elapsed = Date().timeIntervalSince(syncedAt)
        let micros = Int64(baseElapsedSeconds) * 1_000_000 + Int64(elapsed * 1_000_000)
        displayMicros = max(0, micros)
        tick += 1
    }

    private func runAction(_ action: () throws -> TimerState) {
        busy = true
        defer { busy = false }
        do {
            let state = try action()
            apply(state)
            onChange()
        } catch {
            errorText = error.localizedDescription
        }
    }
}

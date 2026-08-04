import SwiftUI
import SwiftData

struct TopicHoursView: View {
    let topicStats: [TopicStat]
    @Binding var selectedTopicId: UUID?
    let canChangeSelection: Bool
    let timerService: TimerService
    let onChange: () -> Void

    @State private var isEditing = false
    @State private var editingTopicId: UUID?
    @State private var editingName = ""
    @State private var errorText: String?
    @State private var newTopicName = ""
    @AppStorage("activityTypeTitle") private var activityTypeTitle = "Study"
    @State private var isEditingTypeTitle = false
    @State private var draftTypeTitle = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                if isEditingTypeTitle {
                    TextField("Activity type", text: $draftTypeTitle)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .textFieldStyle(.roundedBorder)
                        .onSubmit(saveTypeTitle)

                    Button("Save") { saveTypeTitle() }
                        .font(.caption.weight(.semibold))

                    Button("Cancel") {
                        isEditingTypeTitle = false
                        draftTypeTitle = ""
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                } else {
                    Button {
                        draftTypeTitle = activityTypeTitle
                        isEditingTypeTitle = true
                    } label: {
                        HStack(spacing: 5) {
                            Text(activityTypeTitle.uppercased())
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .tracking(1.2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                            Image(systemName: "pencil")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Edit activity type")

                    Spacer()

                    Button {
                        if isEditing {
                            exitEditMode()
                        } else {
                            enterEditMode()
                        }
                    } label: {
                        if isEditing {
                            Text("Done")
                                .font(.caption.weight(.semibold))
                        } else {
                            Label("Edit", systemImage: "pencil")
                                .font(.caption.weight(.semibold))
                                .labelStyle(.titleAndIcon)
                        }
                    }
                    .disabled(!canChangeSelection && !isEditing)
                }
            }

            if topicStats.isEmpty && !isEditing {
                Text("No activities yet")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(topicStats.enumerated()), id: \.element.id) { index, topic in
                        topicRow(topic)

                        if index < topicStats.count - 1 {
                            Divider()
                                .padding(.leading, isEditing ? 0 : 28)
                        }
                    }
                }
            }

            if isEditing {
                HStack(spacing: 8) {
                    TextField("New activity", text: $newTopicName)
                        .textFieldStyle(.roundedBorder)
                        .font(.subheadline)
                        .onSubmit(createTopic)

                    Button("Add") { createTopic() }
                        .font(.caption.weight(.semibold))
                        .disabled(newTopicName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }

            if let errorText {
                Text(errorText)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func topicRow(_ topic: TopicStat) -> some View {
        let isSelected = selectedTopicId == topic.id

        if isEditing && editingTopicId == topic.id {
            HStack(spacing: 10) {
                TextField("Name", text: $editingName)
                    .textFieldStyle(.roundedBorder)
                    .font(.subheadline)
                    .onSubmit { saveRename(topic.id) }
                Button("Save") { saveRename(topic.id) }
                    .font(.caption.weight(.semibold))
                Button("Cancel") {
                    editingTopicId = nil
                    editingName = ""
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding(.vertical, 8)
        } else if isEditing {
            HStack(spacing: 10) {
                Text(topic.name)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer()
                Button {
                    editingTopicId = topic.id
                    editingName = topic.name
                } label: {
                    Image(systemName: "pencil")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Rename \(topic.name)")

                encodingDot(topic.color)
            }
            .padding(.vertical, 10)
        } else {
            Button {
                guard canChangeSelection else { return }
                selectedTopicId = topic.id
            } label: {
                HStack(spacing: 12) {
                    selectionDot(filled: isSelected)

                    Text(topic.name)
                        .font(.subheadline.weight(isSelected ? .semibold : .medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    Spacer(minLength: 0)

                    encodingDot(topic.color)
                }
                .padding(.vertical, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!canChangeSelection)
            .opacity(canChangeSelection ? 1 : 0.55)
        }
    }

    private func encodingDot(_ hex: String) -> some View {
        Circle()
            .fill(Color(hex: hex))
            .frame(width: 7, height: 7)
            .accessibilityHidden(true)
    }

    private func selectionDot(filled: Bool) -> some View {
        ZStack {
            if filled {
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 18, height: 18)
            } else {
                Circle()
                    .strokeBorder(Color.primary.opacity(0.35), lineWidth: 1.5)
                    .frame(width: 18, height: 18)
            }
        }
        .frame(width: 18, height: 18)
    }

    private func enterEditMode() {
        isEditing = true
        editingTopicId = nil
        editingName = ""
        newTopicName = ""
        errorText = nil
    }

    private func exitEditMode() {
        isEditing = false
        editingTopicId = nil
        editingName = ""
        newTopicName = ""
        errorText = nil
    }

    private func saveRename(_ id: UUID) {
        do {
            _ = try timerService.renameTopic(id: id, name: editingName)
            editingTopicId = nil
            editingName = ""
            errorText = nil
            onChange()
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func createTopic() {
        do {
            let topic = try timerService.createTopic(name: newTopicName)
            selectedTopicId = topic.id
            newTopicName = ""
            errorText = nil
            onChange()
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func saveTypeTitle() {
        let cleaned = draftTypeTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleaned.isEmpty {
            activityTypeTitle = cleaned
        }
        isEditingTypeTitle = false
        draftTypeTitle = ""
    }
}

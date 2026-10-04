import SwiftUI
import Models

struct MemoEditorToolbar: View {
    let tags: [Tag]
    let onInsertTag: (Tag?) -> Void
    let onToggleTodo: () -> Void
    let onPickJournalingSuggestion: () -> Void
    let supportsJournalingSuggestions: Bool
    let onPickPhotos: () -> Void
    let onPickCamera: () -> Void
    let supportsDocumentScanning: Bool
    let onScanDocument: () -> Void
    let onPickFiles: () -> Void
    @Binding var isFocused: Bool

    private func icon(_ title: LocalizedStringKey, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .labelStyle(.iconOnly)
            .font(.system(size: 20))
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
    }

    private var writingTools: some View {
        HStack(spacing: 0) {
            Button(action: onToggleTodo) {
                icon("input.toggle-checklist", systemImage: "checklist")
            }

            Menu {
                Button("input.new-tag", systemImage: "number") {
                    onInsertTag(nil)
                }
                if !tags.isEmpty {
                    Section {
                        ForEach(tags) { tag in
                            Button(tag.name) { onInsertTag(tag) }
                        }
                    }
                }
            } label: {
                icon("input.insert-tag", systemImage: "number")
            }

            Menu {
                Button("input.photos", systemImage: "photo.on.rectangle", action: onPickPhotos)
                Button("input.camera", systemImage: "camera", action: onPickCamera)
                if supportsDocumentScanning {
                    Button("input.scan", systemImage: "doc.viewfinder", action: onScanDocument)
                }
                Button("input.files", systemImage: "doc", action: onPickFiles)
                if supportsJournalingSuggestions {
                    Section {
                        Button("input.journaling", systemImage: "wand.and.sparkles", action: onPickJournalingSuggestion)
                    }
                }
            } label: {
                icon("input.attach", systemImage: "paperclip")
            }
        }
        .buttonStyle(.borderless)
        .padding(4)
    }

    private var keyboardButton: some View {
        Button {
            isFocused.toggle()
        } label: {
            icon(
                isFocused ? "input.hide-keyboard" : "input.show-keyboard",
                systemImage: isFocused ? "keyboard.chevron.compact.down" : "keyboard"
            )
        }
        .buttonStyle(.borderless)
        .padding(4)
    }

    var body: some View {
        if #available(iOS 26, *) {
            GlassEffectContainer(spacing: 12) {
                HStack(spacing: 12) {
                    writingTools
                        .glassEffect(.regular.interactive(), in: .capsule)
                    Spacer(minLength: 12)
                    keyboardButton
                        .glassEffect(.regular.interactive(), in: .circle)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        } else {
            HStack(spacing: 12) {
                writingTools
                Spacer(minLength: 12)
                keyboardButton
            }
            .padding(.horizontal, 12)
            .background(.bar)
        }
    }
}

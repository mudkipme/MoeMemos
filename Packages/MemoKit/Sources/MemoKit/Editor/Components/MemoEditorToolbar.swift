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
    
    @ViewBuilder
    private var contentView: some View {
        HStack(alignment: .center, spacing: 16) {
            if !tags.isEmpty {
                Menu {
                    ForEach(tags) { tag in
                        Button(tag.name) {
                            onInsertTag(tag)
                        }
                    }
                } label: {
                    Label("input.insert-tag", systemImage: "number")
                        .labelStyle(.iconOnly)
                }
            } else {
                Button {
                    onInsertTag(nil)
                } label: {
                    Label("input.insert-tag", systemImage: "number")
                        .labelStyle(.iconOnly)
                }
            }

            Button {
                onToggleTodo()
            } label: {
                Label("input.toggle-checklist", systemImage: "checkmark.square")
                        .labelStyle(.iconOnly)
            }

            if supportsJournalingSuggestions {
                Button {
                    onPickJournalingSuggestion()
                } label: {
                    Label("input.journaling", systemImage: "wand.and.sparkles")
                        .labelStyle(.iconOnly)
                }
            }

            Button {
                onPickPhotos()
            } label: {
                Label("input.photos", systemImage: "photo.on.rectangle")
                        .labelStyle(.iconOnly)
            }

            Button {
                onPickCamera()
            } label: {
                Label("input.camera", systemImage: "camera")
                        .labelStyle(.iconOnly)
            }

            if supportsDocumentScanning {
                Button {
                    onScanDocument()
                } label: {
                    Label("input.scan", systemImage: "doc.viewfinder")
                        .labelStyle(.iconOnly)
                }
            }

            Button {
                onPickFiles()
            } label: {
                Label("input.files", systemImage: "doc")
                        .labelStyle(.iconOnly)
            }
            
            Spacer()
        }
        .padding(.horizontal, 20)
    }

    var body: some View {
        if #available(iOS 26, *) {
            GlassEffectContainer(spacing: 10) {
                VStack {
                    contentView
                        .padding(.vertical, 16)
                        .glassEffect(.regular.interactive())
                        .background(.bar.opacity(0.2))
                        .padding(.horizontal, 16)
                }
                .padding(.bottom)
            }
        } else {
            contentView
                .frame(height: 20)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial)
        }
    }
}

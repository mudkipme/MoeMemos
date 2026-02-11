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
                    Image(systemName: "number")
                }
            } else {
                Button {
                    onInsertTag(nil)
                } label: {
                    Image(systemName: "number")
                }
            }

            Button {
                onToggleTodo()
            } label: {
                Image(systemName: "checkmark.square")
            }

            if supportsJournalingSuggestions {
                Button {
                    onPickJournalingSuggestion()
                } label: {
                    Image(systemName: "wand.and.sparkles")
                }
            }

            Button {
                onPickPhotos()
            } label: {
                Image(systemName: "photo.on.rectangle")
            }

            Button {
                onPickCamera()
            } label: {
                Image(systemName: "camera")
            }

            Button {
                onPickFiles()
            } label: {
                Image(systemName: "doc")
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

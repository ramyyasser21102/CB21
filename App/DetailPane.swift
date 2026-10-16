import AppKit
import SwiftUI
import CB21Core

/// Shows one selected Clip in full with its Metadata, or a hint when there isn't exactly one.
struct DetailPane: View {
    let selection: Set<UUID>
    let load: (UUID) async -> Clip?
    let folderAccess: FolderAccessModel

    var body: some View {
        if selection.count == 1, let id = selection.first {
            ClipDetail(id: id, load: load, folderAccess: folderAccess)
        } else {
            ContentUnavailableView(
                selection.isEmpty ? "Select a clip" : "\(selection.count) clips selected",
                systemImage: "sidebar.right",
                description: Text(selection.isEmpty ? "Choose a clip on the left to see its details." : "Select a single clip to see its details.")
            )
        }
    }
}

private struct Loaded: Equatable {
    let id: UUID
    let displayText: DisplayText?
    let metadata: ClipMetadata
}

private struct ClipDetail: View {
    let id: UUID
    let load: (UUID) async -> Clip?
    let folderAccess: FolderAccessModel
    /// Folders that must be allowed before this file clip may be read. Reading it earlier would make macOS show a
    /// surprise permission prompt.
    @State private var locked: [ProtectedFolder] = []
    @State private var loaded: Loaded?
    @State private var preview: NSImage?
    @State private var previewState = PreviewState.none
    @State private var missing = false

    private enum PreviewState { case none, loading, ready, unavailable }

    var body: some View {
        Group {
            if !locked.isEmpty {
                lockedPlaceholder
            } else if let loaded, loaded.id == id {
                content(loaded)
            } else if missing {
                ContentUnavailableView("Clip not found", systemImage: "questionmark.folder")
            } else {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        // Reading and decoding happens off the main thread, so a big image or PDF can't freeze the window.
        .task(id: TaskKey(id: id, accessRevision: folderAccess.revision)) {
            missing = false
            locked = []
            preview = nil
            previewState = .none
            guard let clip = await load(id) else { missing = true; return }
            // Decide from the stored text, before touching the file in any way.
            if let text = clip.fileURLText {
                let blocked = FileAccessGuard.requiredFolders(forFileURLText: text).filter { folder in
                    let state = folderAccess.state(for: folder)
                    return state != .allowed && state != .missing
                }
                if !blocked.isEmpty {
                    locked = blocked
                    return
                }
            }
            let result = await Task.detached(priority: .userInitiated) {
                Loaded(id: id, displayText: clip.displayText(), metadata: clip.metadata())
            }.value
            loaded = result
            // The facts show first; the picture fills in when it is ready.
            if clip.hasPicture {
                previewState = .loading
                let image = await PreviewCache.shared.image(for: clip)
                guard !Task.isCancelled else { return }
                preview = image
                previewState = image == nil ? .unavailable : .ready
            }
        }
    }

    private struct TaskKey: Equatable {
        let id: UUID
        let accessRevision: Int
    }

    private var lockedPlaceholder: some View {
        let names = locked.map(\.displayName)
        let list = names.count > 1 ? names.dropLast().joined(separator: ", ") + " and " + (names.last ?? "") : (names.first ?? "")
        return ContentUnavailableView {
            Label("This file is in \(list)", systemImage: "lock")
        } description: {
            Text("macOS asks before an app may look inside \(list). Allow access to see this file's details and preview.")
        } actions: {
            Button("Allow Access…") {
                Task { await folderAccess.requestAccess(for: locked) }
            }
            Button("Open System Settings") {
                if let url = URL(string: SystemSettingsLink.filesAndFolders) { NSWorkspace.shared.open(url) }
            }
            .buttonStyle(.link)
        }
    }

    @ViewBuilder
    private func content(_ item: Loaded) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                switch item.metadata.detail {
                case .text(let facts):
                    textBody(item.displayText, facts)
                case .link(let facts):
                    LabeledBlock("Link") {
                        Text(facts.url).textSelection(.enabled)
                    }
                case .image, .pdf, .file:
                    picture
                }
                facts(item.metadata)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var picture: some View {
        switch previewState {
        case .ready:
            if let preview {
                Image(nsImage: preview)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: 360)
                    .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 6))
                    .accessibilityLabel("Preview")
            }
        case .loading:
            ProgressView().frame(maxWidth: .infinity, minHeight: 120)
        case .unavailable:
            Label("No preview available", systemImage: "eye.slash")
                .font(.callout).foregroundStyle(.secondary)
        case .none:
            EmptyView()
        }
    }

    @ViewBuilder
    private func textBody(_ shown: DisplayText?, _ facts: TextFacts?) -> some View {
        if let shown {
            Text(shown.text)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
                .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 6))
            if shown.isTruncated {
                Text("Showing the first \(DisplayText.defaultLimit.formatted()) characters.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        } else {
            Text("Rich text").foregroundStyle(.secondary)
        }
    }

    private func facts(_ meta: ClipMetadata) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            switch meta.detail {
            case .text(let t?):
                row("Characters", t.characters.formatted())
                row("Words", t.words.formatted())
                row("Lines", t.lines.formatted())
            case .image(let i?):
                row("Dimensions", "\(i.pixelWidth) × \(i.pixelHeight) px")
                row("Format", i.format)
            case .pdf(let p?):
                row("Pages", p.pageCount.formatted())
                if let title = p.title { row("Title", title) }
            case .file(let f):
                row("Name", f.name)
                row("Folder", f.folder)
                if f.exists {
                    if let kind = f.kind { row("Kind", kind) }
                    if let size = f.fileSize { row("File size", ClipSubtitle.size(size)) }
                    if let modified = f.modified { row("Modified", modified.formatted(date: .abbreviated, time: .shortened)) }
                    if let pdf = f.pdf {
                        row("Pages", pdf.pageCount.formatted())
                        if let title = pdf.title { row("Title", title) }
                    }
                } else {
                    Label("File no longer exists", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                }
            case .link(let l):
                if let host = l.host { row("Host", host) }
            default:
                EmptyView()
            }
            Divider().padding(.vertical, 4)
            row("Copied", meta.createdAt.formatted(date: .abbreviated, time: .shortened))
            row("Last used", meta.lastUsedAt.formatted(date: .abbreviated, time: .shortened))
            row("Stored size", ClipSubtitle.size(meta.byteCount))
            if let source = meta.sourceAppName { row("Source app", source) }
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label).foregroundStyle(.secondary).frame(width: 90, alignment: .leading)
            Text(value).textSelection(.enabled)
            Spacer(minLength: 0)
        }
        .font(.callout)
    }
}

private struct LabeledBlock<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            content
        }
    }
}


private extension Clip {
    /// Images, PDFs and files can show a picture; text and links can't.
    var hasPicture: Bool {
        switch preferred.kind {
        case .image, .pdf, .file: true
        case .link, .richText, .plainText: false
        }
    }
}

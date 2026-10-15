import SwiftUI
import CB21Core

/// One Clip's preview line, shown in the History window.
struct ClipLabel: View {
    let row: HistoryModel.Row

    @ViewBuilder
    var body: some View {
        switch row.preview {
        case .text(let text):
            Text(text)
        case .link(let url):
            Label(url, systemImage: "link")
        case .file(let name):
            Label(name, systemImage: "doc")
        case .pdf:
            Label("PDF", systemImage: "doc.richtext")
        case .image:
            if let thumbnail = row.thumbnail {
                Label { Text("Image") } icon: { Image(nsImage: thumbnail) }
            } else {
                Label("Image", systemImage: "photo")
            }
        }
    }
}

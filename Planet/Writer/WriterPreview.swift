import SwiftUI

struct WriterPreview: View {
    let draft: DraftModel
    let lastRender: Date

    var body: some View {
        WriterWebView(draft: draft, lastRender: lastRender)
            .background(Color(NSColor.textBackgroundColor))
            .frame(minWidth: 320, minHeight: 400)
    }
}

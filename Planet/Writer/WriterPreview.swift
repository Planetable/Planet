import SwiftUI

struct WriterPreview: View {
    let draft: DraftModel

    var body: some View {
        WriterWebView(draft: draft)
            .background(Color(NSColor.textBackgroundColor))
            .frame(minWidth: 320, minHeight: 400)
    }
}

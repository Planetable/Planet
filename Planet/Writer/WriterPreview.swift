import SwiftUI

struct WriterPreview: View {
    var url: URL?

    var body: some View {
        VStack {
            WriterWebView(url: url ?? Bundle.main.url(forResource: "WriterBasicPlaceholder", withExtension: "html")!)
        }.background(Color(NSColor.textBackgroundColor))
    }
}

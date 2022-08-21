import SwiftUI

struct SharingServicePicker: NSViewRepresentable {
    @Binding var isPresented: Bool
    var sharingItems: [Any] = []

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if isPresented {
            let picker = NSSharingServicePicker(items: sharingItems)
            picker.delegate = context.coordinator
            DispatchQueue.main.async {
                picker.show(relativeTo: .zero, of: nsView, preferredEdge: .minY)
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(owner: self)
    }

    class Coordinator: NSObject, NSSharingServicePickerDelegate {
        let owner: SharingServicePicker

        init(owner: SharingServicePicker) {
            self.owner = owner
        }

        func sharingServicePicker(
            _ sharingServicePicker: NSSharingServicePicker,
            sharingServicesForItems items: [Any],
            proposedSharingServices proposedServices: [NSSharingService]
        ) -> [NSSharingService] {
            guard let image = NSImage(systemSymbolName: "link", accessibilityDescription: "Link") else {
                return proposedServices
            }
            var share = proposedServices
            let copyService = NSSharingService(title: "Copy Link", image: image, alternateImage: image) {
                if let item = items.first as? URL {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(item.absoluteString, forType: .string)
                }
            }
            share.insert(copyService, at: 0)
            return share
        }

        func sharingServicePicker(_ sharingServicePicker: NSSharingServicePicker, didChoose service: NSSharingService?) {
            sharingServicePicker.delegate = nil
            self.owner.isPresented = false
        }
    }
}

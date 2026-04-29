import QuickLook
import SafariServices
import SwiftUI

struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

struct QuickLookFile: Identifiable {
    let id = UUID()
    let url: URL
}

struct QuickLookView: UIViewControllerRepresentable {
    let file: QuickLookFile

    func makeCoordinator() -> Coordinator {
        Coordinator(file: file)
    }

    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: QLPreviewController, context: Context) {}

    final class Coordinator: NSObject, QLPreviewControllerDataSource {
        let file: QuickLookFile

        init(file: QuickLookFile) {
            self.file = file
        }

        func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
            1
        }

        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            file.url as NSURL
        }
    }
}

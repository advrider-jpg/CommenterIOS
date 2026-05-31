import Foundation
import SwiftUI

#if canImport(UIKit)
import UIKit

struct ActivityShareSheet: UIViewControllerRepresentable {
    let url: URL
    let onCompletion: (Result<Bool, Error>) -> Void

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        controller.completionWithItemsHandler = { _, completed, _, error in
            if let error {
                onCompletion(.failure(error))
            } else {
                onCompletion(.success(completed))
            }
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#else
struct ActivityShareSheet: View {
    let url: URL
    let onCompletion: (Result<Bool, Error>) -> Void

    var body: some View {
        Text("Native sharing is available from the iOS app target.")
            .padding()
            .onAppear { onCompletion(.success(false)) }
    }
}
#endif

import SwiftUI
import UIKit

/// 카메라 한 장 (BRU-43).
///
/// SwiftUI에는 카메라를 여는 것이 없다 — `PhotosPicker`는 보관함만 연다.
/// 그래서 여기만 UIKit을 얇게 감싼다. 찍은 사진은 앱의 기존 첨부 경로로 넘어간다.
struct CameraPicker: UIViewControllerRepresentable {
    /// JPEG 데이터. 취소하면 불리지 않는다.
    let onCapture: (Data) -> Void

    @Environment(\.dismiss) private var dismiss

    /// 시뮬레이터·카메라 없는 기기에서는 아예 띄우지 않는다 —
    /// 빈 화면이 뜨고 아무 일도 일어나지 않는 것이 가장 나쁘다.
    static var isAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let controller = UIImagePickerController()
        controller.sourceType = .camera
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_: UIImagePickerController, context _: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onCapture: onCapture, onFinish: { dismiss() })
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        private let onCapture: (Data) -> Void
        private let onFinish: () -> Void

        init(onCapture: @escaping (Data) -> Void, onFinish: @escaping () -> Void) {
            self.onCapture = onCapture
            self.onFinish = onFinish
        }

        func imagePickerController(
            _: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage, let data = image.jpegData(compressionQuality: 0.9) {
                onCapture(data)
            }
            onFinish()
        }

        func imagePickerControllerDidCancel(_: UIImagePickerController) {
            onFinish()
        }
    }
}

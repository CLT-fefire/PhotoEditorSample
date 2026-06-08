import UIKit
import Photos

/// 편집 결과를 사진 앨범에 저장한다. iOS 12 호환 클래식 권한 플로우 사용.
enum PhotoSaver {

    enum SaveResult {
        case success
        case denied          // 권한 거부
        case failed(Error?)  // 기타 실패
    }

    static func save(_ image: UIImage, completion: @escaping (SaveResult) -> Void) {

        func performSave() {
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }, completionHandler: { ok, error in
                DispatchQueue.main.async {
                    completion(ok ? .success : .failed(error))
                }
            })
        }

        let status = PHPhotoLibrary.authorizationStatus()
        switch status {
        case .authorized:
            performSave()
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization { newStatus in
                if newStatus == .authorized {
                    performSave()
                } else {
                    DispatchQueue.main.async { completion(.denied) }
                }
            }
        default: // .denied, .restricted (그리고 iOS 14+ .limited는 add 권한으로 충분하나 보수적으로 처리)
            DispatchQueue.main.async { completion(.denied) }
        }
    }
}

import UIKit
import CoreImage
import Metal

/// Core Image 합성 파이프라인. 모든 도구는 단일 공식으로 합성된다:
///   CIBlendWithMask(source, background: 현재결과, mask: 스트로크경로)
/// 도구별로 source(드러낼 이미지)만 다르다.
///   - 모자이크 → CIPixellate(원본)
///   - 블러     → CIGaussianBlur(원본)
///   - 지우개   → 원본 그 자체
///   - 브러시   → 단색 채움
///
/// source는 항상 **원본**에서 필터링하여 시각적으로 깔끔하고 순서 의존성을 줄인다.
/// CIContext는 생성 비용이 크므로 앱 전역에서 1개만 재사용한다.
final class ImageCompositor {

    static let shared = ImageCompositor()

    let context: CIContext

    private init() {
        if let device = MTLCreateSystemDefaultDevice() {
            context = CIContext(mtlDevice: device)
        } else {
            context = CIContext(options: [.useSoftwareRenderer: false])
        }
    }

    // MARK: - 단일 스트로크 합성

    /// `base` 위에 스트로크 하나를 합성한다. `base`와 `original`은 동일 픽셀 크기(.up, scale 1)여야 한다.
    func apply(stroke: Stroke, base: UIImage, original: UIImage) -> UIImage {
        guard let baseCG = base.cgImage, let origCG = original.cgImage else { return base }

        let baseCI = CIImage(cgImage: baseCG)
        let origCI = CIImage(cgImage: origCG)
        let extent = baseCI.extent
        guard extent.width >= 1, extent.height >= 1 else { return base }

        let alpha: CGFloat = (stroke.tool == .brush) ? stroke.opacity : 1.0
        guard let maskUI = MaskRenderer.maskImage(for: stroke, imageSize: extent.size, alpha: alpha),
              let maskCG = maskUI.cgImage else { return base }
        let maskCI = CIImage(cgImage: maskCG)

        let source = sourceImage(for: stroke, original: origCI, extent: extent)

        let output = source.applyingFilter("CIBlendWithMask", parameters: [
            kCIInputBackgroundImageKey: baseCI,
            kCIInputMaskImageKey: maskCI
        ])

        guard let outCG = context.createCGImage(output, from: extent) else { return base }
        return UIImage(cgImage: outCG)
    }

    /// 스트로크 스택 전체를 원본 위에 순서대로 재합성한다 (Undo·원본 해상도 저장에 사용).
    func render(strokes: [Stroke], original: UIImage) -> UIImage {
        var result = original
        for stroke in strokes {
            result = apply(stroke: stroke, base: result, original: original)
        }
        return result
    }

    // MARK: - 라이브 미리보기용 전체 필터 이미지

    /// 터치 시작 시 1회 계산하여 CanvasView가 마스크로 드러낼 "전체 필터 이미지".
    func previewFiltered(tool: EditTool,
                         original: UIImage,
                         mosaicScale: CGFloat,
                         blurSigma: CGFloat) -> UIImage? {
        guard let cg = original.cgImage else { return nil }
        let ci = CIImage(cgImage: cg)
        let extent = ci.extent
        guard extent.width >= 1, extent.height >= 1 else { return nil }

        let out: CIImage
        switch tool {
        case .mosaic:
            out = pixellate(ci, scaleFraction: mosaicScale, extent: extent)
        case .blur:
            out = blur(ci, radiusFraction: blurSigma, extent: extent)
        case .eraser, .brush:
            return original
        }

        guard let outCG = context.createCGImage(out, from: extent) else { return nil }
        return UIImage(cgImage: outCG)
    }

    // MARK: - source 생성

    private func sourceImage(for stroke: Stroke, original: CIImage, extent: CGRect) -> CIImage {
        switch stroke.tool {
        case .mosaic:
            return pixellate(original, scaleFraction: stroke.mosaicScale, extent: extent)
        case .blur:
            return blur(original, radiusFraction: stroke.blurSigma, extent: extent)
        case .eraser:
            return original                          // 원본 드러내기
        case .brush:
            let color = CIColor(color: stroke.color)
            return CIImage(color: color).cropped(to: extent)
        }
    }

    private func pixellate(_ image: CIImage, scaleFraction: CGFloat, extent: CGRect) -> CIImage {
        let minDim = min(extent.width, extent.height)
        let scale = max(1, scaleFraction * minDim)
        return image
            .applyingFilter("CIPixellate", parameters: [
                kCIInputScaleKey: scale,
                kCIInputCenterKey: CIVector(x: extent.midX, y: extent.midY)
            ])
            .cropped(to: extent)
    }

    private func blur(_ image: CIImage, radiusFraction: CGFloat, extent: CGRect) -> CIImage {
        let minDim = min(extent.width, extent.height)
        let radius = max(0.1, radiusFraction * minDim)
        // clampedToExtent: 가장자리가 투명/수축되는 것을 방지한 뒤 원본 extent로 crop.
        return image
            .clampedToExtent()
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: radius])
            .cropped(to: extent)
    }
}

import UIKit

/// 스트로크 경로를 그레이스케일 마스크 이미지(흰색=적용, 검정=미적용)로 렌더한다.
/// 결과는 지정한 픽셀 크기로 그려지며 CIBlendWithMask의 inputMaskImage로 사용된다.
enum MaskRenderer {

    /// - Parameters:
    ///   - stroke: 정규화 좌표/반경을 가진 스트로크.
    ///   - imageSize: 마스크를 그릴 픽셀 크기 (= 대상 이미지 extent).
    ///   - alpha: 브러시 투명도 등으로 마스크 강도를 낮출 때 사용 (0...1).
    static func maskImage(for stroke: Stroke, imageSize: CGSize, alpha: CGFloat = 1.0) -> UIImage? {
        guard imageSize.width >= 1, imageSize.height >= 1 else { return nil }

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1          // 픽셀 = 포인트 (마스크를 이미지 픽셀 공간에 정확히 일치시킴)
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: imageSize, format: format)

        let minDim = min(imageSize.width, imageSize.height)
        let lineWidth = max(1, stroke.brushRadius * minDim * 2)
        let white = UIColor(white: 1, alpha: clamp01(alpha))

        // 정규화 → 픽셀 좌표.
        let pts = stroke.points.map {
            CGPoint(x: $0.x * imageSize.width, y: $0.y * imageSize.height)
        }

        return renderer.image { ctx in
            let c = ctx.cgContext
            // 배경: 검정 (미적용 영역).
            c.setFillColor(UIColor.black.cgColor)
            c.fill(CGRect(origin: .zero, size: imageSize))

            guard !pts.isEmpty else { return }

            c.setLineCap(.round)
            c.setLineJoin(.round)
            c.setStrokeColor(white.cgColor)
            c.setFillColor(white.cgColor)
            c.setLineWidth(lineWidth)

            if pts.count == 1 {
                // 단일 탭 → 점(원)으로 표현.
                let p = pts[0]
                c.fillEllipse(in: CGRect(x: p.x - lineWidth / 2,
                                         y: p.y - lineWidth / 2,
                                         width: lineWidth,
                                         height: lineWidth))
            } else {
                let path = CGMutablePath()
                path.addLines(between: pts)
                c.addPath(path)
                c.strokePath()
            }
        }
    }

    private static func clamp01(_ v: CGFloat) -> CGFloat { min(1, max(0, v)) }
}

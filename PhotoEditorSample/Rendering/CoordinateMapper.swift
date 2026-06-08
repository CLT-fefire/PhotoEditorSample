import UIKit

/// view 좌표 ↔ 정규화 이미지 좌표(0...1) ↔ 이미지 픽셀 좌표 변환.
///
/// 이미지는 view 안에 aspect-fit(레터박스)으로 표시되므로, 터치 좌표를 정규화 좌표로 옮기려면
/// 먼저 fitted rect 기준으로 환산해야 한다. 마스크 렌더는 이미지 픽셀 공간에서 수행해야
/// CIBlendWithMask와 정합한다. (좌표 공간 불일치는 이 류 기능의 최다 버그 발원지)
struct CoordinateMapper {

    let viewSize: CGSize
    /// 작업 이미지의 픽셀 크기.
    let imageSize: CGSize

    /// 이미지가 view 안에서 차지하는 aspect-fit 사각형.
    var fittedRect: CGRect {
        guard imageSize.width > 0, imageSize.height > 0,
              viewSize.width > 0, viewSize.height > 0 else { return .zero }
        let scale = min(viewSize.width / imageSize.width,
                        viewSize.height / imageSize.height)
        let w = imageSize.width * scale
        let h = imageSize.height * scale
        let x = (viewSize.width - w) * 0.5
        let y = (viewSize.height - h) * 0.5
        return CGRect(x: x, y: y, width: w, height: h)
    }

    /// view 좌표 → 정규화(0...1). 이미지 밖이어도 0...1로 클램프하여 마스크가 이미지 안에 머물게 한다.
    func normalizedPoint(fromView p: CGPoint) -> CGPoint {
        let r = fittedRect
        guard r.width > 0, r.height > 0 else { return .zero }
        let nx = (p.x - r.minX) / r.width
        let ny = (p.y - r.minY) / r.height
        return CGPoint(x: clamp01(nx), y: clamp01(ny))
    }

    /// 정규화(0...1) → view 좌표.
    func viewPoint(fromNormalized n: CGPoint) -> CGPoint {
        let r = fittedRect
        return CGPoint(x: r.minX + n.x * r.width,
                       y: r.minY + n.y * r.height)
    }

    /// 정규화(0...1) → 이미지 픽셀 좌표.
    func imagePoint(fromNormalized n: CGPoint) -> CGPoint {
        return CGPoint(x: n.x * imageSize.width, y: n.y * imageSize.height)
    }

    private func clamp01(_ v: CGFloat) -> CGFloat {
        return min(1, max(0, v))
    }
}

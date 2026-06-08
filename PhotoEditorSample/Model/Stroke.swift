import UIKit

/// 하나의 편집 동작(스트로크). 픽셀에 즉시 굽지 않고 이 객체들의 순서 있는 배열로 보관하며,
/// 표시 시점에 ImageCompositor가 합성한다. Undo = 스택 pop, 지우개 = 원본 드러내기.
///
/// 좌표·크기는 모두 **정규화(0...1)** 저장 — 작업 해상도에서 편집하고 원본 해상도에서 동일하게 재렌더하기 위함.
struct Stroke {
    let tool: EditTool

    /// 정규화 이미지 좌표(0...1)의 경로 점들.
    var points: [CGPoint]

    /// 이미지 최단변 대비 브러시 반경 비율.
    var brushRadius: CGFloat

    // 도구별 파라미터 (모두 이미지 최단변 대비 비율 또는 0...1)
    var mosaicScale: CGFloat
    var blurSigma: CGFloat
    var color: UIColor
    var opacity: CGFloat

    init(config: StrokeConfig, points: [CGPoint]) {
        self.tool = config.tool
        self.points = points
        self.brushRadius = config.brushRadius
        self.mosaicScale = config.mosaicScale
        self.blurSigma = config.blurSigma
        self.color = config.color
        self.opacity = config.opacity
    }
}

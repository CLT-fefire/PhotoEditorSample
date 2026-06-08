import UIKit

/// 편집 문서. 원본(작업 해상도)과 스트로크 스택, 그리고 누적 합성 결과를 보관한다.
///
/// - commit: 스트로크를 스택에 push하고 합성 결과를 증분 갱신(1회 합성).
/// - undo:   스택 pop 후 남은 스트로크로 전체 재합성(스트로크 수가 적어 충분히 빠름).
final class EditDocument {

    /// 작업 해상도 원본 (.up 방향, scale 1).
    let original: UIImage

    private(set) var strokes: [Stroke] = []

    /// 현재 화면에 표시할 누적 합성 결과.
    private(set) var composited: UIImage

    init(original: UIImage) {
        self.original = original
        self.composited = original
    }

    var canUndo: Bool { !strokes.isEmpty }

    /// 스트로크 하나를 확정하고 합성 결과를 증분 갱신한다.
    func commit(_ stroke: Stroke) {
        guard !stroke.points.isEmpty else { return }
        strokes.append(stroke)
        composited = ImageCompositor.shared.apply(stroke: stroke,
                                                   base: composited,
                                                   original: original)
    }

    /// 직전 스트로크를 되돌린다. 되돌릴 게 있으면 true.
    @discardableResult
    func undo() -> Bool {
        guard !strokes.isEmpty else { return false }
        strokes.removeLast()
        composited = ImageCompositor.shared.render(strokes: strokes, original: original)
        return true
    }
}

import UIKit

protocol CanvasViewDelegate: AnyObject {
    /// 터치 시작 시 현재 도구 설정을 제공한다.
    func canvasViewCurrentConfig(_ canvas: CanvasView) -> StrokeConfig?
    /// 스트로크가 완성되면 호출 (정규화 좌표 포함).
    func canvasView(_ canvas: CanvasView, didComplete stroke: Stroke)
}

/// 이미지 표시 + 손가락 드로잉 + 라이브 미리보기.
///
/// 라이브 미리보기: 진행 중 도구의 "전체 필터 이미지"를 base 위 overlay에 깔고,
/// 터치 경로로 만든 CAShapeLayer를 overlay의 layer mask로 사용 → 경로를 따라 필터가 드러난다.
/// Core Image는 터치마다 호출하지 않고(60fps 유지), 터치 업에 1회만 합성한다.
final class CanvasView: UIView {

    weak var delegate: CanvasViewDelegate?

    /// 라이브 미리보기 source 계산에 쓰이는 작업 원본.
    var workingOriginal: UIImage?

    /// 작업 이미지의 픽셀 크기 (좌표 매핑/마스크 기준).
    var imageSize: CGSize = .zero

    /// 화면에 표시할 누적 합성 결과.
    var displayImage: UIImage? {
        didSet { baseImageView.image = displayImage }
    }

    // MARK: - Subviews

    private let baseImageView = UIImageView()
    private let overlayImageView = UIImageView()
    private let shapeLayer = CAShapeLayer()

    // MARK: - 진행 중 스트로크 상태

    private var activeConfig: StrokeConfig?
    private var viewPoints: [CGPoint] = []   // view 좌표 (라이브 path)
    private var normPoints: [CGPoint] = []   // 정규화 좌표 (확정용)
    private var bezier = UIBezierPath()

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        backgroundColor = .clear
        isMultipleTouchEnabled = false

        baseImageView.contentMode = .scaleAspectFit
        baseImageView.isUserInteractionEnabled = false
        addSubview(baseImageView)

        overlayImageView.contentMode = .scaleAspectFit
        overlayImageView.isUserInteractionEnabled = false
        overlayImageView.isHidden = true
        addSubview(overlayImageView)

        shapeLayer.fillColor = UIColor.clear.cgColor
        shapeLayer.strokeColor = UIColor.white.cgColor   // 마스크: 흰색 = 드러냄
        shapeLayer.lineCap = .round
        shapeLayer.lineJoin = .round
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        baseImageView.frame = bounds
        overlayImageView.frame = bounds
        shapeLayer.frame = overlayImageView.bounds
    }

    // MARK: - Coordinate helper

    private var mapper: CoordinateMapper {
        CoordinateMapper(viewSize: bounds.size, imageSize: imageSize)
    }

    // MARK: - Touch handling

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard imageSize != .zero,
              let cfg = delegate?.canvasViewCurrentConfig(self),
              let touch = touches.first else { return }

        let p = touch.location(in: self)
        let fitted = mapper.fittedRect
        guard fitted.contains(p) else { return }   // 이미지 밖 터치 무시

        activeConfig = cfg
        viewPoints = [p]
        normPoints = [mapper.normalizedPoint(fromView: p)]

        bezier = UIBezierPath()
        bezier.move(to: p)
        bezier.addLine(to: CGPoint(x: p.x + 0.1, y: p.y))   // 단일 탭에서도 점이 보이도록

        // 라이브 미리보기 구성
        overlayImageView.image = livePreviewImage(for: cfg)
        overlayImageView.alpha = (cfg.tool == .brush) ? clamp01(cfg.opacity) : 1.0

        let lineWidth = cfg.brushRadius * min(fitted.width, fitted.height) * 2
        shapeLayer.lineWidth = max(1, lineWidth)
        shapeLayer.path = bezier.cgPath
        overlayImageView.layer.mask = shapeLayer
        overlayImageView.isHidden = false
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard activeConfig != nil, let touch = touches.first else { return }
        let p = touch.location(in: self)
        viewPoints.append(p)
        normPoints.append(mapper.normalizedPoint(fromView: p))
        bezier.addLine(to: p)
        shapeLayer.path = bezier.cgPath
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        finishStroke()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        finishStroke()
    }

    private func finishStroke() {
        defer { resetOverlay() }
        guard let cfg = activeConfig, !normPoints.isEmpty else { return }
        let stroke = Stroke(config: cfg, points: normPoints)
        delegate?.canvasView(self, didComplete: stroke)
    }

    private func resetOverlay() {
        activeConfig = nil
        viewPoints = []
        normPoints = []
        bezier = UIBezierPath()
        overlayImageView.layer.mask = nil
        overlayImageView.image = nil
        overlayImageView.isHidden = true
    }

    // MARK: - Live preview image

    private func livePreviewImage(for cfg: StrokeConfig) -> UIImage? {
        guard let original = workingOriginal else { return nil }
        switch cfg.tool {
        case .eraser:
            return original
        case .brush:
            return solidColorImage(cfg.color, size: imageSize)
        case .mosaic, .blur:
            return ImageCompositor.shared.previewFiltered(tool: cfg.tool,
                                                          original: original,
                                                          mosaicScale: cfg.mosaicScale,
                                                          blurSigma: cfg.blurSigma)
        }
    }

    private func solidColorImage(_ color: UIColor, size: CGSize) -> UIImage? {
        guard size.width >= 1, size.height >= 1 else { return nil }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            color.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
    }

    private func clamp01(_ v: CGFloat) -> CGFloat { min(1, max(0, v)) }
}

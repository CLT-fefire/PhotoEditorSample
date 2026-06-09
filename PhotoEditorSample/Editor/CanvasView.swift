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

    /// 브러시 크기 인디케이터: 외곽선만 있는 원. 손가락을 따라다니며 작업 위치·굵기를 보여준다.
    private let brushIndicatorLayer = CAShapeLayer()
    /// 굵기 슬라이더 미리보기의 자동 숨김 작업(다음 표시 시 취소).
    private var previewHideWork: DispatchWorkItem?

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

        // 외곽선만 있는 원. 흰 선 + 검은 그림자로 밝거나 어두운 사진 위에서도 보이게 한다.
        brushIndicatorLayer.fillColor = UIColor.clear.cgColor
        brushIndicatorLayer.strokeColor = UIColor.white.cgColor
        brushIndicatorLayer.lineWidth = 2
        brushIndicatorLayer.shadowColor = UIColor.black.cgColor
        brushIndicatorLayer.shadowOpacity = 0.6
        brushIndicatorLayer.shadowRadius = 2
        brushIndicatorLayer.shadowOffset = .zero
        brushIndicatorLayer.opacity = 0          // 평소엔 숨김(투명)
        layer.addSublayer(brushIndicatorLayer)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        baseImageView.frame = bounds
        overlayImageView.frame = bounds
        shapeLayer.frame = overlayImageView.bounds
        brushIndicatorLayer.frame = bounds
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

        // 크기 인디케이터를 손가락 위치에 즉시 표시 (슬라이더 미리보기 자동숨김이 예약돼 있으면 취소).
        previewHideWork?.cancel()
        setIndicator(center: p, diameter: max(1, lineWidth))
        showIndicatorInstant()
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard activeConfig != nil, let touch = touches.first else { return }
        let p = touch.location(in: self)
        viewPoints.append(p)
        normPoints.append(mapper.normalizedPoint(fromView: p))
        bezier.addLine(to: p)
        shapeLayer.path = bezier.cgPath
        setIndicator(center: p, diameter: shapeLayer.lineWidth)   // 인디케이터가 손가락을 따라간다
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
        fadeOutIndicator()
    }

    // MARK: - 브러시 크기 인디케이터

    /// 굵기 슬라이더 변경 시: 이미지 중앙에 현재 브러시 지름의 원을 잠깐 보여준다.
    func showBrushSizePreview() {
        guard imageSize != .zero,
              let cfg = delegate?.canvasViewCurrentConfig(self) else { return }
        let fitted = mapper.fittedRect
        guard fitted.width > 0, fitted.height > 0 else { return }
        let diameter = max(1, cfg.brushRadius * min(fitted.width, fitted.height) * 2)
        setIndicator(center: CGPoint(x: fitted.midX, y: fitted.midY), diameter: diameter)
        showIndicatorInstant()

        previewHideWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.fadeOutIndicator() }
        previewHideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9, execute: work)
    }

    /// 인디케이터 원의 위치·지름 갱신. 암묵적 애니메이션을 꺼 손가락을 지연 없이 따라가게 한다.
    private func setIndicator(center: CGPoint, diameter: CGFloat) {
        let d = max(1, diameter)
        let rect = CGRect(x: center.x - d / 2, y: center.y - d / 2, width: d, height: d)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        brushIndicatorLayer.path = UIBezierPath(ovalIn: rect).cgPath
        CATransaction.commit()
    }

    private func showIndicatorInstant() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        brushIndicatorLayer.removeAllAnimations()   // 진행 중인 페이드아웃 취소 (깜빡임 방지)
        brushIndicatorLayer.opacity = 1
        CATransaction.commit()
    }

    private func fadeOutIndicator() {
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.25)
        brushIndicatorLayer.opacity = 0
        CATransaction.commit()
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

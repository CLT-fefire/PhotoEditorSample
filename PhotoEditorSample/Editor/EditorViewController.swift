import UIKit

/// 편집 화면 오케스트레이터. 상단 바(불러오기/저장) + 캔버스 + 파라미터 슬라이더 + 하단 도구 바를 소유하고,
/// 도구/파라미터 상태를 StrokeConfig로 합쳐 CanvasView에 제공한다.
final class EditorViewController: UIViewController {

    // MARK: - UI

    private let topBar = UIView()
    private let titleLabel = UILabel()
    private let loadButton = UIButton(type: .system)
    private let saveButton = UIButton(type: .system)
    private let placeholderLabel = UILabel()

    private let canvasScrollView = UIScrollView()
    private let canvasView = CanvasView()
    private let parameterView = ParameterSliderView()
    private let toolbarView = ToolbarView()

    // MARK: - State

    private var document: EditDocument?
    /// 저장용 원본 해상도 이미지(.up, scale 1). 정규화 스트로크를 이 위에 재렌더하여 고해상도로 저장.
    private var fullOriginal: UIImage?
    /// 캔버스 가시 영역이 실제로 바뀔 때만 줌 대상 frame을 다시 잡기 위한 캐시.
    private var lastLaidOutCanvasSize: CGSize = .zero

    private var currentTool: EditTool = .mosaic
    private var currentColor: BrushColor { BrushColor(rawValue: parameterView.selectedColorIndex) ?? .red }

    private let workingMaxDimension: CGFloat = 2048
    private let fullMaxDimension: CGFloat = 4096

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        buildUI()
        applyLoadedState(false)
        parameterView.configure(for: currentTool)
        toolbarView.selectTool(currentTool)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // 줌 대상(canvasView)은 frame으로 관리한다. 가시 영역 크기가 실제로 바뀔 때만 다시 잡아
        // 줌 진행 중 불필요한 리셋을 피한다. zoomScale==1에서 canvasView.frame == scrollView.bounds.
        let size = canvasScrollView.bounds.size
        guard size.width > 0, size.height > 0, size != lastLaidOutCanvasSize else { return }
        lastLaidOutCanvasSize = size
        canvasScrollView.setZoomScale(1, animated: false)   // 회전 등 크기 변경 시 줌 리셋
        canvasView.frame = CGRect(origin: .zero, size: size)
        canvasScrollView.contentSize = size
        canvasView.applyZoomScale(1)
    }

    // MARK: - UI build

    private func buildUI() {
        // 상단 바
        topBar.backgroundColor = .white
        topBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(topBar)

        loadButton.setTitle("불러오기", for: .normal)
        loadButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        loadButton.addTarget(self, action: #selector(loadTapped), for: .touchUpInside)
        loadButton.translatesAutoresizingMaskIntoConstraints = false
        topBar.addSubview(loadButton)

        saveButton.setTitle("저장", for: .normal)
        saveButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        saveButton.addTarget(self, action: #selector(saveTapped), for: .touchUpInside)
        saveButton.translatesAutoresizingMaskIntoConstraints = false
        topBar.addSubview(saveButton)

        titleLabel.text = "사진 편집"
        titleLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        titleLabel.textColor = .darkText
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        topBar.addSubview(titleLabel)

        // 캔버스: UIScrollView로 감싸 핀치 줌/팬을 지원한다. 1손가락 = 드로잉, 2손가락 = 팬+줌.
        canvasScrollView.delegate = self
        canvasScrollView.backgroundColor = UIColor(white: 0.96, alpha: 1)
        canvasScrollView.minimumZoomScale = 1
        canvasScrollView.maximumZoomScale = 4
        canvasScrollView.bouncesZoom = true
        canvasScrollView.showsHorizontalScrollIndicator = false
        canvasScrollView.showsVerticalScrollIndicator = false
        canvasScrollView.delaysContentTouches = false                    // 드로잉 첫 점 지연 제거
        canvasScrollView.panGestureRecognizer.minimumNumberOfTouches = 2 // 1손가락은 드로잉으로 흘려보냄
        canvasScrollView.contentInsetAdjustmentBehavior = .never
        canvasScrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(canvasScrollView)

        // canvasView는 스크롤뷰의 줌 대상 → frame으로 관리(autoresizing mask 기본값 유지).
        canvasView.delegate = self
        canvasView.backgroundColor = UIColor(white: 0.96, alpha: 1)
        canvasScrollView.addSubview(canvasView)

        placeholderLabel.text = "‘불러오기’를 눌러 사진을 선택하세요"
        placeholderLabel.font = .systemFont(ofSize: 15)
        placeholderLabel.textColor = .gray
        placeholderLabel.textAlignment = .center
        placeholderLabel.numberOfLines = 0
        placeholderLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(placeholderLabel)   // 줌 대상 밖(이미지 로드 전에만 표시되므로 줌과 무관)

        // 파라미터 + 도구 바
        parameterView.delegate = self
        parameterView.backgroundColor = .white
        parameterView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(parameterView)

        toolbarView.delegate = self
        toolbarView.backgroundColor = .white
        toolbarView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(toolbarView)

        let guide = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            topBar.topAnchor.constraint(equalTo: guide.topAnchor),
            topBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            topBar.heightAnchor.constraint(equalToConstant: 52),

            loadButton.leadingAnchor.constraint(equalTo: topBar.leadingAnchor, constant: 16),
            loadButton.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),
            saveButton.trailingAnchor.constraint(equalTo: topBar.trailingAnchor, constant: -16),
            saveButton.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),
            titleLabel.centerXAnchor.constraint(equalTo: topBar.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),

            canvasScrollView.topAnchor.constraint(equalTo: topBar.bottomAnchor),
            canvasScrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            canvasScrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            placeholderLabel.centerXAnchor.constraint(equalTo: canvasScrollView.centerXAnchor),
            placeholderLabel.centerYAnchor.constraint(equalTo: canvasScrollView.centerYAnchor),
            placeholderLabel.leadingAnchor.constraint(greaterThanOrEqualTo: canvasScrollView.leadingAnchor, constant: 24),
            placeholderLabel.trailingAnchor.constraint(lessThanOrEqualTo: canvasScrollView.trailingAnchor, constant: -24),

            parameterView.topAnchor.constraint(equalTo: canvasScrollView.bottomAnchor),
            parameterView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            parameterView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            parameterView.heightAnchor.constraint(equalToConstant: 124),

            toolbarView.topAnchor.constraint(equalTo: parameterView.bottomAnchor),
            toolbarView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            toolbarView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            toolbarView.bottomAnchor.constraint(equalTo: guide.bottomAnchor),
            toolbarView.heightAnchor.constraint(equalToConstant: 56)
        ])
    }

    private func applyLoadedState(_ loaded: Bool) {
        placeholderLabel.isHidden = loaded
        saveButton.isEnabled = loaded
        toolbarView.setEnabled(loaded)
        parameterView.isUserInteractionEnabled = loaded
        parameterView.alpha = loaded ? 1.0 : 0.5
        updateUndoState()
    }

    private func updateUndoState() {
        toolbarView.setUndoEnabled(document?.canUndo ?? false)
        toolbarView.setRedoEnabled(document?.canRedo ?? false)
    }

    // MARK: - Config

    /// 현재 도구/슬라이더/색상을 StrokeConfig로 합친다.
    private func makeConfig() -> StrokeConfig {
        let radius = lerp(CGFloat(parameterView.bottomValue), 0.012, 0.12)
        var config = StrokeConfig(tool: currentTool,
                                  brushRadius: radius,
                                  mosaicScale: 0.04,
                                  blurSigma: 0.02,
                                  color: currentColor.uiColor,
                                  opacity: 1.0)
        let top = CGFloat(parameterView.topValue)
        switch currentTool {
        case .mosaic: config.mosaicScale = lerp(top, 0.01, 0.09)
        case .blur:   config.blurSigma   = lerp(top, 0.004, 0.05)
        case .brush:  config.opacity     = lerp(top, 0.15, 1.0)
        case .eraser: break
        }
        return config
    }

    private func lerp(_ t: CGFloat, _ a: CGFloat, _ b: CGFloat) -> CGFloat {
        return a + min(1, max(0, t)) * (b - a)
    }

    // MARK: - Actions

    @objc private func loadTapped() {
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.delegate = self
        present(picker, animated: true)
    }

    @objc private func saveTapped() {
        guard let strokes = document?.strokes, let full = fullOriginal else { return }
        saveButton.isEnabled = false
        let output = ImageCompositor.shared.render(strokes: strokes, original: full)
        PhotoSaver.save(output) { [weak self] result in
            guard let self = self else { return }
            self.saveButton.isEnabled = true
            switch result {
            case .success:
                self.showAlert(title: "저장 완료", message: "사진 앨범에 저장되었습니다.")
            case .denied:
                self.showAlert(title: "권한 필요",
                               message: "사진 추가 권한이 필요합니다. 설정 > 개인정보 보호에서 허용해 주세요.")
            case .failed(let error):
                self.showAlert(title: "저장 실패", message: error?.localizedDescription ?? "알 수 없는 오류가 발생했습니다.")
            }
        }
    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "확인", style: .default))
        present(alert, animated: true)
    }

    // MARK: - Image setup

    private func setupDocument(with picked: UIImage) {
        let full = normalizedUpImage(picked, maxDimension: fullMaxDimension)
        let working = normalizedUpImage(full, maxDimension: workingMaxDimension)

        fullOriginal = full
        let doc = EditDocument(original: working)
        document = doc

        canvasView.workingOriginal = working
        canvasView.imageSize = working.size      // scale 1 → size == 픽셀 크기
        canvasView.displayImage = doc.composited

        canvasScrollView.setZoomScale(1, animated: false)   // 새 이미지는 1x부터
        canvasView.applyZoomScale(1)

        applyLoadedState(true)
    }

    /// EXIF 방향을 .up으로 정규화하고 maxDimension 이하로 다운스케일 (scale 1).
    private func normalizedUpImage(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        guard size.width > 0, size.height > 0 else { return image }
        let longest = max(size.width, size.height)
        let scale = longest > maxDimension ? maxDimension / longest : 1
        let target = CGSize(width: max(1, floor(size.width * scale)),
                            height: max(1, floor(size.height * scale)))
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))   // draw가 방향을 .up으로 정규화
        }
    }
}

// MARK: - CanvasViewDelegate

extension EditorViewController: CanvasViewDelegate {

    func canvasViewCurrentConfig(_ canvas: CanvasView) -> StrokeConfig? {
        guard document != nil else { return nil }
        return makeConfig()
    }

    func canvasView(_ canvas: CanvasView, didComplete stroke: Stroke) {
        guard let doc = document else { return }
        doc.commit(stroke)
        canvas.displayImage = doc.composited
        updateUndoState()
    }
}

// MARK: - ToolbarViewDelegate

extension EditorViewController: ToolbarViewDelegate {

    func toolbarView(_ toolbar: ToolbarView, didSelect tool: EditTool) {
        currentTool = tool
        parameterView.configure(for: tool)
    }

    func toolbarViewDidTapUndo(_ toolbar: ToolbarView) {
        guard let doc = document else { return }
        doc.undo()
        canvasView.displayImage = doc.composited
        updateUndoState()
    }

    func toolbarViewDidTapRedo(_ toolbar: ToolbarView) {
        guard let doc = document else { return }
        doc.redo()
        canvasView.displayImage = doc.composited
        updateUndoState()
    }
}

// MARK: - ParameterSliderViewDelegate

extension EditorViewController: ParameterSliderViewDelegate {
    func parameterViewDidChange(_ view: ParameterSliderView) {
        // 값은 다음 터치 시작 시 makeConfig()에서 읽으므로 즉시 처리할 것은 없다.
    }

    func parameterViewDidChangeBrushSize(_ view: ParameterSliderView) {
        // 줌/팬 상태에서도 보이도록 현재 보이는 영역의 중심(콘텐츠 좌표)에 미리보기 원을 표시한다.
        let visible = canvasScrollView.convert(canvasScrollView.bounds, to: canvasView)
        canvasView.showBrushSizePreview(centeredAt: CGPoint(x: visible.midX, y: visible.midY))
    }
}

// MARK: - UIImagePickerControllerDelegate

extension EditorViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {

    func imagePickerController(_ picker: UIImagePickerController,
                               didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        picker.dismiss(animated: true)
        guard let image = info[.originalImage] as? UIImage else { return }
        setupDocument(with: image)
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }
}

// MARK: - UIScrollViewDelegate (핀치 줌)

extension EditorViewController: UIScrollViewDelegate {

    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return canvasView
    }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        canvasView.applyZoomScale(scrollView.zoomScale)   // 인디케이터 외곽선 두께 역보정
    }
}

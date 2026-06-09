import UIKit

protocol ParameterSliderViewDelegate: AnyObject {
    func parameterViewDidChange(_ view: ParameterSliderView)
    /// 굵기(공통) 슬라이더가 변경되었을 때. 브러시 크기 미리보기 표시에 사용.
    func parameterViewDidChangeBrushSize(_ view: ParameterSliderView)
}

/// 현재 도구의 파라미터 UI.
///  - slider1(상단): 도구별 파라미터1 (모자이크 픽셀 / 블러 강도 / 브러시 투명도). 지우개는 숨김.
///  - slider2(하단): 브러시 굵기(공통).
///  - 색상 컨트롤: 브러시 전용.
/// 슬라이더 값은 0...1 (raw). 실제 파라미터 매핑은 EditorViewController가 담당.
final class ParameterSliderView: UIView {

    weak var delegate: ParameterSliderViewDelegate?

    let slider1 = UISlider()
    let slider2 = UISlider()
    private let label1 = UILabel()
    private let label2 = UILabel()
    let colorControl = UISegmentedControl(items: BrushColor.allCases.map { $0.title })

    private let row1 = UIStackView()
    private let row2 = UIStackView()
    private let container = UIStackView()

    var topValue: Float { slider1.value }
    var bottomValue: Float { slider2.value }
    var selectedColorIndex: Int { max(0, colorControl.selectedSegmentIndex) }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        [label1, label2].forEach {
            $0.font = .systemFont(ofSize: 12, weight: .medium)
            $0.textColor = .darkGray
            $0.setContentHuggingPriority(.required, for: .horizontal)
            $0.widthAnchor.constraint(equalToConstant: 64).isActive = true
        }
        label1.text = "픽셀 크기"
        label2.text = "굵기"

        slider1.minimumValue = 0
        slider1.maximumValue = 1
        slider1.value = 0.4
        slider1.addTarget(self, action: #selector(valueChanged), for: .valueChanged)

        slider2.minimumValue = 0
        slider2.maximumValue = 1
        slider2.value = 0.4
        slider2.addTarget(self, action: #selector(thicknessChanged), for: .valueChanged)

        colorControl.selectedSegmentIndex = 0
        colorControl.addTarget(self, action: #selector(valueChanged), for: .valueChanged)
        updateColorSelectionAppearance()

        row1.axis = .horizontal
        row1.spacing = 8
        row1.alignment = .center
        row1.addArrangedSubview(label1)
        row1.addArrangedSubview(slider1)

        row2.axis = .horizontal
        row2.spacing = 8
        row2.alignment = .center
        row2.addArrangedSubview(label2)
        row2.addArrangedSubview(slider2)

        container.axis = .vertical
        container.spacing = 6
        container.translatesAutoresizingMaskIntoConstraints = false
        container.addArrangedSubview(row1)
        container.addArrangedSubview(row2)
        container.addArrangedSubview(colorControl)
        addSubview(container)

        NSLayoutConstraint.activate([
            container.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            container.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            container.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            container.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8)
        ])
    }

    /// 선택된 도구에 맞춰 행 표시/숨김 및 라벨을 구성한다.
    func configure(for tool: EditTool) {
        if let primary = tool.primaryParamTitle {
            label1.text = primary
            row1.isHidden = false
        } else {
            row1.isHidden = true       // 지우개: 파라미터1 없음
        }
        colorControl.isHidden = !tool.usesColor
    }

    @objc private func valueChanged() {
        updateColorSelectionAppearance()
        delegate?.parameterViewDidChange(self)
    }

    /// 굵기 슬라이더 전용: 크기 미리보기를 띄우도록 별도 콜백을 호출한다.
    @objc private func thicknessChanged() {
        delegate?.parameterViewDidChangeBrushSize(self)
        delegate?.parameterViewDidChange(self)
    }

    /// 선택된 세그먼트 알약을 해당 브러시 색으로 칠하고 흰색 굵은 글자로 강조한다.
    /// 선택 위치(채워진 알약)와 실제 색을 동시에 드러낸다.
    private func updateColorSelectionAppearance() {
        let color = (BrushColor(rawValue: selectedColorIndex) ?? .red).uiColor
        colorControl.setTitleTextAttributes(
            [.foregroundColor: UIColor.white,
             .font: UIFont.systemFont(ofSize: 13, weight: .semibold)], for: .selected)
        colorControl.setTitleTextAttributes(
            [.foregroundColor: UIColor.darkText,
             .font: UIFont.systemFont(ofSize: 13, weight: .regular)], for: .normal)
        if #available(iOS 13.0, *) {
            colorControl.selectedSegmentTintColor = color
        } else {
            colorControl.tintColor = color   // iOS 12: 선택 세그먼트 배경 = tintColor
        }
    }
}

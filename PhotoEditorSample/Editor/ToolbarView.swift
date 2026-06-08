import UIKit

protocol ToolbarViewDelegate: AnyObject {
    func toolbarView(_ toolbar: ToolbarView, didSelect tool: EditTool)
    func toolbarViewDidTapUndo(_ toolbar: ToolbarView)
}

/// 하단 도구 바: [모자이크][블러][브러시][지우개]  +  [되돌리기].
final class ToolbarView: UIView {

    weak var delegate: ToolbarViewDelegate?

    private(set) var selectedTool: EditTool = .mosaic

    private var toolButtons: [EditTool: UIButton] = [:]
    private let undoButton = UIButton(type: .system)
    private let stack = UIStackView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.alignment = .fill
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6)
        ])

        for tool in EditTool.allCases {
            let button = makeButton(title: tool.title)
            button.tag = tool.rawValue
            button.addTarget(self, action: #selector(toolTapped(_:)), for: .touchUpInside)
            toolButtons[tool] = button
            stack.addArrangedSubview(button)
        }

        undoButton.setTitle("되돌리기", for: .normal)
        undoButton.titleLabel?.font = .systemFont(ofSize: 14, weight: .medium)
        undoButton.addTarget(self, action: #selector(undoTapped), for: .touchUpInside)
        stack.addArrangedSubview(undoButton)

        updateSelectionAppearance()
        setUndoEnabled(false)
    }

    private func makeButton(title: String) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 14, weight: .medium)
        button.titleLabel?.adjustsFontSizeToFitWidth = true
        button.titleLabel?.minimumScaleFactor = 0.7
        button.layer.cornerRadius = 8
        return button
    }

    // MARK: - Public API

    func setEnabled(_ enabled: Bool) {
        toolButtons.values.forEach { $0.isEnabled = enabled }
        isUserInteractionEnabled = enabled
        alpha = enabled ? 1.0 : 0.5
    }

    func setUndoEnabled(_ enabled: Bool) {
        undoButton.isEnabled = enabled
    }

    func selectTool(_ tool: EditTool) {
        selectedTool = tool
        updateSelectionAppearance()
    }

    // MARK: - Actions

    @objc private func toolTapped(_ sender: UIButton) {
        guard let tool = EditTool(rawValue: sender.tag) else { return }
        selectedTool = tool
        updateSelectionAppearance()
        delegate?.toolbarView(self, didSelect: tool)
    }

    @objc private func undoTapped() {
        delegate?.toolbarViewDidTapUndo(self)
    }

    private func updateSelectionAppearance() {
        for (tool, button) in toolButtons {
            let selected = (tool == selectedTool)
            button.backgroundColor = selected ? UIColor.systemBlue.withAlphaComponent(0.15) : .clear
            button.setTitleColor(selected ? .systemBlue : .darkText, for: .normal)
        }
    }
}

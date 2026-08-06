#if os(iOS)
import UIKit

/// Vertical option list popup (playback rate / quality-style).
final class SgOptionListPanelView: UIView {
    var onSelect: ((Int) -> Void)?

    private let titleLabel = UILabel()
    private let stack = UIStackView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    func reload(title: String, options: [(label: String, selected: Bool)]) {
        titleLabel.text = title
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for (index, option) in options.enumerated() {
            let button = UIButton(type: .system)
            button.contentHorizontalAlignment = .leading
            button.titleLabel?.font = .systemFont(ofSize: 13)
            button.setTitle(option.label, for: .normal)
            button.setTitleColor(option.selected ? KineticPlayerColors.seekActive : .white, for: .normal)
            button.tag = index
            button.addTarget(self, action: #selector(tapped(_:)), for: .touchUpInside)
            stack.addArrangedSubview(button)
        }
    }

    private func setup() {
        backgroundColor = KineticPlayerColors.panelBackground
        layer.cornerRadius = 8
        clipsToBounds = true

        titleLabel.font = .boldSystemFont(ofSize: 14)
        titleLabel.textColor = .white
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(titleLabel)
        addSubview(stack)

        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: 120),
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            stack.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
        ])
    }

    @objc private func tapped(_ sender: UIButton) {
        onSelect?(sender.tag)
    }
}
#elseif os(macOS)
import AppKit

/// Vertical option list popup (playback rate / quality-style).
final class SgOptionListPanelView: NSView {
    var onSelect: ((Int) -> Void)?

    private let titleLabel = NSTextField(labelWithString: "")
    private let stack = NSStackView()

    override var isFlipped: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    func reload(title: String, options: [(label: String, selected: Bool)]) {
        titleLabel.stringValue = title
        stack.views.forEach { $0.removeFromSuperview() }
        for (index, option) in options.enumerated() {
            let button = NSButton(title: option.label, target: self, action: #selector(tapped(_:)))
            button.isBordered = false
            button.setButtonType(.momentaryChange)
            button.alignment = .left
            button.tag = index
            let color: NSColor = option.selected ? KineticPlayerColors.seekActive : .white
            button.attributedTitle = NSAttributedString(
                string: option.label,
                attributes: [.foregroundColor: color, .font: NSFont.systemFont(ofSize: 13)],
            )
            stack.addArrangedSubview(button)
        }
    }

    private func setup() {
        wantsLayer = true
        layer?.backgroundColor = KineticPlayerColors.panelBackground.cgColor
        layer?.cornerRadius = 8
        layer?.masksToBounds = true

        titleLabel.font = .boldSystemFont(ofSize: 14)
        titleLabel.textColor = .white
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(titleLabel)
        addSubview(stack)

        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: 120),
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            stack.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
        ])
    }

    @objc private func tapped(_ sender: NSButton) {
        onSelect?(sender.tag)
    }
}
#endif

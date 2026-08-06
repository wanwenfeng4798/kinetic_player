#if os(iOS)
import UIKit

/// Centered HUD shown while adjusting seek / volume / brightness via pan gestures.
final class SgGestureOverlayView: UIView {
    private let iconView = UIImageView()
    private let valueLabel = UILabel()
    private let symbolConfig = UIImage.SymbolConfiguration(pointSize: 28, weight: .medium)

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    func show(symbolName: String, text: String) {
        iconView.image = UIImage(systemName: symbolName, withConfiguration: symbolConfig)
        valueLabel.text = text
        isHidden = false
        alpha = 1
    }

    func hide(animated: Bool = true) {
        guard !isHidden else { return }
        if animated {
            UIView.animate(withDuration: 0.2, animations: {
                self.alpha = 0
            }, completion: { _ in
                self.isHidden = true
                self.alpha = 1
            })
        } else {
            isHidden = true
            alpha = 1
        }
    }

    private func setup() {
        isHidden = true
        backgroundColor = UIColor(white: 0, alpha: 0.55)
        layer.cornerRadius = 10
        clipsToBounds = true
        translatesAutoresizingMaskIntoConstraints = false
        isUserInteractionEnabled = false

        iconView.tintColor = .white
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false

        valueLabel.font = .monospacedDigitSystemFont(ofSize: 15, weight: .medium)
        valueLabel.textColor = .white
        valueLabel.textAlignment = .center
        valueLabel.translatesAutoresizingMaskIntoConstraints = false

        addSubview(iconView)
        addSubview(valueLabel)

        NSLayoutConstraint.activate([
            widthAnchor.constraint(greaterThanOrEqualToConstant: 120),
            heightAnchor.constraint(equalToConstant: 88),

            iconView.topAnchor.constraint(equalTo: topAnchor, constant: 14),
            iconView.centerXAnchor.constraint(equalTo: centerXAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 32),
            iconView.heightAnchor.constraint(equalToConstant: 32),

            valueLabel.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 8),
            valueLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            valueLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            valueLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
        ])
    }
}
#elseif os(macOS)
import AppKit

/// Centered HUD shown while adjusting seek / volume via pan gestures.
/// (No public brightness API on macOS, so only seek / volume are surfaced here.)
final class SgGestureOverlayView: NSView {
    private let iconView = NSImageView()
    private let valueLabel = NSTextField(labelWithString: "")

    override var isFlipped: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    func show(symbolName: String, text: String) {
        let image = KineticPlayerSymbols.image(systemName: symbolName, pointSize: 28, weight: .medium)
        image?.isTemplate = true
        iconView.image = image
        valueLabel.stringValue = text
        isHidden = false
        alphaValue = 1
    }

    func hide(animated: Bool = true) {
        guard !isHidden else { return }
        if animated {
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.2
                self.animator().alphaValue = 0
            }, completionHandler: { [weak self] in
                self?.isHidden = true
                self?.alphaValue = 1
            })
        } else {
            isHidden = true
            alphaValue = 1
        }
    }

    /// Mouse events pass through; this is a purely visual HUD.
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    private func setup() {
        isHidden = true
        wantsLayer = true
        layer?.backgroundColor = NSColor(white: 0, alpha: 0.55).cgColor
        layer?.cornerRadius = 10
        layer?.masksToBounds = true
        translatesAutoresizingMaskIntoConstraints = false

        iconView.contentTintColor = .white
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.translatesAutoresizingMaskIntoConstraints = false

        valueLabel.font = .monospacedDigitSystemFont(ofSize: 15, weight: .medium)
        valueLabel.textColor = .white
        valueLabel.alignment = .center
        valueLabel.translatesAutoresizingMaskIntoConstraints = false

        addSubview(iconView)
        addSubview(valueLabel)

        NSLayoutConstraint.activate([
            widthAnchor.constraint(greaterThanOrEqualToConstant: 120),
            heightAnchor.constraint(equalToConstant: 88),

            iconView.topAnchor.constraint(equalTo: topAnchor, constant: 14),
            iconView.centerXAnchor.constraint(equalTo: centerXAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 32),
            iconView.heightAnchor.constraint(equalToConstant: 32),

            valueLabel.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 8),
            valueLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            valueLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            valueLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
        ])
    }
}
#endif

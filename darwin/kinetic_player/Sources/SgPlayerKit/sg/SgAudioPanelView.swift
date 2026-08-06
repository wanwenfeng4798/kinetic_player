#if os(iOS)
import UIKit

/// Bilibili-style vertical volume popup with top percent label.
final class SgAudioPanelView: UIView {
    var onVolumeChanged: ((Double) -> Void)?
    var onDraggingChanged: ((Bool) -> Void)?

    private let volumeSliderContainer = UIView()
    private let volumeValueLabel = UILabel()
    private let volumeSlider = UISlider()
    private var syncing = false
    private var isDragging = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    func syncVolume(volume: Double, muted: Bool) {
        syncing = true
        let level = Float(max(0, min(volume, 1)))
        volumeSlider.value = muted ? 0 : level
        updateVolumeValueLabel(level: muted ? 0 : level)
        syncing = false
    }

    private func setup() {
        backgroundColor = .clear
        clipsToBounds = false

        volumeValueLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .medium)
        volumeValueLabel.textColor = .white
        volumeValueLabel.textAlignment = .center
        volumeValueLabel.isHidden = false
        volumeValueLabel.text = "100%"
        volumeValueLabel.translatesAutoresizingMaskIntoConstraints = false

        volumeSliderContainer.backgroundColor = KineticPlayerColors.panelBackground
        volumeSliderContainer.layer.cornerRadius = 8
        volumeSliderContainer.clipsToBounds = true
        volumeSliderContainer.translatesAutoresizingMaskIntoConstraints = false

        volumeSlider.minimumValue = 0
        volumeSlider.maximumValue = 1
        volumeSlider.value = 1
        volumeSlider.minimumTrackTintColor = KineticPlayerColors.seekActive
        volumeSlider.maximumTrackTintColor = KineticPlayerColors.seekBackground
        volumeSlider.transform = CGAffineTransform(rotationAngle: -.pi / 2)
        volumeSlider.translatesAutoresizingMaskIntoConstraints = false
        volumeSlider.addTarget(
            self,
            action: #selector(volumeTouchDown),
            for: [.touchDown, .touchDragInside, .touchDragOutside],
        )
        volumeSlider.addTarget(self, action: #selector(volumeChanged), for: .valueChanged)
        volumeSlider.addTarget(
            self,
            action: #selector(volumeTouchUp),
            for: [.touchUpInside, .touchUpOutside, .touchCancel],
        )
        volumeSliderContainer.addSubview(volumeValueLabel)
        volumeSliderContainer.addSubview(volumeSlider)

        addSubview(volumeSliderContainer)

        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: 44),

            volumeSliderContainer.topAnchor.constraint(equalTo: topAnchor),
            volumeSliderContainer.leadingAnchor.constraint(equalTo: leadingAnchor),
            volumeSliderContainer.trailingAnchor.constraint(equalTo: trailingAnchor),
            volumeSliderContainer.bottomAnchor.constraint(equalTo: bottomAnchor),
            volumeSliderContainer.heightAnchor.constraint(equalToConstant: 160),

            volumeValueLabel.topAnchor.constraint(equalTo: volumeSliderContainer.topAnchor, constant: 8),
            volumeValueLabel.leadingAnchor.constraint(equalTo: volumeSliderContainer.leadingAnchor),
            volumeValueLabel.trailingAnchor.constraint(equalTo: volumeSliderContainer.trailingAnchor),

            volumeSlider.centerXAnchor.constraint(equalTo: volumeSliderContainer.centerXAnchor),
            volumeSlider.centerYAnchor.constraint(equalTo: volumeSliderContainer.centerYAnchor, constant: 8),
            volumeSlider.widthAnchor.constraint(equalToConstant: 120),
        ])
    }

    @objc private func volumeTouchDown() {
        beginDragging()
    }

    @objc private func volumeChanged() {
        guard !syncing else { return }
        beginDragging()
        updateVolumeValueLabel(level: volumeSlider.value)
        onVolumeChanged?(Double(volumeSlider.value))
    }

    @objc private func volumeTouchUp() {
        isDragging = false
        onDraggingChanged?(false)
    }

    private func beginDragging() {
        if isDragging { return }
        isDragging = true
        onDraggingChanged?(true)
        updateVolumeValueLabel(level: volumeSlider.value)
    }

    private func updateVolumeValueLabel(level: Float) {
        let percent = Int((max(0, min(level, 1)) * 100).rounded())
        volumeValueLabel.text = "\(percent)%"
    }
}
#elseif os(macOS)
import AppKit

/// Bilibili-style vertical volume popup with top percent label.
final class SgAudioPanelView: NSView {
    var onVolumeChanged: ((Double) -> Void)?
    var onDraggingChanged: ((Bool) -> Void)?

    private let volumeSliderContainer = NSView()
    private let volumeValueLabel = NSTextField(labelWithString: "100%")
    private let volumeSlider = SgTrackSlider()
    private var syncing = false
    private var isDragging = false

    override var isFlipped: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    func syncVolume(volume: Double, muted: Bool) {
        syncing = true
        let level = Float(max(0, min(volume, 1)))
        volumeSlider.value = muted ? 0 : level
        updateVolumeValueLabel(level: muted ? 0 : level)
        syncing = false
    }

    private func setup() {
        wantsLayer = true

        volumeValueLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .medium)
        volumeValueLabel.textColor = .white
        volumeValueLabel.alignment = .center
        volumeValueLabel.isHidden = false
        volumeValueLabel.translatesAutoresizingMaskIntoConstraints = false

        volumeSliderContainer.wantsLayer = true
        volumeSliderContainer.layer?.backgroundColor = KineticPlayerColors.panelBackground.cgColor
        volumeSliderContainer.layer?.cornerRadius = 8
        volumeSliderContainer.layer?.masksToBounds = true
        volumeSliderContainer.translatesAutoresizingMaskIntoConstraints = false

        volumeSlider.orientation = .vertical
        volumeSlider.minimumValue = 0
        volumeSlider.maximumValue = 1
        volumeSlider.value = 1
        volumeSlider.minimumTrackTintColor = KineticPlayerColors.seekActive
        volumeSlider.maximumTrackTintColor = KineticPlayerColors.seekBackground
        volumeSlider.translatesAutoresizingMaskIntoConstraints = false
        volumeSlider.onTouchDown = { [weak self] in self?.beginDragging() }
        volumeSlider.onValueChanged = { [weak self] in self?.handleSliderChanged() }
        volumeSlider.onTouchUp = { [weak self] in self?.endDragging() }
        volumeSliderContainer.addSubview(volumeValueLabel)
        volumeSliderContainer.addSubview(volumeSlider)

        addSubview(volumeSliderContainer)

        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: 44),

            volumeSliderContainer.topAnchor.constraint(equalTo: topAnchor),
            volumeSliderContainer.leadingAnchor.constraint(equalTo: leadingAnchor),
            volumeSliderContainer.trailingAnchor.constraint(equalTo: trailingAnchor),
            volumeSliderContainer.bottomAnchor.constraint(equalTo: bottomAnchor),
            volumeSliderContainer.heightAnchor.constraint(equalToConstant: 160),

            volumeValueLabel.topAnchor.constraint(equalTo: volumeSliderContainer.topAnchor, constant: 8),
            volumeValueLabel.leadingAnchor.constraint(equalTo: volumeSliderContainer.leadingAnchor),
            volumeValueLabel.trailingAnchor.constraint(equalTo: volumeSliderContainer.trailingAnchor),

            volumeSlider.centerXAnchor.constraint(equalTo: volumeSliderContainer.centerXAnchor),
            volumeSlider.centerYAnchor.constraint(equalTo: volumeSliderContainer.centerYAnchor, constant: 8),
            volumeSlider.widthAnchor.constraint(equalToConstant: 24),
            volumeSlider.heightAnchor.constraint(equalToConstant: 120),
        ])
    }

    private func handleSliderChanged() {
        guard !syncing else { return }
        beginDragging()
        updateVolumeValueLabel(level: volumeSlider.value)
        onVolumeChanged?(Double(volumeSlider.value))
    }

    private func beginDragging() {
        if isDragging { return }
        isDragging = true
        onDraggingChanged?(true)
        updateVolumeValueLabel(level: volumeSlider.value)
    }

    private func endDragging() {
        isDragging = false
        onDraggingChanged?(false)
    }

    private func updateVolumeValueLabel(level: Float) {
        let percent = Int((max(0, min(level, 1)) * 100).rounded())
        volumeValueLabel.stringValue = "\(percent)%"
    }
}
#endif

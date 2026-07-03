import UIKit

/// Bilibili-style vertical volume popup (volume only).
final class SgAudioPanelView: UIView {
    var onVolumeChanged: ((Double) -> Void)?

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
        if isDragging {
            updateVolumeValueLabel(level: muted ? 0 : level)
        }
        syncing = false
    }

    private func setup() {
        backgroundColor = .clear
        clipsToBounds = false

        volumeValueLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .medium)
        volumeValueLabel.textColor = .white
        volumeValueLabel.textAlignment = .center
        volumeValueLabel.isHidden = true
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
        volumeSliderContainer.addSubview(volumeSlider)

        addSubview(volumeValueLabel)
        addSubview(volumeSliderContainer)

        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: 44),

            volumeSliderContainer.topAnchor.constraint(equalTo: topAnchor),
            volumeSliderContainer.leadingAnchor.constraint(equalTo: leadingAnchor),
            volumeSliderContainer.trailingAnchor.constraint(equalTo: trailingAnchor),
            volumeSliderContainer.bottomAnchor.constraint(equalTo: bottomAnchor),
            volumeSliderContainer.heightAnchor.constraint(equalToConstant: 144),

            volumeValueLabel.trailingAnchor.constraint(equalTo: volumeSliderContainer.leadingAnchor, constant: -4),
            volumeValueLabel.centerYAnchor.constraint(equalTo: volumeSliderContainer.centerYAnchor),
            volumeValueLabel.widthAnchor.constraint(equalToConstant: 28),

            volumeSlider.centerXAnchor.constraint(equalTo: volumeSliderContainer.centerXAnchor),
            volumeSlider.centerYAnchor.constraint(equalTo: volumeSliderContainer.centerYAnchor),
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
        volumeValueLabel.isHidden = true
    }

    private func beginDragging() {
        if isDragging { return }
        isDragging = true
        updateVolumeValueLabel(level: volumeSlider.value)
        volumeValueLabel.isHidden = false
    }

    private func updateVolumeValueLabel(level: Float) {
        let percent = Int((max(0, min(level, 1)) * 100).rounded())
        volumeValueLabel.text = "\(percent)%"
    }
}

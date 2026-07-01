import UIKit

/// Bottom native toolbar with mute toggle and volume slider for SGPlayer.
final class SgVolumeToolbarView: UIView {
    var onVolumeChanged: ((Double) -> Void)?
    var onMuteToggle: ((Bool) -> Void)?

    private let muteButton = UIButton(type: .system)
    private let slider = UISlider()
    private var syncing = false
    private var level: Float = 1.0
    private var muted = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    func sync(volume: Double, muted: Bool) {
        syncing = true
        level = Float(max(0, min(volume, 1)))
        self.muted = muted
        slider.value = muted ? 0 : level
        updateMuteIcon()
        syncing = false
    }

    private func setup() {
        backgroundColor = UIColor(white: 0, alpha: 0.55)
        isUserInteractionEnabled = true

        muteButton.tintColor = .white
        muteButton.translatesAutoresizingMaskIntoConstraints = false
        muteButton.addTarget(self, action: #selector(toggleMute), for: .touchUpInside)
        addSubview(muteButton)

        slider.minimumValue = 0
        slider.maximumValue = 1
        slider.value = level
        slider.minimumTrackTintColor = UIColor(red: 0.30, green: 0.91, blue: 0.71, alpha: 1)
        slider.maximumTrackTintColor = UIColor(white: 1, alpha: 0.35)
        slider.translatesAutoresizingMaskIntoConstraints = false
        slider.addTarget(self, action: #selector(sliderChanged), for: .valueChanged)
        addSubview(slider)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 40),
            muteButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            muteButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            muteButton.widthAnchor.constraint(equalToConstant: 28),
            muteButton.heightAnchor.constraint(equalToConstant: 28),
            slider.leadingAnchor.constraint(equalTo: muteButton.trailingAnchor, constant: 8),
            slider.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            slider.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])

        updateMuteIcon()
    }

    @objc private func sliderChanged() {
        guard !syncing else { return }
        level = slider.value
        muted = level <= 0.001
        updateMuteIcon()
        onVolumeChanged?(Double(level))
    }

    @objc private func toggleMute() {
        muted.toggle()
        if muted {
            onMuteToggle?(true)
        } else {
            onMuteToggle?(false)
            if level <= 0.001 {
                level = 1.0
            }
            onVolumeChanged?(Double(level))
        }
        sync(volume: Double(level), muted: muted)
    }

    private func updateMuteIcon() {
        let symbolName = muted || slider.value <= 0.001 ? "speaker.slash.fill" : "speaker.wave.2.fill"
        let image = UIImage(systemName: symbolName)
        muteButton.setImage(image, for: .normal)
    }
}

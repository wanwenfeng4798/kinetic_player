import UIKit

/// Bilibili-style vertical volume popup (volume only).
final class SgAudioPanelView: UIView {
    var onVolumeChanged: ((Double) -> Void)?

    private let volumeSliderContainer = UIView()
    private let volumeSlider = UISlider()
    private var syncing = false

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
        syncing = false
    }

    private func setup() {
        backgroundColor = KineticPlayerColors.panelBackground
        layer.cornerRadius = 8
        clipsToBounds = true
        isUserInteractionEnabled = true

        volumeSliderContainer.translatesAutoresizingMaskIntoConstraints = false

        volumeSlider.minimumValue = 0
        volumeSlider.maximumValue = 1
        volumeSlider.value = 1
        volumeSlider.minimumTrackTintColor = KineticPlayerColors.seekActive
        volumeSlider.maximumTrackTintColor = KineticPlayerColors.seekBackground
        volumeSlider.transform = CGAffineTransform(rotationAngle: -.pi / 2)
        volumeSlider.translatesAutoresizingMaskIntoConstraints = false
        volumeSlider.addTarget(self, action: #selector(volumeChanged), for: .valueChanged)
        volumeSliderContainer.addSubview(volumeSlider)

        addSubview(volumeSliderContainer)

        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: 56),

            volumeSliderContainer.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            volumeSliderContainer.centerXAnchor.constraint(equalTo: centerXAnchor),
            volumeSliderContainer.widthAnchor.constraint(equalToConstant: 56),
            volumeSliderContainer.heightAnchor.constraint(equalToConstant: 120),
            volumeSliderContainer.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),

            volumeSlider.centerXAnchor.constraint(equalTo: volumeSliderContainer.centerXAnchor),
            volumeSlider.centerYAnchor.constraint(equalTo: volumeSliderContainer.centerYAnchor),
            volumeSlider.widthAnchor.constraint(equalToConstant: 120),
        ])
    }

    @objc private func volumeChanged() {
        guard !syncing else { return }
        onVolumeChanged?(Double(volumeSlider.value))
    }
}

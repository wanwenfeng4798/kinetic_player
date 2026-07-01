import UIKit

/// Bilibili-style vertical popup: vertical volume slider + stacked audio tracks.
final class SgAudioPanelView: UIView {
    var onVolumeChanged: ((Double) -> Void)?
    var onSelectTrack: ((Int) -> Void)?

    private let volumeSliderContainer = UIView()
    private let volumeSlider = UISlider()
    private let divider = UIView()
    private let tracksStack = UIStackView()
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

    func reloadTracks(_ tracks: [[String: Any]]) {
        tracksStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let showTracks = tracks.count > 1
        divider.isHidden = !showTracks
        tracksStack.isHidden = !showTracks
        guard showTracks else { return }

        for track in tracks {
            let index = track["index"] as? Int ?? 0
            let label = track["label"] as? String ?? "Track \(index)"
            let language = track["language"] as? String
            let selected = track["selected"] as? Bool ?? false
            let title = Self.formatVerticalTrackLabel(label, language: language)

            let button = UIButton(type: .system)
            button.titleLabel?.font = .systemFont(ofSize: 12)
            button.titleLabel?.numberOfLines = 0
            button.titleLabel?.textAlignment = .center
            button.contentHorizontalAlignment = .center
            button.setTitle(title, for: .normal)
            button.setTitleColor(selected ? KineticPlayerColors.seekActive : .white, for: .normal)
            button.tag = index
            button.addTarget(self, action: #selector(trackTapped(_:)), for: .touchUpInside)
            tracksStack.addArrangedSubview(button)
        }
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

        divider.backgroundColor = KineticPlayerColors.seekBackground
        divider.isHidden = true
        divider.translatesAutoresizingMaskIntoConstraints = false

        tracksStack.axis = .vertical
        tracksStack.alignment = .center
        tracksStack.spacing = 4
        tracksStack.isHidden = true
        tracksStack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(volumeSliderContainer)
        addSubview(divider)
        addSubview(tracksStack)

        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: 56),

            volumeSliderContainer.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            volumeSliderContainer.centerXAnchor.constraint(equalTo: centerXAnchor),
            volumeSliderContainer.widthAnchor.constraint(equalToConstant: 56),
            volumeSliderContainer.heightAnchor.constraint(equalToConstant: 120),

            volumeSlider.centerXAnchor.constraint(equalTo: volumeSliderContainer.centerXAnchor),
            volumeSlider.centerYAnchor.constraint(equalTo: volumeSliderContainer.centerYAnchor),
            volumeSlider.widthAnchor.constraint(equalToConstant: 120),

            divider.topAnchor.constraint(equalTo: volumeSliderContainer.bottomAnchor, constant: 8),
            divider.centerXAnchor.constraint(equalTo: centerXAnchor),
            divider.widthAnchor.constraint(equalToConstant: 32),
            divider.heightAnchor.constraint(equalToConstant: 1),

            tracksStack.topAnchor.constraint(equalTo: divider.bottomAnchor, constant: 8),
            tracksStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            tracksStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            tracksStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
        ])
    }

    @objc private func volumeChanged() {
        guard !syncing else { return }
        onVolumeChanged?(Double(volumeSlider.value))
    }

    @objc private func trackTapped(_ sender: UIButton) {
        onSelectTrack?(sender.tag)
    }

    private static func formatVerticalTrackLabel(_ label: String, language: String?) -> String {
        let compact = label.trimmingCharacters(in: .whitespacesAndNewlines)
        let vertical: String
        if compact.unicodeScalars.contains(where: { (0x4E00...0x9FFF).contains($0.value) }) {
            vertical = compact.filter { !$0.isWhitespace }.map { String($0) }.joined(separator: "\n")
        } else {
            vertical = compact
        }
        if let language, !language.isEmpty {
            return "\(vertical)\n(\(language))"
        }
        return vertical
    }
}

import UIKit

/// Native settings sheet with audio track selection.
final class SgSettingsPanelView: UIView {
    var onSelectTrack: ((Int) -> Void)?

    private let titleLabel = UILabel()
    private let sectionLabel = UILabel()
    private let tracksStack = UIStackView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    func reloadTracks(_ tracks: [[String: Any]]) {
        tracksStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        if tracks.isEmpty {
            let label = UILabel()
            label.text = "暂无可用音轨"
            label.font = .systemFont(ofSize: 12)
            label.textColor = UIColor(white: 1, alpha: 0.6)
            tracksStack.addArrangedSubview(label)
            return
        }
        for track in tracks {
            let index = track["index"] as? Int ?? 0
            let label = track["label"] as? String ?? "Track \(index)"
            let language = track["language"] as? String
            let selected = track["selected"] as? Bool ?? false
            let title = language.map { "\(label) (\($0))" } ?? label

            let button = UIButton(type: .system)
            button.contentHorizontalAlignment = .leading
            button.titleLabel?.font = .systemFont(ofSize: 13)
            button.titleLabel?.numberOfLines = 1
            button.titleLabel?.lineBreakMode = .byTruncatingTail
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

        titleLabel.text = "设置"
        titleLabel.font = .boldSystemFont(ofSize: 14)
        titleLabel.textColor = .white
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        sectionLabel.text = "音轨"
        sectionLabel.font = .systemFont(ofSize: 12)
        sectionLabel.textColor = UIColor(white: 1, alpha: 0.8)
        sectionLabel.translatesAutoresizingMaskIntoConstraints = false

        tracksStack.axis = .vertical
        tracksStack.alignment = .fill
        tracksStack.spacing = 4
        tracksStack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(titleLabel)
        addSubview(sectionLabel)
        addSubview(tracksStack)

        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: 180),

            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),

            sectionLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 10),
            sectionLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),

            tracksStack.topAnchor.constraint(equalTo: sectionLabel.bottomAnchor, constant: 6),
            tracksStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            tracksStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            tracksStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
        ])
    }

    @objc private func trackTapped(_ sender: UIButton) {
        onSelectTrack?(sender.tag)
    }
}

#if os(iOS)
import UIKit

/// Two-level settings sheet: level1 (mirror/loop/auto/more) + level2 (mode/aspect/other/tracks).
final class SgSettingsPanelView: UIView {
    var onSelectTrack: ((Int) -> Void)?
    var onMirrorChanged: ((Bool) -> Void)?
    var onLoopingChanged: ((Bool) -> Void)?
    var onAutoPlayChanged: ((Bool) -> Void)?
    var onAutoPlayNextChanged: ((Bool) -> Void)?
    var onAspectChanged: ((Int) -> Void)?
    var onHideBlackBarsChanged: ((Bool) -> Void)?
    var onBlackoutChanged: ((Bool) -> Void)?

    private let contentStack = UIStackView()
    private let level1 = UIStackView()
    private let level2 = UIStackView()
    private let tracksStack = UIStackView()

    private var mirrorOn = false
    private var loopingOn = false
    private var autoPlayOn = true
    private var autoPlayNext = true
    private var aspect = 0
    private var hideBlackBars = false
    private var blackout = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    func syncState(
        mirror: Bool,
        looping: Bool,
        autoPlay: Bool,
        autoPlayNext: Bool,
        aspect: Int,
        hideBlackBars: Bool,
        blackout: Bool,
    ) {
        mirrorOn = mirror
        loopingOn = looping
        autoPlayOn = autoPlay
        self.autoPlayNext = autoPlayNext
        self.aspect = aspect
        self.hideBlackBars = hideBlackBars
        self.blackout = blackout
        rebuildLevel1()
        rebuildLevel2()
    }

    func reloadTracks(_ tracks: [[String: Any]]) {
        tracksStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        if tracks.isEmpty {
            tracksStack.addArrangedSubview(mutedLabel("暂无可用音轨"))
            return
        }
        for track in tracks {
            let index = track["index"] as? Int ?? 0
            let label = track["label"] as? String ?? "Track \(index)"
            let language = track["language"] as? String
            let selected = track["selected"] as? Bool ?? false
            let title = language.map { "\(label) (\($0))" } ?? label
            tracksStack.addArrangedSubview(optionButton(title, selected: selected, tag: index, action: #selector(trackTapped(_:))))
        }
    }

    func showLevel1() {
        level1.isHidden = false
        level2.isHidden = true
        setNeedsLayout()
        invalidateIntrinsicContentSize()
    }

    func showLevel2() {
        rebuildLevel2()
        level1.isHidden = true
        level2.isHidden = false
        setNeedsLayout()
        invalidateIntrinsicContentSize()
    }

    private func setup() {
        backgroundColor = KineticPlayerColors.panelBackground
        layer.cornerRadius = 8
        clipsToBounds = true

        // Keep only one level in layout; pinning both level stacks to the panel
        // top+bottom made the panel as tall as level2 and stretched level1 rows.
        contentStack.axis = .vertical
        contentStack.translatesAutoresizingMaskIntoConstraints = false

        level1.axis = .vertical
        level1.spacing = 6
        level1.alignment = .fill
        level1.distribution = .fill

        level2.axis = .vertical
        level2.spacing = 4
        level2.alignment = .fill
        level2.distribution = .fill
        level2.isHidden = true

        tracksStack.axis = .vertical
        tracksStack.spacing = 4

        contentStack.addArrangedSubview(level1)
        contentStack.addArrangedSubview(level2)
        addSubview(contentStack)
        contentStack.setContentHuggingPriority(.required, for: .horizontal)
        contentStack.setContentCompressionResistancePriority(.required, for: .horizontal)
        NSLayoutConstraint.activate([
            contentStack.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            contentStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            contentStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            contentStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
        ])
        rebuildLevel1()
        rebuildLevel2()
    }

    private func rebuildLevel1() {
        level1.arrangedSubviews.forEach { $0.removeFromSuperview() }
        level1.addArrangedSubview(titleLabel("设置"))
        level1.addArrangedSubview(toggleRow("镜像画面", on: mirrorOn, action: #selector(toggleMirror)))
        level1.addArrangedSubview(toggleRow("单集循环", on: loopingOn, action: #selector(toggleLoop)))
        level1.addArrangedSubview(toggleRow("自动开播", on: autoPlayOn, action: #selector(toggleAutoPlay)))
        let more = optionButton("更多播放设置 ›", selected: false, tag: 0, action: #selector(openMore))
        level1.addArrangedSubview(more)
    }

    private func rebuildLevel2() {
        level2.arrangedSubviews.forEach { $0.removeFromSuperview() }
        level2.addArrangedSubview(optionButton("‹ 返回", selected: false, tag: 0, action: #selector(backToLevel1)))
        level2.addArrangedSubview(sectionLabel("播放方式"))
        level2.addArrangedSubview(optionButton("播完暂停", selected: !autoPlayNext, tag: 0, action: #selector(modePause)))
        level2.addArrangedSubview(optionButton("播完切下一集", selected: autoPlayNext, tag: 0, action: #selector(modeNext)))
        level2.addArrangedSubview(sectionLabel("视频比例"))
        level2.addArrangedSubview(optionButton("自动", selected: !hideBlackBars && aspect == 0, tag: 0, action: #selector(aspectAuto)))
        level2.addArrangedSubview(optionButton("16:9", selected: !hideBlackBars && aspect == 1, tag: 0, action: #selector(aspect169)))
        level2.addArrangedSubview(optionButton("4:3", selected: !hideBlackBars && aspect == 2, tag: 0, action: #selector(aspect43)))
        level2.addArrangedSubview(sectionLabel("其它设置"))
        level2.addArrangedSubview(optionButton("隐藏黑边", selected: hideBlackBars, tag: 0, action: #selector(toggleHideBars)))
        level2.addArrangedSubview(optionButton("关灯模式", selected: blackout, tag: 0, action: #selector(toggleBlackout)))
        level2.addArrangedSubview(sectionLabel("音轨"))
        level2.addArrangedSubview(tracksStack)
    }

    private func titleLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .boldSystemFont(ofSize: 14)
        label.textColor = .white
        label.setContentHuggingPriority(.required, for: .vertical)
        return label
    }

    private func sectionLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .systemFont(ofSize: 12)
        label.textColor = UIColor(white: 1, alpha: 0.8)
        label.setContentHuggingPriority(.required, for: .vertical)
        return label
    }

    private func mutedLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .systemFont(ofSize: 12)
        label.textColor = UIColor(white: 1, alpha: 0.6)
        return label
    }

    private func toggleRow(_ title: String, on: Bool, action: Selector) -> UIView {
        let row = UIButton(type: .system)
        row.contentHorizontalAlignment = .fill
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 13)
        titleLabel.textColor = .white
        let value = UILabel()
        value.text = on ? "开" : "关"
        value.font = .systemFont(ofSize: 12)
        value.textColor = on ? KineticPlayerColors.seekActive : UIColor(white: 1, alpha: 0.8)
        value.textAlignment = .right
        let stack = UIStackView(arrangedSubviews: [titleLabel, value])
        stack.axis = .horizontal
        stack.isUserInteractionEnabled = false
        stack.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: row.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: row.trailingAnchor),
            stack.topAnchor.constraint(equalTo: row.topAnchor, constant: 4),
            stack.bottomAnchor.constraint(equalTo: row.bottomAnchor, constant: -4),
            row.heightAnchor.constraint(equalToConstant: 28),
        ])
        row.setContentHuggingPriority(.required, for: .vertical)
        row.setContentCompressionResistancePriority(.required, for: .vertical)
        row.addTarget(self, action: action, for: .touchUpInside)
        return row
    }

    private func optionButton(_ title: String, selected: Bool, tag: Int, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.contentHorizontalAlignment = .leading
        button.titleLabel?.font = .systemFont(ofSize: 13)
        button.setTitle(title, for: .normal)
        button.setTitleColor(selected ? KineticPlayerColors.seekActive : .white, for: .normal)
        button.tag = tag
        button.setContentHuggingPriority(.required, for: .vertical)
        button.setContentCompressionResistancePriority(.required, for: .vertical)
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }

    @objc private func toggleMirror() {
        mirrorOn.toggle()
        onMirrorChanged?(mirrorOn)
        rebuildLevel1()
    }

    @objc private func toggleLoop() {
        loopingOn.toggle()
        onLoopingChanged?(loopingOn)
        rebuildLevel1()
    }

    @objc private func toggleAutoPlay() {
        autoPlayOn.toggle()
        onAutoPlayChanged?(autoPlayOn)
        rebuildLevel1()
    }

    @objc private func openMore() { showLevel2() }
    @objc private func backToLevel1() { showLevel1() }

    @objc private func modePause() {
        autoPlayNext = false
        onAutoPlayNextChanged?(false)
        rebuildLevel2()
    }

    @objc private func modeNext() {
        autoPlayNext = true
        onAutoPlayNextChanged?(true)
        rebuildLevel2()
    }

    @objc private func aspectAuto() {
        aspect = 0
        hideBlackBars = false
        onAspectChanged?(0)
        onHideBlackBarsChanged?(false)
        rebuildLevel2()
    }

    @objc private func aspect169() {
        aspect = 1
        hideBlackBars = false
        onAspectChanged?(1)
        onHideBlackBarsChanged?(false)
        rebuildLevel2()
    }

    @objc private func aspect43() {
        aspect = 2
        hideBlackBars = false
        onAspectChanged?(2)
        onHideBlackBarsChanged?(false)
        rebuildLevel2()
    }

    @objc private func toggleHideBars() {
        hideBlackBars.toggle()
        onHideBlackBarsChanged?(hideBlackBars)
        if hideBlackBars {
            onAspectChanged?(3)
        } else {
            onAspectChanged?(aspect)
        }
        rebuildLevel2()
    }

    @objc private func toggleBlackout() {
        blackout.toggle()
        onBlackoutChanged?(blackout)
        rebuildLevel2()
    }

    @objc private func trackTapped(_ sender: UIButton) {
        onSelectTrack?(sender.tag)
    }
}
#elseif os(macOS)
import AppKit

/// Two-level settings sheet (macOS mirror of iOS).
final class SgSettingsPanelView: NSView {
    var onSelectTrack: ((Int) -> Void)?
    var onMirrorChanged: ((Bool) -> Void)?
    var onLoopingChanged: ((Bool) -> Void)?
    var onAutoPlayChanged: ((Bool) -> Void)?
    var onAutoPlayNextChanged: ((Bool) -> Void)?
    var onAspectChanged: ((Int) -> Void)?
    var onHideBlackBarsChanged: ((Bool) -> Void)?
    var onBlackoutChanged: ((Bool) -> Void)?

    private let contentStack = NSStackView()
    private let level1 = NSStackView()
    private let level2 = NSStackView()
    private let tracksStack = NSStackView()

    private var mirrorOn = false
    private var loopingOn = false
    private var autoPlayOn = true
    private var autoPlayNext = true
    private var aspect = 0
    private var hideBlackBars = false
    private var blackout = false

    override var isFlipped: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    func syncState(
        mirror: Bool,
        looping: Bool,
        autoPlay: Bool,
        autoPlayNext: Bool,
        aspect: Int,
        hideBlackBars: Bool,
        blackout: Bool,
    ) {
        mirrorOn = mirror
        loopingOn = looping
        autoPlayOn = autoPlay
        self.autoPlayNext = autoPlayNext
        self.aspect = aspect
        self.hideBlackBars = hideBlackBars
        self.blackout = blackout
        rebuildLevel1()
        rebuildLevel2()
    }

    func reloadTracks(_ tracks: [[String: Any]]) {
        tracksStack.views.forEach { $0.removeFromSuperview() }
        if tracks.isEmpty {
            tracksStack.addArrangedSubview(mutedLabel("暂无可用音轨"))
        } else {
            for track in tracks {
                let index = track["index"] as? Int ?? 0
                let label = track["label"] as? String ?? "Track \(index)"
                let language = track["language"] as? String
                let selected = track["selected"] as? Bool ?? false
                let title = language.map { "\(label) (\($0))" } ?? label
                tracksStack.addArrangedSubview(optionButton(title, selected: selected, tag: index, action: #selector(trackTapped(_:))))
            }
        }
        refreshPanelHeightIfNeeded()
    }

    func showLevel1() {
        level1.isHidden = false
        level2.isHidden = true
        contentStack.setVisibilityPriority(.mustHold, for: level1)
        contentStack.setVisibilityPriority(.notVisible, for: level2)
        refreshPanelHeightIfNeeded()
    }

    func showLevel2() {
        rebuildLevel2()
        level1.isHidden = true
        level2.isHidden = false
        contentStack.setVisibilityPriority(.notVisible, for: level1)
        contentStack.setVisibilityPriority(.mustHold, for: level2)
        refreshPanelHeightIfNeeded()
    }

    func refreshPanelHeightIfNeeded() {
        needsLayout = true
        layoutSubtreeIfNeeded()
        superview?.needsLayout = true
        superview?.layoutSubtreeIfNeeded()
    }

    private func setup() {
        wantsLayer = true
        layer?.backgroundColor = KineticPlayerColors.panelBackground.cgColor
        layer?.cornerRadius = 8
        layer?.masksToBounds = true

        // Same as iOS: only the visible level should drive panel height.
        contentStack.orientation = .vertical
        contentStack.spacing = 0
        contentStack.detachesHiddenViews = true
        contentStack.alignment = .leading
        contentStack.setContentHuggingPriority(.required, for: .vertical)
        contentStack.translatesAutoresizingMaskIntoConstraints = false

        level1.orientation = .vertical
        level1.spacing = 6
        level1.alignment = .width
        level1.setContentHuggingPriority(.required, for: .vertical)

        level2.orientation = .vertical
        level2.spacing = 4
        level2.alignment = .width
        level2.isHidden = true
        level2.setContentHuggingPriority(.required, for: .vertical)

        tracksStack.orientation = .vertical
        tracksStack.spacing = 4
        tracksStack.alignment = .width
        tracksStack.setContentHuggingPriority(.required, for: .vertical)

        contentStack.addArrangedSubview(level1)
        contentStack.addArrangedSubview(level2)
        addSubview(contentStack)
        contentStack.setContentHuggingPriority(.required, for: .horizontal)
        contentStack.setContentCompressionResistancePriority(.required, for: .horizontal)
        NSLayoutConstraint.activate([
            contentStack.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            contentStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            contentStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            contentStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
        ])
        rebuildLevel1()
        rebuildLevel2()
        showLevel1()
    }

    private func rebuildLevel1() {
        level1.views.forEach { $0.removeFromSuperview() }
        level1.addArrangedSubview(titleLabel("设置"))
        level1.addArrangedSubview(optionButton("镜像画面  \(mirrorOn ? "开" : "关")", selected: mirrorOn, tag: 0, action: #selector(toggleMirror)))
        level1.addArrangedSubview(optionButton("单集循环  \(loopingOn ? "开" : "关")", selected: loopingOn, tag: 0, action: #selector(toggleLoop)))
        level1.addArrangedSubview(optionButton("自动开播  \(autoPlayOn ? "开" : "关")", selected: autoPlayOn, tag: 0, action: #selector(toggleAutoPlay)))
        level1.addArrangedSubview(optionButton("更多播放设置 ›", selected: false, tag: 0, action: #selector(openMore)))
    }

    private func rebuildLevel2() {
        level2.views.forEach { $0.removeFromSuperview() }
        level2.addArrangedSubview(optionButton("‹ 返回", selected: false, tag: 0, action: #selector(backToLevel1)))
        level2.addArrangedSubview(sectionLabel("播放方式"))
        level2.addArrangedSubview(optionButton("播完暂停", selected: !autoPlayNext, tag: 0, action: #selector(modePause)))
        level2.addArrangedSubview(optionButton("播完切下一集", selected: autoPlayNext, tag: 0, action: #selector(modeNext)))
        level2.addArrangedSubview(sectionLabel("视频比例"))
        level2.addArrangedSubview(optionButton("自动", selected: !hideBlackBars && aspect == 0, tag: 0, action: #selector(aspectAuto)))
        level2.addArrangedSubview(optionButton("16:9", selected: !hideBlackBars && aspect == 1, tag: 0, action: #selector(aspect169)))
        level2.addArrangedSubview(optionButton("4:3", selected: !hideBlackBars && aspect == 2, tag: 0, action: #selector(aspect43)))
        level2.addArrangedSubview(sectionLabel("其它设置"))
        level2.addArrangedSubview(optionButton("隐藏黑边", selected: hideBlackBars, tag: 0, action: #selector(toggleHideBars)))
        level2.addArrangedSubview(optionButton("关灯模式", selected: blackout, tag: 0, action: #selector(toggleBlackout)))
        level2.addArrangedSubview(sectionLabel("音轨"))
        level2.addArrangedSubview(tracksStack)
    }

    private func titleLabel(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = .boldSystemFont(ofSize: 14)
        label.textColor = .white
        label.setContentHuggingPriority(.required, for: .vertical)
        return label
    }

    private func sectionLabel(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 12)
        label.textColor = NSColor(white: 1, alpha: 0.8)
        label.setContentHuggingPriority(.required, for: .vertical)
        return label
    }

    private func mutedLabel(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 12)
        label.textColor = NSColor(white: 1, alpha: 0.6)
        label.setContentHuggingPriority(.required, for: .vertical)
        return label
    }

    private func optionButton(_ title: String, selected: Bool, tag: Int, action: Selector) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.isBordered = false
        button.setButtonType(.momentaryChange)
        button.alignment = .left
        button.tag = tag
        button.setContentHuggingPriority(.required, for: .vertical)
        let color: NSColor = selected ? KineticPlayerColors.seekActive : .white
        button.attributedTitle = NSAttributedString(
            string: title,
            attributes: [.foregroundColor: color, .font: NSFont.systemFont(ofSize: 13)],
        )
        return button
    }

    @objc private func toggleMirror() {
        mirrorOn.toggle()
        onMirrorChanged?(mirrorOn)
        rebuildLevel1()
    }

    @objc private func toggleLoop() {
        loopingOn.toggle()
        onLoopingChanged?(loopingOn)
        rebuildLevel1()
    }

    @objc private func toggleAutoPlay() {
        autoPlayOn.toggle()
        onAutoPlayChanged?(autoPlayOn)
        rebuildLevel1()
    }

    @objc private func openMore() {
        showLevel2()
    }

    @objc private func backToLevel1() {
        showLevel1()
    }

    @objc private func modePause() {
        autoPlayNext = false
        onAutoPlayNextChanged?(false)
        rebuildLevel2()
    }

    @objc private func modeNext() {
        autoPlayNext = true
        onAutoPlayNextChanged?(true)
        rebuildLevel2()
    }

    @objc private func aspectAuto() {
        aspect = 0
        hideBlackBars = false
        onAspectChanged?(0)
        rebuildLevel2()
    }

    @objc private func aspect169() {
        aspect = 1
        hideBlackBars = false
        onAspectChanged?(1)
        rebuildLevel2()
    }

    @objc private func aspect43() {
        aspect = 2
        hideBlackBars = false
        onAspectChanged?(2)
        rebuildLevel2()
    }

    @objc private func toggleHideBars() {
        hideBlackBars.toggle()
        onHideBlackBarsChanged?(hideBlackBars)
        onAspectChanged?(hideBlackBars ? 3 : aspect)
        rebuildLevel2()
    }

    @objc private func toggleBlackout() {
        blackout.toggle()
        onBlackoutChanged?(blackout)
        rebuildLevel2()
    }

    @objc private func trackTapped(_ sender: NSButton) {
        onSelectTrack?(sender.tag)
    }
}
#endif

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
    private var strings: [String: String] = [:]
    private let scrollView = UIScrollView()

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

    func applyStrings(_ strings: [String: String]) {
        self.strings = strings
        rebuildLevel1()
        rebuildLevel2()
        refreshContentSize()
    }

    private func t(_ key: String, _ fallback: String) -> String {
        if let value = strings[key], !value.isEmpty { return value }
        return fallback
    }

    override var intrinsicContentSize: CGSize {
        let fittingWidth: CGFloat = 220
        let size = contentStack.systemLayoutSizeFitting(
            CGSize(width: fittingWidth, height: 0),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel,
        )
        return CGSize(width: fittingWidth + 24, height: size.height + 24)
    }

    private func refreshContentSize() {
        invalidateIntrinsicContentSize()
        setNeedsLayout()
    }

    func reloadTracks(_ tracks: [[String: Any]]) {
        tracksStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        if tracks.isEmpty {
            tracksStack.addArrangedSubview(mutedLabel(t("kinetic_no_audio_tracks", "暂无可用音轨")))
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
        refreshContentSize()
    }

    func showLevel1() {
        level1.isHidden = false
        level2.isHidden = true
        refreshContentSize()
    }

    func showLevel2() {
        rebuildLevel2()
        level1.isHidden = true
        level2.isHidden = false
        refreshContentSize()
    }

    private func setup() {
        backgroundColor = KineticPlayerColors.panelBackground
        layer.cornerRadius = 8
        clipsToBounds = true
        setContentHuggingPriority(.defaultHigh, for: .vertical)
        setContentCompressionResistancePriority(.defaultLow, for: .vertical)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = false
        scrollView.showsVerticalScrollIndicator = true
        scrollView.clipsToBounds = true

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
        scrollView.addSubview(contentStack)
        addSubview(scrollView)
        contentStack.setContentHuggingPriority(.required, for: .horizontal)
        contentStack.setContentCompressionResistancePriority(.required, for: .horizontal)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentStack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
        ])
        widthAnchor.constraint(equalToConstant: 220).isActive = true
        rebuildLevel1()
        rebuildLevel2()
    }

    private func rebuildLevel1() {
        level1.arrangedSubviews.forEach { $0.removeFromSuperview() }
        level1.addArrangedSubview(titleLabel(t("kinetic_settings_title", "设置")))
        level1.addArrangedSubview(toggleRow(t("kinetic_settings_mirror", "镜像画面"), on: mirrorOn, action: #selector(toggleMirror)))
        level1.addArrangedSubview(toggleRow(t("kinetic_settings_loop", "单集循环"), on: loopingOn, action: #selector(toggleLoop)))
        level1.addArrangedSubview(toggleRow(t("kinetic_settings_auto_play", "自动开播"), on: autoPlayOn, action: #selector(toggleAutoPlay)))
        let more = optionButton(t("kinetic_settings_more", "更多播放设置 ›"), selected: false, tag: 0, action: #selector(openMore))
        level1.addArrangedSubview(more)
    }

    private func rebuildLevel2() {
        level2.arrangedSubviews.forEach { $0.removeFromSuperview() }
        level2.addArrangedSubview(optionButton(t("kinetic_settings_more_back", "‹ 返回"), selected: false, tag: 0, action: #selector(backToLevel1)))
        level2.addArrangedSubview(sectionLabel(t("kinetic_settings_playback_mode", "播放方式")))
        level2.addArrangedSubview(optionButton(t("kinetic_settings_mode_pause", "播完暂停"), selected: !autoPlayNext, tag: 0, action: #selector(modePause)))
        level2.addArrangedSubview(optionButton(t("kinetic_settings_mode_next", "播完切下一集"), selected: autoPlayNext, tag: 0, action: #selector(modeNext)))
        level2.addArrangedSubview(sectionLabel(t("kinetic_settings_aspect", "视频比例")))
        level2.addArrangedSubview(optionButton(t("kinetic_settings_aspect_auto", "自动"), selected: !hideBlackBars && aspect == 0, tag: 0, action: #selector(aspectAuto)))
        level2.addArrangedSubview(optionButton("16:9", selected: !hideBlackBars && aspect == 1, tag: 0, action: #selector(aspect169)))
        level2.addArrangedSubview(optionButton("4:3", selected: !hideBlackBars && aspect == 2, tag: 0, action: #selector(aspect43)))
        level2.addArrangedSubview(sectionLabel(t("kinetic_settings_other", "其它设置")))
        level2.addArrangedSubview(optionButton(t("kinetic_settings_hide_black_bars", "隐藏黑边"), selected: hideBlackBars, tag: 0, action: #selector(toggleHideBars)))
        level2.addArrangedSubview(optionButton(t("kinetic_settings_blackout", "关灯模式"), selected: blackout, tag: 0, action: #selector(toggleBlackout)))
        level2.addArrangedSubview(sectionLabel(t("kinetic_audio_tracks", "音轨")))
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
        value.text = on ? t("kinetic_settings_on", "开") : t("kinetic_settings_off", "关")
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
    private let scrollView = NSScrollView()

    private var mirrorOn = false
    private var loopingOn = false
    private var autoPlayOn = true
    private var autoPlayNext = true
    private var aspect = 0
    private var hideBlackBars = false
    private var blackout = false
    private var strings: [String: String] = [:]

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

    func applyStrings(_ strings: [String: String]) {
        self.strings = strings
        rebuildLevel1()
        rebuildLevel2()
        refreshPanelHeightIfNeeded()
    }

    private func t(_ key: String, _ fallback: String) -> String {
        if let value = strings[key], !value.isEmpty { return value }
        return fallback
    }

    override var intrinsicContentSize: NSSize {
        contentStack.layoutSubtreeIfNeeded()
        let content = contentStack.fittingSize
        return NSSize(width: max(content.width + 24, 220), height: content.height + 24)
    }

    override var fittingSize: NSSize { intrinsicContentSize }

    override func layout() {
        super.layout()
        syncDocumentSize()
    }

    private func syncDocumentSize() {
        let width = max(scrollView.contentView.bounds.width, 1)
        let height = max(contentStack.fittingSize.height, 1)
        if abs(contentStack.frame.width - width) > 0.5 || abs(contentStack.frame.height - height) > 0.5 {
            contentStack.setFrameSize(NSSize(width: width, height: height))
        }
    }

    func reloadTracks(_ tracks: [[String: Any]]) {
        tracksStack.views.forEach { $0.removeFromSuperview() }
        if tracks.isEmpty {
            tracksStack.addArrangedSubview(mutedLabel(t("kinetic_no_audio_tracks", "暂无可用音轨")))
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
        invalidateIntrinsicContentSize()
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

        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.translatesAutoresizingMaskIntoConstraints = false

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
        contentStack.translatesAutoresizingMaskIntoConstraints = true
        scrollView.documentView = contentStack
        addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
            widthAnchor.constraint(equalToConstant: 220),
        ])
        rebuildLevel1()
        rebuildLevel2()
        showLevel1()
    }

    private func rebuildLevel1() {
        level1.views.forEach { $0.removeFromSuperview() }
        let on = t("kinetic_settings_on", "开")
        let off = t("kinetic_settings_off", "关")
        level1.addArrangedSubview(titleLabel(t("kinetic_settings_title", "设置")))
        level1.addArrangedSubview(optionButton("\(t("kinetic_settings_mirror", "镜像画面"))  \(mirrorOn ? on : off)", selected: mirrorOn, tag: 0, action: #selector(toggleMirror)))
        level1.addArrangedSubview(optionButton("\(t("kinetic_settings_loop", "单集循环"))  \(loopingOn ? on : off)", selected: loopingOn, tag: 0, action: #selector(toggleLoop)))
        level1.addArrangedSubview(optionButton("\(t("kinetic_settings_auto_play", "自动开播"))  \(autoPlayOn ? on : off)", selected: autoPlayOn, tag: 0, action: #selector(toggleAutoPlay)))
        level1.addArrangedSubview(optionButton(t("kinetic_settings_more", "更多播放设置 ›"), selected: false, tag: 0, action: #selector(openMore)))
    }

    private func rebuildLevel2() {
        level2.views.forEach { $0.removeFromSuperview() }
        level2.addArrangedSubview(optionButton(t("kinetic_settings_more_back", "‹ 返回"), selected: false, tag: 0, action: #selector(backToLevel1)))
        level2.addArrangedSubview(sectionLabel(t("kinetic_settings_playback_mode", "播放方式")))
        level2.addArrangedSubview(optionButton(t("kinetic_settings_mode_pause", "播完暂停"), selected: !autoPlayNext, tag: 0, action: #selector(modePause)))
        level2.addArrangedSubview(optionButton(t("kinetic_settings_mode_next", "播完切下一集"), selected: autoPlayNext, tag: 0, action: #selector(modeNext)))
        level2.addArrangedSubview(sectionLabel(t("kinetic_settings_aspect", "视频比例")))
        level2.addArrangedSubview(optionButton(t("kinetic_settings_aspect_auto", "自动"), selected: !hideBlackBars && aspect == 0, tag: 0, action: #selector(aspectAuto)))
        level2.addArrangedSubview(optionButton("16:9", selected: !hideBlackBars && aspect == 1, tag: 0, action: #selector(aspect169)))
        level2.addArrangedSubview(optionButton("4:3", selected: !hideBlackBars && aspect == 2, tag: 0, action: #selector(aspect43)))
        level2.addArrangedSubview(sectionLabel(t("kinetic_settings_other", "其它设置")))
        level2.addArrangedSubview(optionButton(t("kinetic_settings_hide_black_bars", "隐藏黑边"), selected: hideBlackBars, tag: 0, action: #selector(toggleHideBars)))
        level2.addArrangedSubview(optionButton(t("kinetic_settings_blackout", "关灯模式"), selected: blackout, tag: 0, action: #selector(toggleBlackout)))
        level2.addArrangedSubview(sectionLabel(t("kinetic_audio_tracks", "音轨")))
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

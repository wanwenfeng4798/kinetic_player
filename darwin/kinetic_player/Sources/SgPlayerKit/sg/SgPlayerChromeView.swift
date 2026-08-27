protocol SgPlayerChromeDelegate: AnyObject {
    func chromeDidTapPlayPause()
    func chromeDidSeek(toMs: Int)
    func chromeDidTapFullscreen()
    func chromeDidChangeVolume(_ volume: Double)
    func chromeDidToggleMute(_ muted: Bool)
    func chromeDidRequestAudioTracks() -> [[String: Any]]
    func chromeDidSelectAudioTrack(index: Int)
    func chromeDidChangeRate(_ rate: Double)
    func chromeDidChangeMirror(_ enabled: Bool)
    func chromeDidChangeLooping(_ looping: Bool)
    func chromeDidChangeAutoPlayNext(_ enabled: Bool)
    /// 0 auto, 1 16:9, 2 4:3, 3 fill/hide bars
    func chromeDidChangeScaleMode(_ mode: Int)
    func chromeDidChangeBlackout(_ enabled: Bool)
    func chromeDidRequestScreenshot()
}

#if os(iOS)
import UIKit

/// Native playback chrome: play/pause, progress, rate, settings, volume, fullscreen,
/// lock (fullscreen), blackout — plus GSY-style pan gestures (seek / volume / brightness).
final class SgPlayerChromeView: UIView, UIGestureRecognizerDelegate {
    private enum PanGestureKind {
        case none
        case seek
        case volume
        case brightness
    }

    weak var delegate: SgPlayerChromeDelegate?

    /// Matches Android `kinetic_control_icon_size` (20dp glyph in 28dp hit target).
    private static let toolbarIconPointSize: CGFloat = 18
    private static let toolbarButtonSize: CGFloat = 28
    private static let toastTag = 91_017
    private static let popupAnimationDuration: TimeInterval = 0.2
    private static let centerControlButtonSize: CGFloat = 60
    private static let centerControlIconPointSize: CGFloat = 26
    private static let lockButtonTrailingInset: CGFloat = 50
    private static let panActivationThreshold: CGFloat = 12
    /// Hold scrub UI until playhead catches the committed seek (avoids bounce).
    private static let seekSettleToleranceMs: Int64 = 800
    private static let seekHoldTimeout: CFTimeInterval = 1.5
    private static let rateOptions: [Double] = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]
    private static let toolbarSymbolConfig = UIImage.SymbolConfiguration(
        pointSize: toolbarIconPointSize,
        weight: .regular,
    )
    private static let centerControlSymbolConfig = UIImage.SymbolConfiguration(
        pointSize: centerControlIconPointSize,
        weight: .semibold,
    )

    private var config: SgUiConfig
    private let bottomPanel = UIView()
    private let progressRow = UIStackView()
    private let currentTimeLabel = UILabel()
    private let totalTimeLabel = UILabel()
    private let progressSlider = UISlider()
    private let rateButton = UIButton(type: .system)
    private let toolbarPlayButton = UIButton(type: .system)
    private let settingsButton = UIButton(type: .system)
    private let volumeButton = UIButton(type: .system)
    private let fullscreenButton = UIButton(type: .system)
    private let centerPlayButton = UIButton(type: .system)
    private let lockButton = UIButton(type: .system)
    private let blackoutOverlay = UIView()
    private let audioPanel = SgAudioPanelView()
    private let settingsPanel = SgSettingsPanelView()
    private let ratePanel = SgOptionListPanelView()
    private let gestureOverlay = SgGestureOverlayView()

    private var hideTimer: Timer?
    private var popupAnimationGeneration = 0
    private var controlsVisible = true
    private var audioPanelVisible = false
    private var settingsPanelVisible = false
    private var ratePanelVisible = false
    private var isSeeking = false
    private var isPlaying = false
    private var isFullscreen = false
    private var isScreenLocked = false
    private var durationMs: Int64 = 0
    private var positionMs: Int64 = 0
    private var volumeLevel: Double = 1
    private var muted = false
    private var currentRate: Double = 1
    private var mirrorEnabled = false
    private var loopingEnabled = false
    private var autoPlayNextEnabled = true
    private var aspectMode = 0
    private var hideBlackBars = false
    private var blackoutEnabled = false
    /// Target after gesture/slider commit; UI ignores stale playhead until settled.
    private var pendingSeekTargetMs: Int64?
    private var seekHoldDeadline: CFTimeInterval = 0
    private var seekHoldTimer: Timer?

    private var panKind: PanGestureKind = .none
    private var panStartVolume: Double = 1
    private var panStartBrightness: CGFloat = 0
    private var panStartPositionMs: Int64 = 0
    private var panPreviewPositionMs: Int64 = 0
    private var brightnessBeforeSession: CGFloat?
    private var didAdjustBrightness = false
    /// Matches Android: block swipe-volume while the popup is open or its slider is dragged.
    private var volumeSliderDragging = false

    init(config: SgUiConfig) {
        self.config = config
        self.currentRate = Double(config.speed)
        self.loopingEnabled = config.looping
        super.init(frame: .zero)
        KineticPlayerColors.applyAccent(argb: config.accentColor)
        settingsPanel.applyStrings(config.strings)
        clipsToBounds = false
        isUserInteractionEnabled = true
        setupViews()
        applyConfig()
        updateRateButtonTitle()
        scheduleAutoHide()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        hideTimer?.invalidate()
        seekHoldTimer?.invalidate()
        restoreBrightnessIfNeeded()
    }

    /// Restores system brightness if a brightness gesture changed it during this session.
    func restoreBrightnessIfNeeded() {
        guard didAdjustBrightness, let original = brightnessBeforeSession else { return }
        UIScreen.main.brightness = original
        didAdjustBrightness = false
        brightnessBeforeSession = nil
    }

    func updateProgress(positionMs: Int64, durationMs: Int64) {
        self.durationMs = max(0, durationMs)
        totalTimeLabel.text = Self.formatMs(self.durationMs)

        if let pending = pendingSeekTargetMs {
            let arrived = abs(positionMs - pending) <= Self.seekSettleToleranceMs
            let timedOut = CACurrentMediaTime() >= seekHoldDeadline
            if arrived || timedOut {
                clearSeekHold(applyPositionMs: max(0, positionMs))
            }
            // Still waiting for seek to land — keep preview UI, ignore stale playhead.
            return
        }

        // While scrubbing, do not let the live playhead overwrite the preview position.
        if isSeeking || panKind == .seek {
            return
        }

        self.positionMs = max(0, positionMs)
        applyProgressToChromeUI()
    }

    private func applyProgressToChromeUI() {
        currentTimeLabel.text = Self.formatMs(positionMs)
        if durationMs > 0 {
            progressSlider.value = Float(positionMs) / Float(durationMs)
        } else {
            progressSlider.value = 0
        }
    }

    private func beginSeekHold(toMs targetMs: Int64) {
        pendingSeekTargetMs = targetMs
        positionMs = targetMs
        isSeeking = true
        seekHoldDeadline = CACurrentMediaTime() + Self.seekHoldTimeout
        currentTimeLabel.text = Self.formatMs(targetMs)
        if durationMs > 0 {
            progressSlider.value = Float(targetMs) / Float(durationMs)
        }
        seekHoldTimer?.invalidate()
        seekHoldTimer = Timer.scheduledTimer(
            withTimeInterval: Self.seekHoldTimeout,
            repeats: false,
        ) { [weak self] _ in
            guard let self, self.pendingSeekTargetMs != nil else { return }
            // Progress may be suppressed while seek is in-flight; still unlock UI.
            self.clearSeekHold(applyPositionMs: self.positionMs)
        }
    }

    private func clearSeekHold(applyPositionMs: Int64) {
        seekHoldTimer?.invalidate()
        seekHoldTimer = nil
        pendingSeekTargetMs = nil
        isSeeking = false
        positionMs = applyPositionMs
        applyProgressToChromeUI()
    }

    func updatePlayState(isPlaying: Bool) {
        self.isPlaying = isPlaying
        updateCenterPlayIcon()
    }

    func syncVolume(volume: Double, muted: Bool) {
        volumeLevel = volume
        self.muted = muted
        audioPanel.syncVolume(volume: volume, muted: muted)
        updateVolumeIcon()
    }

    func setControlsVisible(_ visible: Bool, animated: Bool = true) {
        if isScreenLocked {
            // Locked: only the unlock button stays reachable.
            controlsVisible = false
            hideTimer?.invalidate()
            applyLockedChromeVisibility(animated: animated)
            return
        }
        controlsVisible = visible
        let alpha: CGFloat = visible ? 1 : 0
        let updates = {
            self.bottomPanel.alpha = alpha
            self.centerPlayButton.alpha = alpha
            self.bottomPanel.isUserInteractionEnabled = visible
            self.centerPlayButton.isUserInteractionEnabled = visible
            self.updateLockButtonVisibility()
            if !visible {
                self.hideAudioPanel(animated: false)
                self.hideSettingsPanel(animated: false)
                self.hideRatePanel(animated: false)
            }
        }
        if animated {
            UIView.animate(withDuration: 0.2, animations: updates)
        } else {
            updates()
        }
        if visible {
            scheduleAutoHide()
        } else {
            hideTimer?.invalidate()
        }
    }

    func toggleControlsVisibility() {
        setControlsVisible(!controlsVisible)
    }

    func updateFullscreenIcon(isFullscreen: Bool) {
        setFullscreenActive(isFullscreen)
    }

    /// Updates fullscreen state (icon + lock button visibility).
    func setFullscreenActive(_ active: Bool) {
        isFullscreen = active
        let symbol = active ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right"
        setToolbarSymbol(fullscreenButton, systemName: symbol)
        if !active, isScreenLocked {
            setScreenLocked(false)
        } else {
            updateLockButtonVisibility()
        }
    }

    private func setupViews() {
        backgroundColor = .clear

        blackoutOverlay.backgroundColor = UIColor(white: 0, alpha: 0.6)
        blackoutOverlay.isUserInteractionEnabled = false
        blackoutOverlay.isHidden = true
        blackoutOverlay.translatesAutoresizingMaskIntoConstraints = false
        addSubview(blackoutOverlay)

        bottomPanel.backgroundColor = UIColor(white: 0, alpha: 0.55)
        bottomPanel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(bottomPanel)

        progressRow.axis = .horizontal
        progressRow.alignment = .center
        progressRow.spacing = 8
        progressRow.translatesAutoresizingMaskIntoConstraints = false

        currentTimeLabel.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        currentTimeLabel.textColor = .white
        currentTimeLabel.text = "00:00"
        currentTimeLabel.setContentHuggingPriority(.required, for: .horizontal)

        totalTimeLabel.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        totalTimeLabel.textColor = .white
        totalTimeLabel.text = "00:00"
        totalTimeLabel.setContentHuggingPriority(.required, for: .horizontal)

        progressSlider.minimumValue = 0
        progressSlider.maximumValue = 1
        progressSlider.minimumTrackTintColor = KineticPlayerColors.seekActive
        progressSlider.maximumTrackTintColor = KineticPlayerColors.seekBackground
        progressSlider.addTarget(self, action: #selector(sliderTouchDown), for: .touchDown)
        progressSlider.addTarget(self, action: #selector(sliderChanged), for: .valueChanged)
        progressSlider.addTarget(self, action: #selector(sliderTouchUp), for: [.touchUpInside, .touchUpOutside, .touchCancel])

        rateButton.addTarget(self, action: #selector(rateTapped), for: .touchUpInside)
        rateButton.tintColor = .white
        rateButton.setTitleColor(.white, for: .normal)
        rateButton.titleLabel?.font = .systemFont(ofSize: 12, weight: .semibold)
        rateButton.setContentHuggingPriority(.required, for: .horizontal)
        rateButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            rateButton.heightAnchor.constraint(equalToConstant: Self.toolbarButtonSize),
            rateButton.widthAnchor.constraint(greaterThanOrEqualToConstant: Self.toolbarButtonSize),
        ])

        toolbarPlayButton.addTarget(self, action: #selector(centerPlayTapped), for: .touchUpInside)
        styleToolbarButton(toolbarPlayButton)

        settingsButton.addTarget(self, action: #selector(settingsTapped), for: .touchUpInside)
        styleToolbarButton(settingsButton)
        setToolbarSymbol(settingsButton, systemName: "gearshape.fill")

        volumeButton.addTarget(self, action: #selector(volumeTapped), for: .touchUpInside)
        styleToolbarButton(volumeButton)

        fullscreenButton.addTarget(self, action: #selector(fullscreenTapped), for: .touchUpInside)
        styleToolbarButton(fullscreenButton)

        progressRow.addArrangedSubview(toolbarPlayButton)
        progressRow.addArrangedSubview(currentTimeLabel)
        progressRow.addArrangedSubview(progressSlider)
        progressRow.addArrangedSubview(totalTimeLabel)
        progressRow.addArrangedSubview(rateButton)
        progressRow.addArrangedSubview(settingsButton)
        progressRow.addArrangedSubview(volumeButton)
        progressRow.addArrangedSubview(fullscreenButton)

        bottomPanel.addSubview(progressRow)

        audioPanel.translatesAutoresizingMaskIntoConstraints = false
        audioPanel.isHidden = true
        audioPanel.isUserInteractionEnabled = false
        audioPanel.onVolumeChanged = { [weak self] volume in
            guard let self else { return }
            self.volumeLevel = volume
            self.muted = volume <= 0.001
            self.updateVolumeIcon()
            self.delegate?.chromeDidChangeVolume(volume)
            self.scheduleAutoHide()
        }
        audioPanel.onDraggingChanged = { [weak self] dragging in
            self?.volumeSliderDragging = dragging
        }
        addSubview(audioPanel)

        settingsPanel.translatesAutoresizingMaskIntoConstraints = false
        settingsPanel.setContentHuggingPriority(.required, for: .horizontal)
        settingsPanel.setContentHuggingPriority(.defaultHigh, for: .vertical)
        settingsPanel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        settingsPanel.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        settingsPanel.isHidden = true
        settingsPanel.isUserInteractionEnabled = false
        settingsPanel.onSelectTrack = { [weak self] index in
            guard let self else { return }
            self.delegate?.chromeDidSelectAudioTrack(index: index)
            self.reloadSettingsTracks()
            self.scheduleAutoHide()
        }
        settingsPanel.onMirrorChanged = { [weak self] enabled in
            guard let self else { return }
            self.mirrorEnabled = enabled
            self.delegate?.chromeDidChangeMirror(enabled)
        }
        settingsPanel.onLoopingChanged = { [weak self] looping in
            guard let self else { return }
            self.loopingEnabled = looping
            self.delegate?.chromeDidChangeLooping(looping)
        }
        settingsPanel.onAutoPlayNextChanged = { [weak self] enabled in
            guard let self else { return }
            self.autoPlayNextEnabled = enabled
            self.delegate?.chromeDidChangeAutoPlayNext(enabled)
        }
        settingsPanel.onAspectChanged = { [weak self] mode in
            guard let self else { return }
            if mode == 3 {
                self.hideBlackBars = true
            } else {
                self.aspectMode = mode
                self.hideBlackBars = false
            }
            self.delegate?.chromeDidChangeScaleMode(mode)
        }
        settingsPanel.onHideBlackBarsChanged = { [weak self] hide in
            self?.hideBlackBars = hide
        }
        settingsPanel.onBlackoutChanged = { [weak self] enabled in
            guard let self else { return }
            self.setBlackoutEnabled(enabled)
            self.delegate?.chromeDidChangeBlackout(enabled)
        }
        settingsPanel.onScreenshot = { [weak self] in
            self?.captureScreenshotFromSettings()
        }
        addSubview(settingsPanel)

        ratePanel.translatesAutoresizingMaskIntoConstraints = false
        ratePanel.isHidden = true
        ratePanel.isUserInteractionEnabled = false
        ratePanel.onSelect = { [weak self] index in
            guard let self, Self.rateOptions.indices.contains(index) else { return }
            self.setSpeed(Self.rateOptions[index])
            self.hideRatePanel()
        }
        addSubview(ratePanel)

        centerPlayButton.tintColor = .white
        centerPlayButton.backgroundColor = UIColor(white: 0, alpha: 0.45)
        centerPlayButton.layer.cornerRadius = Self.centerControlButtonSize / 2
        centerPlayButton.translatesAutoresizingMaskIntoConstraints = false
        centerPlayButton.addTarget(self, action: #selector(centerPlayTapped), for: .touchUpInside)
        addSubview(centerPlayButton)

        lockButton.tintColor = .white
        lockButton.backgroundColor = UIColor(white: 0, alpha: 0.45)
        lockButton.layer.cornerRadius = Self.centerControlButtonSize / 2
        lockButton.translatesAutoresizingMaskIntoConstraints = false
        lockButton.isHidden = true
        lockButton.addTarget(self, action: #selector(lockTapped), for: .touchUpInside)
        updateLockIcon()
        addSubview(lockButton)

        addSubview(gestureOverlay)

        NSLayoutConstraint.activate([
            blackoutOverlay.leadingAnchor.constraint(equalTo: leadingAnchor),
            blackoutOverlay.trailingAnchor.constraint(equalTo: trailingAnchor),
            blackoutOverlay.topAnchor.constraint(equalTo: topAnchor),
            blackoutOverlay.bottomAnchor.constraint(equalTo: bottomAnchor),

            bottomPanel.leadingAnchor.constraint(equalTo: leadingAnchor),
            bottomPanel.trailingAnchor.constraint(equalTo: trailingAnchor),
            bottomPanel.bottomAnchor.constraint(equalTo: bottomAnchor),

            progressRow.leadingAnchor.constraint(equalTo: bottomPanel.leadingAnchor, constant: 8),
            progressRow.trailingAnchor.constraint(equalTo: bottomPanel.trailingAnchor, constant: -8),
            progressRow.topAnchor.constraint(equalTo: bottomPanel.topAnchor, constant: 4),
            progressRow.bottomAnchor.constraint(equalTo: bottomPanel.bottomAnchor, constant: -4),
            progressRow.heightAnchor.constraint(equalToConstant: 36),

            audioPanel.centerXAnchor.constraint(equalTo: volumeButton.centerXAnchor),
            audioPanel.bottomAnchor.constraint(equalTo: volumeButton.topAnchor, constant: -6),

            settingsPanel.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 8),
            settingsPanel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -8),
            settingsPanel.bottomAnchor.constraint(equalTo: settingsButton.topAnchor, constant: -6),
            settingsPanel.topAnchor.constraint(greaterThanOrEqualTo: topAnchor, constant: 8),

            ratePanel.centerXAnchor.constraint(equalTo: rateButton.centerXAnchor),
            ratePanel.bottomAnchor.constraint(equalTo: rateButton.topAnchor, constant: -6),

            centerPlayButton.centerXAnchor.constraint(equalTo: centerXAnchor),
            centerPlayButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            centerPlayButton.widthAnchor.constraint(equalToConstant: Self.centerControlButtonSize),
            centerPlayButton.heightAnchor.constraint(equalToConstant: Self.centerControlButtonSize),

            lockButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Self.lockButtonTrailingInset),
            lockButton.centerYAnchor.constraint(equalTo: centerPlayButton.centerYAnchor),
            lockButton.widthAnchor.constraint(equalToConstant: Self.centerControlButtonSize),
            lockButton.heightAnchor.constraint(equalToConstant: Self.centerControlButtonSize),

            gestureOverlay.centerXAnchor.constraint(equalTo: centerXAnchor),
            gestureOverlay.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
        let settingsCenter = settingsPanel.centerXAnchor.constraint(equalTo: settingsButton.centerXAnchor)
        settingsCenter.priority = .defaultHigh
        settingsCenter.isActive = true

        updateCenterPlayIcon()
        updateFullscreenIcon(isFullscreen: false)
        updateVolumeIcon()

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleBackgroundTap))
        tap.delegate = self
        addGestureRecognizer(tap)

        if config.enableNativeControls {
            let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePanGesture(_:)))
            pan.delegate = self
            pan.maximumNumberOfTouches = 1
            addGestureRecognizer(pan)
        }
    }

    private func applyConfig() {
        isHidden = !config.enableNativeControls
        bottomPanel.isHidden = !config.enableNativeControls
        centerPlayButton.isHidden = !config.enableNativeControls
        toolbarPlayButton.isHidden = !config.enableNativeControls
        volumeButton.isHidden = !config.showVolumeToolbar
        settingsButton.isHidden = !config.showSettingsButton
        rateButton.isHidden = !config.enableNativeControls
        fullscreenButton.isHidden = !config.showFullscreenButton
        if !config.showVolumeToolbar {
            hideAudioPanel()
        }
        if !config.showSettingsButton {
            hideSettingsPanel()
        }
        bottomPanel.isUserInteractionEnabled = controlsVisible
        centerPlayButton.isUserInteractionEnabled = controlsVisible
        updateLockButtonVisibility()
    }

    func applyUiConfig(_ next: SgUiConfig) {
        config = next
        KineticPlayerColors.applyAccent(argb: next.accentColor)
        settingsPanel.applyStrings(next.strings)
        applyConfig()
        reloadRatePanel()
    }

    func applyChromeLocale(locale: String, strings: [String: String]) {
        config.locale = locale
        config.strings = strings
        settingsPanel.applyStrings(strings)
        reloadRatePanel()
    }

    private func chromeString(_ key: String, _ fallback: String) -> String {
        if let value = config.strings[key], !value.isEmpty { return value }
        return fallback
    }

    private func showChromeToast(_ message: String) {
        viewWithTag(Self.toastTag)?.removeFromSuperview()
        let pill = UIView()
        pill.tag = Self.toastTag
        pill.backgroundColor = UIColor(white: 0, alpha: 0.72)
        pill.layer.cornerRadius = 8
        pill.translatesAutoresizingMaskIntoConstraints = false
        let label = UILabel()
        label.text = message
        label.textColor = .white
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        pill.addSubview(label)
        addSubview(pill)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: pill.topAnchor, constant: 8),
            label.bottomAnchor.constraint(equalTo: pill.bottomAnchor, constant: -8),
            label.leadingAnchor.constraint(equalTo: pill.leadingAnchor, constant: 14),
            label.trailingAnchor.constraint(equalTo: pill.trailingAnchor, constant: -14),
            pill.centerXAnchor.constraint(equalTo: centerXAnchor),
            pill.centerYAnchor.constraint(equalTo: centerYAnchor),
            pill.widthAnchor.constraint(lessThanOrEqualTo: widthAnchor, constant: -32),
        ])
        pill.alpha = 0
        UIView.animate(withDuration: 0.2, animations: { pill.alpha = 1 }) { _ in
            UIView.animate(
                withDuration: 0.2,
                delay: 1.4,
                options: [],
                animations: { pill.alpha = 0 },
                completion: { _ in pill.removeFromSuperview() },
            )
        }
    }

    private func updateCenterPlayIcon() {
        let symbol = isPlaying ? "pause.fill" : "play.fill"
        centerPlayButton.setImage(
            UIImage(systemName: symbol, withConfiguration: Self.centerControlSymbolConfig),
            for: .normal,
        )
        setToolbarSymbol(toolbarPlayButton, systemName: symbol)
    }

    private func updateVolumeIcon() {
        let symbolName = muted || volumeLevel <= 0.001 ? "speaker.slash.fill" : "speaker.wave.2.fill"
        setToolbarSymbol(volumeButton, systemName: symbolName)
    }

    private func updateLockIcon() {
        let symbol = isScreenLocked ? "lock.fill" : "lock.open.fill"
        lockButton.setImage(
            UIImage(systemName: symbol, withConfiguration: Self.centerControlSymbolConfig),
            for: .normal,
        )
    }

    private func updateLockButtonVisibility() {
        let show = config.enableNativeControls
            && config.showLockButton
            && isFullscreen
            && (controlsVisible || isScreenLocked)
        lockButton.isHidden = !show
        lockButton.isUserInteractionEnabled = show
        if show {
            bringSubviewToFront(lockButton)
        }
    }

    private func applyLockedChromeVisibility(animated: Bool) {
        let updates = {
            self.bottomPanel.alpha = 0
            self.centerPlayButton.alpha = 0
            self.bottomPanel.isUserInteractionEnabled = false
            self.centerPlayButton.isUserInteractionEnabled = false
            self.hideAudioPanel(animated: false)
            self.hideSettingsPanel(animated: false)
            self.hideRatePanel(animated: false)
            self.updateLockButtonVisibility()
        }
        if animated {
            UIView.animate(withDuration: 0.2, animations: updates)
        } else {
            updates()
        }
    }

    private func setScreenLocked(_ locked: Bool) {
        isScreenLocked = locked
        updateLockIcon()
        if locked {
            setControlsVisible(false, animated: true)
        } else {
            setControlsVisible(true, animated: true)
        }
    }

    private func setBlackoutEnabled(_ enabled: Bool) {
        blackoutEnabled = enabled
        blackoutOverlay.isHidden = !enabled
        if enabled {
            insertSubview(blackoutOverlay, at: 0)
        }
    }

    private func setSpeed(_ rate: Double) {
        currentRate = rate
        updateRateButtonTitle()
        reloadRatePanel()
        delegate?.chromeDidChangeRate(rate)
    }

    private func updateRateButtonTitle() {
        rateButton.setTitle(Self.formatRateLabel(currentRate), for: .normal)
    }

    private func reloadRatePanel() {
        let options = Self.rateOptions.map { rate in
            (label: Self.formatRateLabel(rate), selected: abs(rate - currentRate) < 0.001)
        }
        ratePanel.reload(title: chromeString("kinetic_rate_title", "倍速"), options: options)
    }

    private static func formatRateLabel(_ rate: Double) -> String {
        if rate == Double(Int(rate)) {
            return String(format: "%.1fx", rate)
        }
        return String(format: "%gx", rate)
    }

    private func styleToolbarButton(_ button: UIButton) {
        button.tintColor = .white
        button.setContentHuggingPriority(.required, for: .horizontal)
        button.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: Self.toolbarButtonSize),
            button.heightAnchor.constraint(equalToConstant: Self.toolbarButtonSize),
        ])
    }

    private func setToolbarSymbol(_ button: UIButton, systemName: String) {
        let image = UIImage(systemName: systemName, withConfiguration: Self.toolbarSymbolConfig)
        button.setImage(image, for: .normal)
    }

    private func toggleAudioPanel() {
        if audioPanelVisible {
            hideAudioPanel()
        } else {
            hideSettingsPanel(animated: false)
            hideRatePanel(animated: false)
            showAudioPanel()
        }
    }

    private func toggleSettingsPanel() {
        if settingsPanelVisible {
            hideSettingsPanel()
        } else {
            hideAudioPanel(animated: false)
            hideRatePanel(animated: false)
            showSettingsPanel()
        }
    }

    private func toggleRatePanel() {
        if ratePanelVisible {
            hideRatePanel()
        } else {
            hideAudioPanel(animated: false)
            hideSettingsPanel(animated: false)
            showRatePanel()
        }
    }

    private func setPopupVisible(
        _ panel: UIView,
        visible: Bool,
        flag: inout Bool,
        animated: Bool = true,
    ) {
        popupAnimationGeneration += 1
        let generation = popupAnimationGeneration
        panel.layer.removeAllAnimations()
        if visible {
            flag = true
            panel.isHidden = false
            panel.isUserInteractionEnabled = true
            bringSubviewToFront(panel)
            hideTimer?.invalidate()
            if animated {
                panel.alpha = 0
                UIView.animate(withDuration: Self.popupAnimationDuration) {
                    panel.alpha = 1
                }
            } else {
                panel.alpha = 1
            }
        } else {
            flag = false
            panel.isUserInteractionEnabled = false
            let finish = {
                panel.isHidden = true
                panel.alpha = 1
            }
            if !animated || panel.isHidden {
                finish()
                scheduleAutoHide()
                return
            }
            UIView.animate(withDuration: Self.popupAnimationDuration, animations: {
                panel.alpha = 0
            }) { finished in
                guard finished, generation == self.popupAnimationGeneration else { return }
                finish()
                self.scheduleAutoHide()
            }
        }
    }

    private func showAudioPanel() {
        setPopupVisible(audioPanel, visible: true, flag: &audioPanelVisible)
    }

    private func hideAudioPanel(animated: Bool = true) {
        setPopupVisible(audioPanel, visible: false, flag: &audioPanelVisible, animated: animated)
    }

    private func showSettingsPanel() {
        settingsPanel.syncState(
            mirror: mirrorEnabled,
            looping: loopingEnabled,
            autoPlay: true,
            autoPlayNext: autoPlayNextEnabled,
            aspect: aspectMode,
            hideBlackBars: hideBlackBars,
            blackout: blackoutEnabled,
        )
        settingsPanel.showLevel1()
        reloadSettingsTracks()
        setPopupVisible(settingsPanel, visible: true, flag: &settingsPanelVisible)
    }

    private func hideSettingsPanel(animated: Bool = true) {
        setPopupVisible(settingsPanel, visible: false, flag: &settingsPanelVisible, animated: animated)
    }

    private func captureScreenshotFromSettings() {
        hideSettingsPanel()
        delegate?.chromeDidRequestScreenshot()
    }

    private func showRatePanel() {
        reloadRatePanel()
        setPopupVisible(ratePanel, visible: true, flag: &ratePanelVisible)
    }

    private func hideRatePanel(animated: Bool = true) {
        setPopupVisible(ratePanel, visible: false, flag: &ratePanelVisible, animated: animated)
    }

    private func reloadSettingsTracks() {
        let tracks = delegate?.chromeDidRequestAudioTracks() ?? []
        settingsPanel.reloadTracks(tracks)
    }

    private func scheduleAutoHide() {
        hideTimer?.invalidate()
        guard config.enableNativeControls,
              isPlaying,
              !isScreenLocked,
              !audioPanelVisible,
              !settingsPanelVisible,
              !ratePanelVisible else { return }
        hideTimer = Timer.scheduledTimer(
            withTimeInterval: TimeInterval(config.dismissControlTimeMs) / 1000.0,
            repeats: false,
        ) { [weak self] _ in
            self?.setControlsVisible(false)
        }
    }

    @objc private func handleBackgroundTap() {
        if isScreenLocked {
            return
        }
        if audioPanelVisible {
            hideAudioPanel()
            return
        }
        if settingsPanelVisible {
            hideSettingsPanel()
            return
        }
        if ratePanelVisible {
            hideRatePanel()
            return
        }
        toggleControlsVisibility()
    }

    // MARK: - Pan gestures (seek / volume / brightness)

    /// Same rule as Android `shouldBlockGestureVolume`: popup open or slider drag wins.
    private var shouldBlockGestureVolume: Bool {
        audioPanelVisible || volumeSliderDragging
    }

    @objc private func handlePanGesture(_ gesture: UIPanGestureRecognizer) {
        guard config.enableNativeControls, !isScreenLocked else { return }

        switch gesture.state {
        case .began:
            hideTimer?.invalidate()
            // Do not close the volume popup here — matches Android (panel stays open;
            // only swipe-volume is blocked while it is visible / being dragged).
            panKind = .none
            panStartVolume = volumeLevel
            panStartBrightness = UIScreen.main.brightness
            panStartPositionMs = positionMs
            panPreviewPositionMs = positionMs

        case .changed:
            let translation = gesture.translation(in: self)
            if panKind == .none {
                let absX = abs(translation.x)
                let absY = abs(translation.y)
                guard max(absX, absY) >= Self.panActivationThreshold else { return }
                if absX >= absY {
                    panKind = .seek
                    isSeeking = true
                } else {
                    let start = gesture.location(in: self)
                    let preferBrightness = start.x < bounds.width * 0.5
                    if preferBrightness {
                        panKind = .brightness
                        if brightnessBeforeSession == nil {
                            brightnessBeforeSession = UIScreen.main.brightness
                        }
                    } else if shouldBlockGestureVolume {
                        // Volume popup / slider owns volume control — ignore right-side swipe.
                        return
                    } else {
                        panKind = .volume
                    }
                }
            }
            if panKind == .volume, shouldBlockGestureVolume {
                return
            }
            applyPanChange(translation: translation)

        case .ended, .cancelled, .failed:
            finishPanGesture()

        default:
            break
        }
    }

    private func applyPanChange(translation: CGPoint) {
        let height = max(bounds.height, 1)
        let width = max(bounds.width, 1)

        switch panKind {
        case .seek:
            guard durationMs > 0 else { return }
            // Full-width drag ≈ seek across entire duration (same as GSY / mSeekRatio=1).
            let deltaMs = Int64((translation.x / width) * Double(durationMs))
            let target = max(0, min(durationMs, panStartPositionMs + deltaMs))
            panPreviewPositionMs = target
            progressSlider.value = Float(target) / Float(durationMs)
            currentTimeLabel.text = Self.formatMs(target)
            let total = Self.formatMs(durationMs)
            gestureOverlay.show(
                symbolName: translation.x >= 0 ? "forward.fill" : "backward.fill",
                text: "\(Self.formatMs(target)) / \(total)",
            )
            bringSubviewToFront(gestureOverlay)

        case .volume:
            // GSY uses ~3× vertical sensitivity for volume swipes.
            let delta = -Double(translation.y) * 3.0 / Double(height)
            let level = max(0, min(1, panStartVolume + delta))
            volumeLevel = level
            muted = level <= 0.001
            updateVolumeIcon()
            audioPanel.syncVolume(volume: level, muted: muted)
            delegate?.chromeDidChangeVolume(level)
            let percent = Int((level * 100).rounded())
            let symbol = percent == 0 ? "speaker.slash.fill" : "speaker.wave.2.fill"
            gestureOverlay.show(symbolName: symbol, text: "\(percent)%")
            bringSubviewToFront(gestureOverlay)

        case .brightness:
            let delta = -translation.y / height
            let level = max(0, min(1, panStartBrightness + delta))
            UIScreen.main.brightness = level
            didAdjustBrightness = true
            let percent = Int((level * 100).rounded())
            let symbol = percent < 30 ? "sun.min.fill" : "sun.max.fill"
            gestureOverlay.show(symbolName: symbol, text: "\(percent)%")
            bringSubviewToFront(gestureOverlay)

        case .none:
            break
        }
    }

    private func finishPanGesture() {
        let kind = panKind
        panKind = .none
        gestureOverlay.hide(animated: true)

        switch kind {
        case .seek:
            if durationMs > 0 {
                let target = panPreviewPositionMs
                beginSeekHold(toMs: target)
                delegate?.chromeDidSeek(toMs: Int(target))
            } else {
                clearSeekHold(applyPositionMs: positionMs)
            }
        case .volume, .brightness, .none:
            break
        }
        scheduleAutoHide()
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        let point = touch.location(in: self)
        if isScreenLocked {
            return !lockButton.frame.contains(point)
        }
        if audioPanelVisible, audioPanel.frame.contains(point) {
            return false
        }
        if settingsPanelVisible, settingsPanel.frame.contains(point) {
            return false
        }
        if ratePanelVisible, ratePanel.frame.contains(point) {
            return false
        }
        if !lockButton.isHidden, lockButton.frame.contains(point) {
            return false
        }
        if bottomPanel.frame.contains(point), bottomPanel.alpha > 0.01, controlsVisible {
            return false
        }
        if controlsVisible {
            if centerPlayButton.frame.contains(point) {
                return false
            }
            if touchHitsInteractiveControl(at: point) {
                return false
            }
        }
        return true
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer,
    ) -> Bool {
        false
    }

    private func touchHitsInteractiveControl(at point: CGPoint) -> Bool {
        for control in [
            toolbarPlayButton,
            progressSlider,
            rateButton,
            settingsButton,
            volumeButton,
            fullscreenButton,
        ] {
            let frame = control.convert(control.bounds, to: self)
            if frame.contains(point) {
                return true
            }
        }
        return false
    }

    @objc private func centerPlayTapped() {
        delegate?.chromeDidTapPlayPause()
        scheduleAutoHide()
    }

    @objc private func fullscreenTapped() {
        delegate?.chromeDidTapFullscreen()
        scheduleAutoHide()
    }

    @objc private func settingsTapped() {
        toggleSettingsPanel()
    }

    @objc private func volumeTapped() {
        toggleAudioPanel()
    }

    @objc private func rateTapped() {
        toggleRatePanel()
    }

    @objc private func lockTapped() {
        setScreenLocked(!isScreenLocked)
    }

    @objc private func sliderTouchDown() {
        isSeeking = true
        hideTimer?.invalidate()
    }

    @objc private func sliderChanged() {
        guard durationMs > 0 else { return }
        let positionMs = Int64(progressSlider.value * Float(durationMs))
        currentTimeLabel.text = Self.formatMs(positionMs)
    }

    @objc private func sliderTouchUp() {
        guard durationMs > 0 else {
            clearSeekHold(applyPositionMs: positionMs)
            return
        }
        let target = max(0, Int64(progressSlider.value * Float(durationMs)))
        beginSeekHold(toMs: target)
        delegate?.chromeDidSeek(toMs: Int(target))
        scheduleAutoHide()
    }

    private static func formatMs(_ ms: Int64) -> String {
        let totalSeconds = max(0, ms / 1000)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
#elseif os(macOS)
import AppKit

/// Minimal filled-track slider control (NSSlider has no public tintable
/// min/max track-color API); shared by the progress bar (horizontal) and the
/// volume popup (vertical).
final class SgTrackSlider: NSView {
    enum Orientation {
        case horizontal
        case vertical
    }

    var orientation: Orientation = .horizontal
    var minimumValue: Float = 0
    var maximumValue: Float = 1
    var value: Float = 0 {
        didSet { needsDisplay = true }
    }
    var minimumTrackTintColor: NSColor = KineticPlayerColors.seekActive
    var maximumTrackTintColor: NSColor = KineticPlayerColors.seekBackground
    var thumbColor: NSColor = .white
    var isEnabled = true
    var onTouchDown: (() -> Void)?
    var onValueChanged: (() -> Void)?
    var onTouchUp: (() -> Void)?

    private let trackThickness: CGFloat = 3
    private let thumbRadius: CGFloat = 6
    private var isDraggingTrack = false

    override var isFlipped: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private var progressRatio: CGFloat {
        guard maximumValue > minimumValue else { return 0 }
        let ratio = CGFloat((value - minimumValue) / (maximumValue - minimumValue))
        return min(max(ratio, 0), 1)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        switch orientation {
        case .horizontal:
            drawHorizontal()
        case .vertical:
            drawVertical()
        }
    }

    private func drawHorizontal() {
        let midY = bounds.midY
        let full = NSRect(x: 0, y: midY - trackThickness / 2, width: bounds.width, height: trackThickness)
        maximumTrackTintColor.setFill()
        NSBezierPath(roundedRect: full, xRadius: trackThickness / 2, yRadius: trackThickness / 2).fill()

        let activeWidth = bounds.width * progressRatio
        let active = NSRect(x: 0, y: midY - trackThickness / 2, width: activeWidth, height: trackThickness)
        minimumTrackTintColor.setFill()
        NSBezierPath(roundedRect: active, xRadius: trackThickness / 2, yRadius: trackThickness / 2).fill()

        drawThumb(at: NSPoint(x: activeWidth, y: midY))
    }

    private func drawVertical() {
        // isFlipped == true (y=0 at top); fill grows upward from the bottom as value increases.
        let midX = bounds.midX
        let full = NSRect(x: midX - trackThickness / 2, y: 0, width: trackThickness, height: bounds.height)
        maximumTrackTintColor.setFill()
        NSBezierPath(roundedRect: full, xRadius: trackThickness / 2, yRadius: trackThickness / 2).fill()

        let activeHeight = bounds.height * progressRatio
        let active = NSRect(
            x: midX - trackThickness / 2,
            y: bounds.height - activeHeight,
            width: trackThickness,
            height: activeHeight,
        )
        minimumTrackTintColor.setFill()
        NSBezierPath(roundedRect: active, xRadius: trackThickness / 2, yRadius: trackThickness / 2).fill()

        drawThumb(at: NSPoint(x: midX, y: bounds.height - activeHeight))
    }

    private func drawThumb(at center: NSPoint) {
        let rect = NSRect(x: center.x - thumbRadius, y: center.y - thumbRadius, width: thumbRadius * 2, height: thumbRadius * 2)
        thumbColor.setFill()
        NSBezierPath(ovalIn: rect).fill()
    }

    override func mouseDown(with event: NSEvent) {
        guard isEnabled else { return }
        isDraggingTrack = true
        onTouchDown?()
        updateValue(with: event)
    }

    override func mouseDragged(with event: NSEvent) {
        guard isDraggingTrack else { return }
        updateValue(with: event)
    }

    override func mouseUp(with event: NSEvent) {
        guard isDraggingTrack else { return }
        isDraggingTrack = false
        updateValue(with: event)
        onTouchUp?()
    }

    private func updateValue(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let ratio: CGFloat
        switch orientation {
        case .horizontal:
            ratio = bounds.width > 0 ? min(max(point.x / bounds.width, 0), 1) : 0
        case .vertical:
            // isFlipped: y=0 is the top, y=bounds.height is the bottom.
            ratio = bounds.height > 0 ? min(max(1 - point.y / bounds.height, 0), 1) : 0
        }
        value = minimumValue + Float(ratio) * (maximumValue - minimumValue)
        onValueChanged?()
    }
}

/// Native playback chrome: play/pause, progress, rate, settings, volume, fullscreen,
/// lock (fullscreen), blackout.
///
/// macOS does not rely on pan gestures (unreliable inside Flutter `AppKitView`, and
/// there is no public brightness API). Seek uses the progress slider; volume uses the
/// toolbar speaker button → vertical popup — same interaction pattern as the gear / 音轨
/// settings button.

/// Circular icon button whose frame equals its Auto Layout alignment rect.
/// Stock `NSButton` insets can still fight frame-based layout if any leftover
/// constraints remain; keep insets zero for predictable hit testing.
private final class SgChromeIconButton: NSButton {
    override var alignmentRectInsets: NSEdgeInsets { NSEdgeInsets() }
}

final class SgPlayerChromeView: NSView, NSGestureRecognizerDelegate {
    weak var delegate: SgPlayerChromeDelegate?

    private static let toolbarIconPointSize: CGFloat = 18
    private static let toolbarButtonSize: CGFloat = 28
    private static let popupAnimationDuration: TimeInterval = 0.2
    private static let centerControlButtonSize: CGFloat = 60
    private static let centerControlIconPointSize: CGFloat = 26
    private static let lockButtonTrailingInset: CGFloat = 50
    private static let seekSettleToleranceMs: Int64 = 800
    private static let seekHoldTimeout: CFTimeInterval = 1.5
    private static let rateOptions: [Double] = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]

    private var config: SgUiConfig
    private let bottomPanel = NSView()
    private let progressRow = NSStackView()
    private let currentTimeLabel = NSTextField(labelWithString: "00:00")
    private let totalTimeLabel = NSTextField(labelWithString: "00:00")
    private let progressSlider = SgTrackSlider()
    private let rateButton = NSButton()
    private let toolbarPlayButton = NSButton()
    private let settingsButton = NSButton()
    private let volumeButton = NSButton()
    private let fullscreenButton = NSButton()
    private let centerPlayButton = SgChromeIconButton()
    private let lockButton = SgChromeIconButton()
    private let blackoutOverlay = NSView()
    private let audioPanel = SgAudioPanelView()
    private let settingsPanel = SgSettingsPanelView()
    private let ratePanel = SgOptionListPanelView()

    private var hideTimer: Timer?
    private var chromeToastView: NSView?
    private var popupAnimationGeneration = 0
    private var controlsVisible = true
    private var audioPanelVisible = false
    private var settingsPanelVisible = false
    private var ratePanelVisible = false
    private var isSeeking = false
    private var isPlaying = false
    private var isFullscreen = false
    private var isScreenLocked = false
    private var durationMs: Int64 = 0
    private var positionMs: Int64 = 0
    private var volumeLevel: Double = 1
    private var muted = false
    private var currentRate: Double = 1
    private var mirrorEnabled = false
    private var loopingEnabled = false
    private var autoPlayNextEnabled = true
    private var aspectMode = 0
    private var hideBlackBars = false
    private var blackoutEnabled = false
    private var pendingSeekTargetMs: Int64?
    private var seekHoldDeadline: CFTimeInterval = 0
    private var seekHoldTimer: Timer?

    override var isFlipped: Bool { true }

    init(config: SgUiConfig) {
        self.config = config
        self.currentRate = Double(config.speed)
        self.loopingEnabled = config.looping
        super.init(frame: .zero)
        KineticPlayerColors.applyAccent(argb: config.accentColor)
        wantsLayer = true
        settingsPanel.applyStrings(config.strings)
        setupViews()
        applyConfig()
        updateRateButtonTitle()
        scheduleAutoHide()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        hideTimer?.invalidate()
        seekHoldTimer?.invalidate()
    }

    override func layout() {
        super.layout()
        layoutCenterControls()
        repositionToolbarPanels()
    }

    /// Frame-based layout — NSButton Auto Layout alignment insets still shift
    /// differently sized (or even equal) circular chrome controls off a shared center.
    private func layoutCenterControls() {
        let size = Self.centerControlButtonSize
        let playX = (bounds.width - size) / 2
        let playY = (bounds.height - size) / 2
        centerPlayButton.frame = NSRect(x: playX, y: playY, width: size, height: size)
        centerPlayButton.layer?.cornerRadius = size / 2

        let lockX = bounds.width - Self.lockButtonTrailingInset - size
        lockButton.frame = NSRect(x: lockX, y: playY, width: size, height: size)
        lockButton.layer?.cornerRadius = size / 2
    }

    private enum ToolbarPanelAlign {
        case center
        case trailing
    }

    /// NSStackView does not expose stable Auto Layout anchors for arranged buttons on macOS.
    private func repositionToolbarPanels() {
        let gap: CGFloat = 6
        let edgeInset: CGFloat = 8
        if audioPanelVisible, !audioPanel.isHidden {
            layoutToolbarPanel(
                audioPanel,
                above: volumeButton,
                width: 44,
                align: .center,
                gap: gap,
                edgeInset: edgeInset,
            )
        }
        if settingsPanelVisible, !settingsPanel.isHidden {
            settingsPanel.invalidateIntrinsicContentSize()
            layoutToolbarPanel(
                settingsPanel,
                above: settingsButton,
                align: .center,
                gap: gap,
                edgeInset: edgeInset,
            )
        }
        if ratePanelVisible, !ratePanel.isHidden {
            layoutToolbarPanel(
                ratePanel,
                above: rateButton,
                width: 120,
                align: .center,
                gap: gap,
                edgeInset: edgeInset,
            )
        }
    }

    private func layoutToolbarPanel(
        _ panel: NSView,
        above anchor: NSView,
        width: CGFloat? = nil,
        align: ToolbarPanelAlign,
        gap: CGFloat,
        edgeInset: CGFloat,
    ) {
        guard anchor.superview != nil, bounds.width > 0 else { return }
        let anchorFrame = anchor.convert(anchor.bounds, to: self)
        panel.layoutSubtreeIfNeeded()
        let resolvedWidth = width ?? max(panel.fittingSize.width, 1)
        let unconstrainedHeight = max(panel.fittingSize.height, 1)
        let maxHeight = max(anchorFrame.minY - gap - edgeInset, 1)
        let height = min(unconstrainedHeight, maxHeight)
        let originX: CGFloat
        switch align {
        case .center:
            originX = anchorFrame.midX - resolvedWidth / 2
        case .trailing:
            originX = anchorFrame.maxX - resolvedWidth
        }
        let clampedX = min(max(originX, edgeInset), max(edgeInset, bounds.width - resolvedWidth - edgeInset))
        let originY = max(edgeInset, anchorFrame.minY - gap - height)
        panel.frame = NSRect(x: clampedX, y: originY, width: resolvedWidth, height: height)
    }

    /// No system brightness API on macOS; kept for call-site parity with iOS.
    func restoreBrightnessIfNeeded() {}

    func updateProgress(positionMs: Int64, durationMs: Int64) {
        self.durationMs = max(0, durationMs)
        totalTimeLabel.stringValue = Self.formatMs(self.durationMs)

        if let pending = pendingSeekTargetMs {
            let arrived = abs(positionMs - pending) <= Self.seekSettleToleranceMs
            let timedOut = CACurrentMediaTime() >= seekHoldDeadline
            if arrived || timedOut {
                clearSeekHold(applyPositionMs: max(0, positionMs))
            }
            return
        }

        if isSeeking {
            return
        }

        self.positionMs = max(0, positionMs)
        applyProgressToChromeUI()
    }

    private func applyProgressToChromeUI() {
        currentTimeLabel.stringValue = Self.formatMs(positionMs)
        progressSlider.value = durationMs > 0 ? Float(positionMs) / Float(durationMs) : 0
    }

    private func beginSeekHold(toMs targetMs: Int64) {
        pendingSeekTargetMs = targetMs
        positionMs = targetMs
        isSeeking = true
        seekHoldDeadline = CACurrentMediaTime() + Self.seekHoldTimeout
        currentTimeLabel.stringValue = Self.formatMs(targetMs)
        if durationMs > 0 {
            progressSlider.value = Float(targetMs) / Float(durationMs)
        }
        seekHoldTimer?.invalidate()
        seekHoldTimer = Timer.scheduledTimer(
            withTimeInterval: Self.seekHoldTimeout,
            repeats: false,
        ) { [weak self] _ in
            guard let self, self.pendingSeekTargetMs != nil else { return }
            self.clearSeekHold(applyPositionMs: self.positionMs)
        }
    }

    private func clearSeekHold(applyPositionMs: Int64) {
        seekHoldTimer?.invalidate()
        seekHoldTimer = nil
        pendingSeekTargetMs = nil
        isSeeking = false
        positionMs = applyPositionMs
        applyProgressToChromeUI()
    }

    func updatePlayState(isPlaying: Bool) {
        self.isPlaying = isPlaying
        updateCenterPlayIcon()
    }

    func syncVolume(volume: Double, muted: Bool) {
        volumeLevel = volume
        self.muted = muted
        audioPanel.syncVolume(volume: volume, muted: muted)
        updateVolumeIcon()
    }

    func setControlsVisible(_ visible: Bool, animated: Bool = true) {
        if isScreenLocked {
            controlsVisible = false
            hideTimer?.invalidate()
            applyLockedChromeVisibility(animated: animated)
            return
        }
        controlsVisible = visible
        let alpha: CGFloat = visible ? 1 : 0
        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.2
                self.bottomPanel.animator().alphaValue = alpha
                self.centerPlayButton.animator().alphaValue = alpha
            }
        } else {
            bottomPanel.alphaValue = alpha
            centerPlayButton.alphaValue = alpha
        }
        setInteractive(bottomPanel, enabled: visible)
        centerPlayButton.isEnabled = visible
        updateLockButtonVisibility()
        if !visible {
            hideAudioPanel(animated: false)
            hideSettingsPanel(animated: false)
            hideRatePanel(animated: false)
        }
        if visible {
            scheduleAutoHide()
        } else {
            hideTimer?.invalidate()
        }
    }

    func toggleControlsVisibility() {
        setControlsVisible(!controlsVisible)
    }

    func updateFullscreenIcon(isFullscreen: Bool) {
        setFullscreenActive(isFullscreen)
    }

    func setFullscreenActive(_ active: Bool) {
        isFullscreen = active
        let symbol = active ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right"
        setToolbarSymbol(fullscreenButton, systemName: symbol)
        if !active, isScreenLocked {
            setScreenLocked(false)
        } else {
            updateLockButtonVisibility()
        }
    }

    private func setInteractive(_ view: NSView, enabled: Bool) {
        if let control = view as? NSControl {
            control.isEnabled = enabled
        }
        if let slider = view as? SgTrackSlider {
            slider.isEnabled = enabled
        }
        for sub in view.subviews {
            setInteractive(sub, enabled: enabled)
        }
    }

    private func bringToFront(_ view: NSView) {
        guard view.superview === self else { return }
        view.removeFromSuperview()
        addSubview(view)
    }

    private func setupViews() {
        blackoutOverlay.wantsLayer = true
        blackoutOverlay.layer?.backgroundColor = NSColor(white: 0, alpha: 0.6).cgColor
        blackoutOverlay.isHidden = true
        blackoutOverlay.translatesAutoresizingMaskIntoConstraints = false
        addSubview(blackoutOverlay)

        bottomPanel.wantsLayer = true
        bottomPanel.layer?.backgroundColor = NSColor(white: 0, alpha: 0.55).cgColor
        bottomPanel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(bottomPanel)

        progressRow.orientation = .horizontal
        progressRow.alignment = .centerY
        progressRow.spacing = 8
        progressRow.translatesAutoresizingMaskIntoConstraints = false

        currentTimeLabel.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        currentTimeLabel.textColor = .white
        currentTimeLabel.setContentHuggingPriority(.required, for: .horizontal)

        totalTimeLabel.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        totalTimeLabel.textColor = .white
        totalTimeLabel.setContentHuggingPriority(.required, for: .horizontal)

        progressSlider.orientation = .horizontal
        progressSlider.minimumValue = 0
        progressSlider.maximumValue = 1
        progressSlider.minimumTrackTintColor = KineticPlayerColors.seekActive
        progressSlider.maximumTrackTintColor = KineticPlayerColors.seekBackground
        progressSlider.translatesAutoresizingMaskIntoConstraints = false
        progressSlider.setContentHuggingPriority(.defaultLow, for: .horizontal)
        progressSlider.onTouchDown = { [weak self] in self?.sliderTouchDown() }
        progressSlider.onValueChanged = { [weak self] in self?.sliderChanged() }
        progressSlider.onTouchUp = { [weak self] in self?.sliderTouchUp() }

        rateButton.isBordered = false
        rateButton.setButtonType(.momentaryChange)
        rateButton.imagePosition = .noImage
        rateButton.contentTintColor = .white
        rateButton.font = .systemFont(ofSize: 12, weight: .semibold)
        rateButton.setContentHuggingPriority(.required, for: .horizontal)
        rateButton.translatesAutoresizingMaskIntoConstraints = false
        rateButton.target = self
        rateButton.action = #selector(rateTapped)
        NSLayoutConstraint.activate([
            rateButton.heightAnchor.constraint(equalToConstant: Self.toolbarButtonSize),
            rateButton.widthAnchor.constraint(greaterThanOrEqualToConstant: Self.toolbarButtonSize),
        ])

        styleToolbarButton(settingsButton)
        setToolbarSymbol(settingsButton, systemName: "gearshape.fill")
        settingsButton.target = self
        settingsButton.action = #selector(settingsTapped)

        styleToolbarButton(volumeButton)
        volumeButton.target = self
        volumeButton.action = #selector(volumeTapped)

        styleToolbarButton(fullscreenButton)
        fullscreenButton.target = self
        fullscreenButton.action = #selector(fullscreenTapped)

        styleToolbarButton(toolbarPlayButton)
        toolbarPlayButton.target = self
        toolbarPlayButton.action = #selector(centerPlayTapped)

        progressRow.addArrangedSubview(toolbarPlayButton)
        progressRow.addArrangedSubview(currentTimeLabel)
        progressRow.addArrangedSubview(progressSlider)
        progressRow.addArrangedSubview(totalTimeLabel)
        progressRow.addArrangedSubview(rateButton)
        progressRow.addArrangedSubview(settingsButton)
        progressRow.addArrangedSubview(volumeButton)
        progressRow.addArrangedSubview(fullscreenButton)

        bottomPanel.addSubview(progressRow)

        audioPanel.translatesAutoresizingMaskIntoConstraints = true
        audioPanel.isHidden = true
        audioPanel.onVolumeChanged = { [weak self] volume in
            guard let self else { return }
            self.volumeLevel = volume
            self.muted = volume <= 0.001
            self.updateVolumeIcon()
            self.delegate?.chromeDidChangeVolume(volume)
            self.scheduleAutoHide()
        }
        addSubview(audioPanel)

        settingsPanel.translatesAutoresizingMaskIntoConstraints = true
        settingsPanel.isHidden = true
        settingsPanel.onSelectTrack = { [weak self] index in
            guard let self else { return }
            self.delegate?.chromeDidSelectAudioTrack(index: index)
            self.reloadSettingsTracks()
            self.scheduleAutoHide()
        }
        settingsPanel.onMirrorChanged = { [weak self] enabled in
            guard let self else { return }
            self.mirrorEnabled = enabled
            self.delegate?.chromeDidChangeMirror(enabled)
        }
        settingsPanel.onLoopingChanged = { [weak self] looping in
            guard let self else { return }
            self.loopingEnabled = looping
            self.delegate?.chromeDidChangeLooping(looping)
        }
        settingsPanel.onAutoPlayNextChanged = { [weak self] enabled in
            guard let self else { return }
            self.autoPlayNextEnabled = enabled
            self.delegate?.chromeDidChangeAutoPlayNext(enabled)
        }
        settingsPanel.onAspectChanged = { [weak self] mode in
            guard let self else { return }
            if mode == 3 {
                self.hideBlackBars = true
            } else {
                self.aspectMode = mode
                self.hideBlackBars = false
            }
            self.delegate?.chromeDidChangeScaleMode(mode)
        }
        settingsPanel.onHideBlackBarsChanged = { [weak self] hide in
            self?.hideBlackBars = hide
        }
        settingsPanel.onBlackoutChanged = { [weak self] enabled in
            guard let self else { return }
            self.setBlackoutEnabled(enabled)
            self.delegate?.chromeDidChangeBlackout(enabled)
        }
        settingsPanel.onScreenshot = { [weak self] in
            self?.captureScreenshotFromSettings()
        }
        addSubview(settingsPanel)

        ratePanel.translatesAutoresizingMaskIntoConstraints = true
        ratePanel.isHidden = true
        ratePanel.onSelect = { [weak self] index in
            guard let self, Self.rateOptions.indices.contains(index) else { return }
            self.setSpeed(Self.rateOptions[index])
            self.hideRatePanel()
        }
        addSubview(ratePanel)

        centerPlayButton.isBordered = false
        centerPlayButton.setButtonType(.momentaryChange)
        centerPlayButton.imagePosition = .imageOnly
        // AppKit's default (.scaleAxesIndependently) stretches SF Symbols to the full
        // hit target — pause.fill becomes fat bars. Keep the square canvas we bake
        // in updateCenterPlayIcon() at its intrinsic size.
        centerPlayButton.imageScaling = .scaleNone
        if let cell = centerPlayButton.cell as? NSButtonCell {
            cell.imageScaling = .scaleNone
        }
        centerPlayButton.contentTintColor = .white
        centerPlayButton.wantsLayer = true
        centerPlayButton.layer?.backgroundColor = NSColor(white: 0, alpha: 0.45).cgColor
        centerPlayButton.layer?.masksToBounds = true
        centerPlayButton.translatesAutoresizingMaskIntoConstraints = true
        centerPlayButton.target = self
        centerPlayButton.action = #selector(centerPlayTapped)
        addSubview(centerPlayButton)

        lockButton.isBordered = false
        lockButton.setButtonType(.momentaryChange)
        lockButton.imagePosition = .imageOnly
        // Same as centerPlayButton: avoid scaleAxesIndependently stretch.
        lockButton.imageScaling = .scaleNone
        if let cell = lockButton.cell as? NSButtonCell {
            cell.imageScaling = .scaleNone
        }
        lockButton.contentTintColor = .white
        lockButton.wantsLayer = true
        lockButton.layer?.backgroundColor = NSColor(white: 0, alpha: 0.45).cgColor
        lockButton.layer?.masksToBounds = true
        lockButton.translatesAutoresizingMaskIntoConstraints = true
        lockButton.isHidden = true
        lockButton.target = self
        lockButton.action = #selector(lockTapped)
        updateLockIcon()
        addSubview(lockButton)

        NSLayoutConstraint.activate([
            blackoutOverlay.leadingAnchor.constraint(equalTo: leadingAnchor),
            blackoutOverlay.trailingAnchor.constraint(equalTo: trailingAnchor),
            blackoutOverlay.topAnchor.constraint(equalTo: topAnchor),
            blackoutOverlay.bottomAnchor.constraint(equalTo: bottomAnchor),

            bottomPanel.leadingAnchor.constraint(equalTo: leadingAnchor),
            bottomPanel.trailingAnchor.constraint(equalTo: trailingAnchor),
            bottomPanel.bottomAnchor.constraint(equalTo: bottomAnchor),

            progressRow.leadingAnchor.constraint(equalTo: bottomPanel.leadingAnchor, constant: 8),
            progressRow.trailingAnchor.constraint(equalTo: bottomPanel.trailingAnchor, constant: -8),
            progressRow.topAnchor.constraint(equalTo: bottomPanel.topAnchor, constant: 4),
            progressRow.bottomAnchor.constraint(equalTo: bottomPanel.bottomAnchor, constant: -4),
            progressRow.heightAnchor.constraint(equalToConstant: 36),
            progressSlider.heightAnchor.constraint(equalToConstant: 20),
        ])

        updateCenterPlayIcon()
        updateFullscreenIcon(isFullscreen: false)
        updateVolumeIcon()

        // Click toggles chrome / dismisses panels. Pan gestures are intentionally
        // omitted on macOS — use progress slider + speaker/gear buttons instead.
        let click = NSClickGestureRecognizer(target: self, action: #selector(handleBackgroundClick))
        click.delegate = self
        addGestureRecognizer(click)
    }

    private func applyConfig() {
        isHidden = !config.enableNativeControls
        bottomPanel.isHidden = !config.enableNativeControls
        centerPlayButton.isHidden = !config.enableNativeControls
        toolbarPlayButton.isHidden = !config.enableNativeControls
        volumeButton.isHidden = !config.showVolumeToolbar
        settingsButton.isHidden = !config.showSettingsButton
        rateButton.isHidden = !config.enableNativeControls
        fullscreenButton.isHidden = !config.showFullscreenButton
        if !config.showVolumeToolbar {
            hideAudioPanel()
        }
        if !config.showSettingsButton {
            hideSettingsPanel()
        }
        setInteractive(bottomPanel, enabled: controlsVisible)
        centerPlayButton.isEnabled = controlsVisible
        updateLockButtonVisibility()
    }

    func applyUiConfig(_ next: SgUiConfig) {
        config = next
        KineticPlayerColors.applyAccent(argb: next.accentColor)
        settingsPanel.applyStrings(next.strings)
        applyConfig()
        reloadRatePanel()
    }

    func applyChromeLocale(locale: String, strings: [String: String]) {
        config.locale = locale
        config.strings = strings
        settingsPanel.applyStrings(strings)
        reloadRatePanel()
    }

    private func chromeString(_ key: String, _ fallback: String) -> String {
        if let value = config.strings[key], !value.isEmpty { return value }
        return fallback
    }

    private func showChromeToast(_ message: String) {
        chromeToastView?.removeFromSuperview()
        let pill = NSView()
        pill.wantsLayer = true
        pill.layer?.backgroundColor = NSColor(white: 0, alpha: 0.72).cgColor
        pill.layer?.cornerRadius = 8
        pill.translatesAutoresizingMaskIntoConstraints = false
        let label = NSTextField(labelWithString: message)
        label.textColor = .white
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.alignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        pill.addSubview(label)
        addSubview(pill)
        chromeToastView = pill
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: pill.topAnchor, constant: 8),
            label.bottomAnchor.constraint(equalTo: pill.bottomAnchor, constant: -8),
            label.leadingAnchor.constraint(equalTo: pill.leadingAnchor, constant: 14),
            label.trailingAnchor.constraint(equalTo: pill.trailingAnchor, constant: -14),
            pill.centerXAnchor.constraint(equalTo: centerXAnchor),
            pill.centerYAnchor.constraint(equalTo: centerYAnchor),
            pill.widthAnchor.constraint(lessThanOrEqualTo: widthAnchor, constant: -32),
        ])
        pill.alphaValue = 0
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            pill.animator().alphaValue = 1
        } completionHandler: {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { [weak self, weak pill] in
                guard self != nil, let pill else { return }
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = 0.2
                    pill.animator().alphaValue = 0
                } completionHandler: {
                    pill.removeFromSuperview()
                }
            }
        }
    }

    private func updateCenterPlayIcon() {
        let symbol = isPlaying ? "pause.fill" : "play.fill"
        guard let image = KineticPlayerSymbols.image(
            systemName: symbol,
            pointSize: Self.centerControlIconPointSize,
            weight: .semibold,
        ) else {
            centerPlayButton.image = nil
            return
        }
        // Always bake into a square canvas so NSButton never stretches non-square
        // SF Symbol bounds (pause.fill is especially prone to this). play.fill gets
        // a small +x nudge for optical centering inside the circle.
        let xOffset: CGFloat = isPlaying ? 0 : 2
        centerPlayButton.image = Self.squareCenteredSymbolImage(
            image,
            pointSize: Self.centerControlIconPointSize,
            xOffset: xOffset,
        )
        setToolbarSymbol(toolbarPlayButton, systemName: symbol)
    }

    /// Draws an SF Symbol into a fixed square canvas, preserving aspect ratio.
    private static func squareCenteredSymbolImage(
        _ symbol: NSImage,
        pointSize: CGFloat,
        xOffset: CGFloat = 0,
    ) -> NSImage {
        let canvasSide = pointSize + 4
        let size = NSSize(width: canvasSide, height: canvasSide)
        let canvas = NSImage(size: size, flipped: false) { bounds in
            let drawSize = symbol.size
            guard drawSize.width > 0, drawSize.height > 0 else { return false }
            let origin = NSPoint(
                x: (bounds.width - drawSize.width) / 2 + xOffset,
                y: (bounds.height - drawSize.height) / 2,
            )
            symbol.draw(
                in: NSRect(origin: origin, size: drawSize),
                from: .zero,
                operation: .sourceOver,
                fraction: 1,
            )
            return true
        }
        canvas.isTemplate = true
        return canvas
    }

    private func updateVolumeIcon() {
        let symbolName = muted || volumeLevel <= 0.001 ? "speaker.slash.fill" : "speaker.wave.2.fill"
        setToolbarSymbol(volumeButton, systemName: symbolName)
    }

    private func updateLockIcon() {
        let symbol = isScreenLocked ? "lock.fill" : "lock.open.fill"
        guard let image = KineticPlayerSymbols.image(
            systemName: symbol,
            pointSize: Self.centerControlIconPointSize,
            weight: .semibold,
        ) else {
            lockButton.image = nil
            return
        }
        lockButton.image = Self.squareCenteredSymbolImage(
            image,
            pointSize: Self.centerControlIconPointSize,
        )
    }

    private func updateLockButtonVisibility() {
        let show = config.enableNativeControls
            && config.showLockButton
            && isFullscreen
            && (controlsVisible || isScreenLocked)
        lockButton.isHidden = !show
        lockButton.isEnabled = show
        if show {
            bringToFront(lockButton)
        }
    }

    private func applyLockedChromeVisibility(animated: Bool) {
        let updates = {
            self.bottomPanel.alphaValue = 0
            self.centerPlayButton.alphaValue = 0
            self.setInteractive(self.bottomPanel, enabled: false)
            self.centerPlayButton.isEnabled = false
            self.hideAudioPanel(animated: false)
            self.hideSettingsPanel(animated: false)
            self.hideRatePanel(animated: false)
            self.updateLockButtonVisibility()
        }
        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.2
                updates()
            }
        } else {
            updates()
        }
    }

    private func setScreenLocked(_ locked: Bool) {
        isScreenLocked = locked
        updateLockIcon()
        if locked {
            setControlsVisible(false, animated: true)
        } else {
            setControlsVisible(true, animated: true)
        }
    }

    private func setBlackoutEnabled(_ enabled: Bool) {
        blackoutEnabled = enabled
        blackoutOverlay.isHidden = !enabled
        if enabled {
            // Keep overlay behind chrome controls.
            blackoutOverlay.removeFromSuperview()
            addSubview(blackoutOverlay, positioned: .below, relativeTo: bottomPanel)
        }
    }

    private func setSpeed(_ rate: Double) {
        currentRate = rate
        updateRateButtonTitle()
        reloadRatePanel()
        delegate?.chromeDidChangeRate(rate)
    }

    private func updateRateButtonTitle() {
        let title = Self.formatRateLabel(currentRate)
        rateButton.attributedTitle = NSAttributedString(
            string: title,
            attributes: [
                .foregroundColor: NSColor.white,
                .font: NSFont.systemFont(ofSize: 12, weight: .semibold),
            ],
        )
    }

    private func reloadRatePanel() {
        let options = Self.rateOptions.map { rate in
            (label: Self.formatRateLabel(rate), selected: abs(rate - currentRate) < 0.001)
        }
        ratePanel.reload(title: chromeString("kinetic_rate_title", "倍速"), options: options)
    }

    private static func formatRateLabel(_ rate: Double) -> String {
        if rate == Double(Int(rate)) {
            return String(format: "%.1fx", rate)
        }
        return String(format: "%gx", rate)
    }

    private func styleToolbarButton(_ button: NSButton) {
        button.isBordered = false
        button.setButtonType(.momentaryChange)
        button.imagePosition = .imageOnly
        button.contentTintColor = .white
        button.setContentHuggingPriority(.required, for: .horizontal)
        button.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: Self.toolbarButtonSize),
            button.heightAnchor.constraint(equalToConstant: Self.toolbarButtonSize),
        ])
    }

    private func setToolbarSymbol(_ button: NSButton, systemName: String) {
        let image = KineticPlayerSymbols.image(
            systemName: systemName,
            pointSize: Self.toolbarIconPointSize,
        )
        image?.isTemplate = true
        button.image = image
    }

    private func toggleAudioPanel() {
        if audioPanelVisible {
            hideAudioPanel()
        } else {
            hideSettingsPanel(animated: false)
            hideRatePanel(animated: false)
            showAudioPanel()
        }
    }

    private func toggleSettingsPanel() {
        if settingsPanelVisible {
            hideSettingsPanel()
        } else {
            hideAudioPanel(animated: false)
            hideRatePanel(animated: false)
            showSettingsPanel()
        }
    }

    private func toggleRatePanel() {
        if ratePanelVisible {
            hideRatePanel()
        } else {
            hideAudioPanel(animated: false)
            hideSettingsPanel(animated: false)
            showRatePanel()
        }
    }

    private func setPopupVisible(
        _ panel: NSView,
        visible: Bool,
        animated: Bool = true,
        afterShow: (() -> Void)? = nil,
    ) {
        popupAnimationGeneration += 1
        let generation = popupAnimationGeneration
        panel.layer?.removeAllAnimations()
        if visible {
            panel.isHidden = false
            bringToFront(panel)
            afterShow?()
            hideTimer?.invalidate()
            if animated {
                panel.alphaValue = 0
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = Self.popupAnimationDuration
                    panel.animator().alphaValue = 1
                }
            } else {
                panel.alphaValue = 1
            }
        } else {
            let finish = {
                panel.isHidden = true
                panel.alphaValue = 1
            }
            if !animated || panel.isHidden {
                finish()
                scheduleAutoHide()
                return
            }
            NSAnimationContext.runAnimationGroup { context in
                context.duration = Self.popupAnimationDuration
                panel.animator().alphaValue = 0
            } completionHandler: {
                guard generation == self.popupAnimationGeneration else { return }
                finish()
                self.scheduleAutoHide()
            }
        }
    }

    private func showAudioPanel() {
        audioPanelVisible = true
        setPopupVisible(audioPanel, visible: true) {
            self.needsLayout = true
            self.layoutSubtreeIfNeeded()
        }
    }

    private func hideAudioPanel(animated: Bool = true) {
        audioPanelVisible = false
        setPopupVisible(audioPanel, visible: false, animated: animated)
    }

    private func showSettingsPanel() {
        settingsPanel.syncState(
            mirror: mirrorEnabled,
            looping: loopingEnabled,
            autoPlay: true,
            autoPlayNext: autoPlayNextEnabled,
            aspect: aspectMode,
            hideBlackBars: hideBlackBars,
            blackout: blackoutEnabled,
        )
        settingsPanel.showLevel1()
        reloadSettingsTracks()
        settingsPanelVisible = true
        setPopupVisible(settingsPanel, visible: true) {
            self.needsLayout = true
            self.layoutSubtreeIfNeeded()
        }
    }

    private func hideSettingsPanel(animated: Bool = true) {
        settingsPanelVisible = false
        setPopupVisible(settingsPanel, visible: false, animated: animated)
    }

    private func captureScreenshotFromSettings() {
        hideSettingsPanel()
        delegate?.chromeDidRequestScreenshot()
    }

    private func showRatePanel() {
        reloadRatePanel()
        ratePanelVisible = true
        setPopupVisible(ratePanel, visible: true) {
            self.needsLayout = true
            self.layoutSubtreeIfNeeded()
        }
    }

    private func hideRatePanel(animated: Bool = true) {
        ratePanelVisible = false
        setPopupVisible(ratePanel, visible: false, animated: animated)
    }

    private func reloadSettingsTracks() {
        let tracks = delegate?.chromeDidRequestAudioTracks() ?? []
        settingsPanel.reloadTracks(tracks)
    }

    private func scheduleAutoHide() {
        hideTimer?.invalidate()
        guard config.enableNativeControls,
              isPlaying,
              !isScreenLocked,
              !audioPanelVisible,
              !settingsPanelVisible,
              !ratePanelVisible else { return }
        hideTimer = Timer.scheduledTimer(
            withTimeInterval: TimeInterval(config.dismissControlTimeMs) / 1000.0,
            repeats: false,
        ) { [weak self] _ in
            self?.setControlsVisible(false)
        }
    }

    @objc private func handleBackgroundClick() {
        if isScreenLocked {
            return
        }
        if audioPanelVisible {
            hideAudioPanel()
            return
        }
        if settingsPanelVisible {
            hideSettingsPanel()
            return
        }
        if ratePanelVisible {
            hideRatePanel()
            return
        }
        toggleControlsVisibility()
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: NSGestureRecognizer) -> Bool {
        let point = gestureRecognizer.location(in: self)
        if isScreenLocked {
            return !lockButton.frame.contains(point)
        }
        if audioPanelVisible, audioPanel.frame.contains(point) {
            return false
        }
        if settingsPanelVisible, settingsPanel.frame.contains(point) {
            return false
        }
        if ratePanelVisible, ratePanel.frame.contains(point) {
            return false
        }
        if !lockButton.isHidden, lockButton.frame.contains(point) {
            return false
        }
        if bottomPanel.frame.contains(point), bottomPanel.alphaValue > 0.01, controlsVisible {
            return false
        }
        if controlsVisible {
            if centerPlayButton.frame.contains(point) {
                return false
            }
            if touchHitsInteractiveControl(at: point) {
                return false
            }
        }
        return true
    }

    func gestureRecognizer(
        _ gestureRecognizer: NSGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: NSGestureRecognizer,
    ) -> Bool {
        false
    }

    private func touchHitsInteractiveControl(at point: NSPoint) -> Bool {
        for control in [
            toolbarPlayButton,
            progressSlider,
            rateButton,
            settingsButton,
            volumeButton,
            fullscreenButton,
        ] as [NSView] {
            let frame = control.convert(control.bounds, to: self)
            if frame.contains(point) {
                return true
            }
        }
        return false
    }

    @objc private func centerPlayTapped() {
        delegate?.chromeDidTapPlayPause()
        scheduleAutoHide()
    }

    @objc private func fullscreenTapped() {
        delegate?.chromeDidTapFullscreen()
        scheduleAutoHide()
    }

    @objc private func settingsTapped() {
        toggleSettingsPanel()
    }

    @objc private func volumeTapped() {
        toggleAudioPanel()
    }

    @objc private func rateTapped() {
        toggleRatePanel()
    }

    @objc private func lockTapped() {
        setScreenLocked(!isScreenLocked)
    }

    private func sliderTouchDown() {
        isSeeking = true
        hideTimer?.invalidate()
    }

    private func sliderChanged() {
        guard durationMs > 0 else { return }
        let position = Int64(progressSlider.value * Float(durationMs))
        currentTimeLabel.stringValue = Self.formatMs(position)
    }

    private func sliderTouchUp() {
        guard durationMs > 0 else {
            clearSeekHold(applyPositionMs: positionMs)
            return
        }
        let target = max(0, Int64(progressSlider.value * Float(durationMs)))
        beginSeekHold(toMs: target)
        delegate?.chromeDidSeek(toMs: Int(target))
        scheduleAutoHide()
    }

    private static func formatMs(_ ms: Int64) -> String {
        let totalSeconds = max(0, ms / 1000)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
#endif

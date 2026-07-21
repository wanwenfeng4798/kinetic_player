protocol SgPlayerChromeDelegate: AnyObject {
    func chromeDidTapPlayPause()
    func chromeDidSeek(toMs: Int)
    func chromeDidTapFullscreen()
    func chromeDidChangeVolume(_ volume: Double)
    func chromeDidToggleMute(_ muted: Bool)
    func chromeDidRequestAudioTracks() -> [[String: Any]]
    func chromeDidSelectAudioTrack(index: Int)
}

#if os(iOS)
import UIKit

/// Native playback chrome: play/pause, progress, settings (音轨), volume, fullscreen,
/// plus GSY-style pan gestures (seek / volume / brightness).
final class SgPlayerChromeView: UIView, UIGestureRecognizerDelegate {
    private enum PanGestureKind {
        case none
        case seek
        case volume
        case brightness
    }

    weak var delegate: SgPlayerChromeDelegate?

    /// Matches Android `kinetic_control_icon_size` (14dp) / GSY stock chrome.
    private static let toolbarIconPointSize: CGFloat = 14
    private static let toolbarButtonSize: CGFloat = 28
    private static let panActivationThreshold: CGFloat = 12
    /// Hold scrub UI until playhead catches the committed seek (avoids bounce).
    private static let seekSettleToleranceMs: Int64 = 800
    private static let seekHoldTimeout: CFTimeInterval = 1.5
    private static let toolbarSymbolConfig = UIImage.SymbolConfiguration(
        pointSize: toolbarIconPointSize,
        weight: .regular,
    )

    private let config: SgUiConfig
    private let bottomPanel = UIView()
    private let progressRow = UIStackView()
    private let currentTimeLabel = UILabel()
    private let totalTimeLabel = UILabel()
    private let progressSlider = UISlider()
    private let settingsButton = UIButton(type: .system)
    private let volumeButton = UIButton(type: .system)
    private let fullscreenButton = UIButton(type: .system)
    private let centerPlayButton = UIButton(type: .system)
    private let audioPanel = SgAudioPanelView()
    private let settingsPanel = SgSettingsPanelView()
    private let gestureOverlay = SgGestureOverlayView()

    private var hideTimer: Timer?
    private var controlsVisible = true
    private var audioPanelVisible = false
    private var settingsPanelVisible = false
    private var isSeeking = false
    private var isPlaying = false
    private var durationMs: Int64 = 0
    private var positionMs: Int64 = 0
    private var volumeLevel: Double = 1
    private var muted = false
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
        super.init(frame: .zero)
        clipsToBounds = false
        isUserInteractionEnabled = true
        setupViews()
        applyConfig()
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
        controlsVisible = visible
        let alpha: CGFloat = visible ? 1 : 0
        let updates = {
            self.bottomPanel.alpha = alpha
            self.centerPlayButton.alpha = alpha
            self.bottomPanel.isUserInteractionEnabled = visible
            self.centerPlayButton.isUserInteractionEnabled = visible
            if !visible {
                self.hideAudioPanel()
                self.hideSettingsPanel()
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
        let symbol = isFullscreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right"
        setToolbarSymbol(fullscreenButton, systemName: symbol)
    }

    private func setupViews() {
        backgroundColor = .clear

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

        settingsButton.addTarget(self, action: #selector(settingsTapped), for: .touchUpInside)
        styleToolbarButton(settingsButton)
        setToolbarSymbol(settingsButton, systemName: "gearshape.fill")

        volumeButton.addTarget(self, action: #selector(volumeTapped), for: .touchUpInside)
        styleToolbarButton(volumeButton)

        fullscreenButton.addTarget(self, action: #selector(fullscreenTapped), for: .touchUpInside)
        styleToolbarButton(fullscreenButton)

        progressRow.addArrangedSubview(currentTimeLabel)
        progressRow.addArrangedSubview(progressSlider)
        progressRow.addArrangedSubview(totalTimeLabel)
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
        settingsPanel.isHidden = true
        settingsPanel.isUserInteractionEnabled = false
        settingsPanel.onSelectTrack = { [weak self] index in
            guard let self else { return }
            self.delegate?.chromeDidSelectAudioTrack(index: index)
            self.reloadSettingsTracks()
            self.scheduleAutoHide()
        }
        addSubview(settingsPanel)

        centerPlayButton.tintColor = .white
        centerPlayButton.backgroundColor = UIColor(white: 0, alpha: 0.45)
        centerPlayButton.layer.cornerRadius = 30
        centerPlayButton.translatesAutoresizingMaskIntoConstraints = false
        centerPlayButton.addTarget(self, action: #selector(centerPlayTapped), for: .touchUpInside)
        addSubview(centerPlayButton)

        addSubview(gestureOverlay)

        NSLayoutConstraint.activate([
            bottomPanel.leadingAnchor.constraint(equalTo: leadingAnchor),
            bottomPanel.trailingAnchor.constraint(equalTo: trailingAnchor),
            bottomPanel.bottomAnchor.constraint(equalTo: bottomAnchor),

            progressRow.leadingAnchor.constraint(equalTo: bottomPanel.leadingAnchor, constant: 8),
            progressRow.trailingAnchor.constraint(equalTo: bottomPanel.trailingAnchor, constant: -8),
            progressRow.topAnchor.constraint(equalTo: bottomPanel.topAnchor, constant: 4),
            progressRow.bottomAnchor.constraint(equalTo: bottomPanel.bottomAnchor, constant: -4),
            progressRow.heightAnchor.constraint(equalToConstant: 36),

            audioPanel.centerXAnchor.constraint(equalTo: volumeButton.centerXAnchor),
            audioPanel.bottomAnchor.constraint(equalTo: bottomPanel.topAnchor, constant: -6),

            settingsPanel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            settingsPanel.bottomAnchor.constraint(equalTo: bottomPanel.topAnchor, constant: -6),

            centerPlayButton.centerXAnchor.constraint(equalTo: centerXAnchor),
            centerPlayButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            centerPlayButton.widthAnchor.constraint(equalToConstant: 60),
            centerPlayButton.heightAnchor.constraint(equalToConstant: 60),

            gestureOverlay.centerXAnchor.constraint(equalTo: centerXAnchor),
            gestureOverlay.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])

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
        volumeButton.isHidden = !config.showVolumeToolbar
        settingsButton.isHidden = !config.showSettingsButton
        fullscreenButton.isHidden = !config.showFullscreenButton
        if !config.showVolumeToolbar {
            hideAudioPanel()
        }
        if !config.showSettingsButton {
            hideSettingsPanel()
        }
        bottomPanel.isUserInteractionEnabled = controlsVisible
        centerPlayButton.isUserInteractionEnabled = controlsVisible
    }

    private func updateCenterPlayIcon() {
        let symbol = isPlaying ? "pause.fill" : "play.fill"
        centerPlayButton.setImage(UIImage(systemName: symbol), for: .normal)
    }

    private func updateVolumeIcon() {
        let symbolName = muted || volumeLevel <= 0.001 ? "speaker.slash.fill" : "speaker.wave.2.fill"
        setToolbarSymbol(volumeButton, systemName: symbolName)
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
            hideSettingsPanel()
            showAudioPanel()
        }
    }

    private func toggleSettingsPanel() {
        if settingsPanelVisible {
            hideSettingsPanel()
        } else {
            hideAudioPanel()
            showSettingsPanel()
        }
    }

    private func showAudioPanel() {
        audioPanel.isHidden = false
        audioPanel.isUserInteractionEnabled = true
        audioPanelVisible = true
        bringSubviewToFront(audioPanel)
        hideTimer?.invalidate()
    }

    private func hideAudioPanel() {
        audioPanel.isHidden = true
        audioPanel.isUserInteractionEnabled = false
        audioPanelVisible = false
        scheduleAutoHide()
    }

    private func showSettingsPanel() {
        reloadSettingsTracks()
        settingsPanel.isHidden = false
        settingsPanel.isUserInteractionEnabled = true
        settingsPanelVisible = true
        bringSubviewToFront(settingsPanel)
        hideTimer?.invalidate()
    }

    private func hideSettingsPanel() {
        settingsPanel.isHidden = true
        settingsPanel.isUserInteractionEnabled = false
        settingsPanelVisible = false
        scheduleAutoHide()
    }

    private func reloadSettingsTracks() {
        let tracks = delegate?.chromeDidRequestAudioTracks() ?? []
        settingsPanel.reloadTracks(tracks)
    }

    private func scheduleAutoHide() {
        hideTimer?.invalidate()
        guard config.enableNativeControls, isPlaying, !audioPanelVisible, !settingsPanelVisible else { return }
        hideTimer = Timer.scheduledTimer(
            withTimeInterval: TimeInterval(config.dismissControlTimeMs) / 1000.0,
            repeats: false,
        ) { [weak self] _ in
            self?.setControlsVisible(false)
        }
    }

    @objc private func handleBackgroundTap() {
        if audioPanelVisible {
            hideAudioPanel()
            return
        }
        if settingsPanelVisible {
            hideSettingsPanel()
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
        guard config.enableNativeControls else { return }

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
        if audioPanelVisible, audioPanel.frame.contains(point) {
            return false
        }
        if settingsPanelVisible, settingsPanel.frame.contains(point) {
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
            progressSlider,
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

/// Native playback chrome: play/pause, progress, settings (音轨), volume, fullscreen,
/// plus GSY-style pan gestures (seek / volume). There is no public brightness API on
/// macOS, so the left-side brightness swipe from the iOS chrome is intentionally skipped.
final class SgPlayerChromeView: NSView, NSGestureRecognizerDelegate {
    private enum PanGestureKind {
        case none
        case seek
        case volume
    }

    weak var delegate: SgPlayerChromeDelegate?

    private static let toolbarIconPointSize: CGFloat = 14
    private static let toolbarButtonSize: CGFloat = 28
    private static let panActivationThreshold: CGFloat = 12
    private static let seekSettleToleranceMs: Int64 = 800
    private static let seekHoldTimeout: CFTimeInterval = 1.5

    private let config: SgUiConfig
    private let bottomPanel = NSView()
    private let progressRow = NSStackView()
    private let currentTimeLabel = NSTextField(labelWithString: "00:00")
    private let totalTimeLabel = NSTextField(labelWithString: "00:00")
    private let progressSlider = SgTrackSlider()
    private let settingsButton = NSButton()
    private let volumeButton = NSButton()
    private let fullscreenButton = NSButton()
    private let centerPlayButton = NSButton()
    private let audioPanel = SgAudioPanelView()
    private let settingsPanel = SgSettingsPanelView()
    private let gestureOverlay = SgGestureOverlayView()

    private var hideTimer: Timer?
    private var controlsVisible = true
    private var audioPanelVisible = false
    private var settingsPanelVisible = false
    private var isSeeking = false
    private var isPlaying = false
    private var durationMs: Int64 = 0
    private var positionMs: Int64 = 0
    private var volumeLevel: Double = 1
    private var muted = false
    private var pendingSeekTargetMs: Int64?
    private var seekHoldDeadline: CFTimeInterval = 0
    private var seekHoldTimer: Timer?

    private var panKind: PanGestureKind = .none
    private var panStartVolume: Double = 1
    private var panStartPositionMs: Int64 = 0
    private var panPreviewPositionMs: Int64 = 0
    private var volumeSliderDragging = false

    override var isFlipped: Bool { true }

    init(config: SgUiConfig) {
        self.config = config
        super.init(frame: .zero)
        wantsLayer = true
        setupViews()
        applyConfig()
        scheduleAutoHide()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        hideTimer?.invalidate()
        seekHoldTimer?.invalidate()
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

        if isSeeking || panKind == .seek {
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
        if !visible {
            hideAudioPanel()
            hideSettingsPanel()
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
        let symbol = isFullscreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right"
        setToolbarSymbol(fullscreenButton, systemName: symbol)
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

        progressRow.addArrangedSubview(currentTimeLabel)
        progressRow.addArrangedSubview(progressSlider)
        progressRow.addArrangedSubview(totalTimeLabel)
        progressRow.addArrangedSubview(settingsButton)
        progressRow.addArrangedSubview(volumeButton)
        progressRow.addArrangedSubview(fullscreenButton)

        bottomPanel.addSubview(progressRow)

        audioPanel.translatesAutoresizingMaskIntoConstraints = false
        audioPanel.isHidden = true
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
        settingsPanel.isHidden = true
        settingsPanel.onSelectTrack = { [weak self] index in
            guard let self else { return }
            self.delegate?.chromeDidSelectAudioTrack(index: index)
            self.reloadSettingsTracks()
            self.scheduleAutoHide()
        }
        addSubview(settingsPanel)

        centerPlayButton.isBordered = false
        centerPlayButton.setButtonType(.momentaryChange)
        centerPlayButton.imagePosition = .imageOnly
        centerPlayButton.contentTintColor = .white
        centerPlayButton.wantsLayer = true
        centerPlayButton.layer?.backgroundColor = NSColor(white: 0, alpha: 0.45).cgColor
        centerPlayButton.layer?.cornerRadius = 30
        centerPlayButton.layer?.masksToBounds = true
        centerPlayButton.translatesAutoresizingMaskIntoConstraints = false
        centerPlayButton.target = self
        centerPlayButton.action = #selector(centerPlayTapped)
        addSubview(centerPlayButton)

        addSubview(gestureOverlay)

        NSLayoutConstraint.activate([
            bottomPanel.leadingAnchor.constraint(equalTo: leadingAnchor),
            bottomPanel.trailingAnchor.constraint(equalTo: trailingAnchor),
            bottomPanel.bottomAnchor.constraint(equalTo: bottomAnchor),

            progressRow.leadingAnchor.constraint(equalTo: bottomPanel.leadingAnchor, constant: 8),
            progressRow.trailingAnchor.constraint(equalTo: bottomPanel.trailingAnchor, constant: -8),
            progressRow.topAnchor.constraint(equalTo: bottomPanel.topAnchor, constant: 4),
            progressRow.bottomAnchor.constraint(equalTo: bottomPanel.bottomAnchor, constant: -4),
            progressRow.heightAnchor.constraint(equalToConstant: 36),
            progressSlider.heightAnchor.constraint(equalToConstant: 20),

            audioPanel.centerXAnchor.constraint(equalTo: volumeButton.centerXAnchor),
            audioPanel.bottomAnchor.constraint(equalTo: bottomPanel.topAnchor, constant: -6),

            settingsPanel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            settingsPanel.bottomAnchor.constraint(equalTo: bottomPanel.topAnchor, constant: -6),

            centerPlayButton.centerXAnchor.constraint(equalTo: centerXAnchor),
            centerPlayButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            centerPlayButton.widthAnchor.constraint(equalToConstant: 60),
            centerPlayButton.heightAnchor.constraint(equalToConstant: 60),

            gestureOverlay.centerXAnchor.constraint(equalTo: centerXAnchor),
            gestureOverlay.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])

        updateCenterPlayIcon()
        updateFullscreenIcon(isFullscreen: false)
        updateVolumeIcon()

        let click = NSClickGestureRecognizer(target: self, action: #selector(handleBackgroundClick))
        click.delegate = self
        addGestureRecognizer(click)

        if config.enableNativeControls {
            let pan = NSPanGestureRecognizer(target: self, action: #selector(handlePanGesture(_:)))
            pan.delegate = self
            addGestureRecognizer(pan)
        }
    }

    private func applyConfig() {
        isHidden = !config.enableNativeControls
        bottomPanel.isHidden = !config.enableNativeControls
        centerPlayButton.isHidden = !config.enableNativeControls
        volumeButton.isHidden = !config.showVolumeToolbar
        settingsButton.isHidden = !config.showSettingsButton
        fullscreenButton.isHidden = !config.showFullscreenButton
        if !config.showVolumeToolbar {
            hideAudioPanel()
        }
        if !config.showSettingsButton {
            hideSettingsPanel()
        }
        setInteractive(bottomPanel, enabled: controlsVisible)
        centerPlayButton.isEnabled = controlsVisible
    }

    private func updateCenterPlayIcon() {
        let symbol = isPlaying ? "pause.fill" : "play.fill"
        let symbolConfig = NSImage.SymbolConfiguration(pointSize: 22, weight: .medium)
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)?
            .withSymbolConfiguration(symbolConfig)
        image?.isTemplate = true
        centerPlayButton.image = image
    }

    private func updateVolumeIcon() {
        let symbolName = muted || volumeLevel <= 0.001 ? "speaker.slash.fill" : "speaker.wave.2.fill"
        setToolbarSymbol(volumeButton, systemName: symbolName)
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
        let symbolConfig = NSImage.SymbolConfiguration(pointSize: Self.toolbarIconPointSize, weight: .regular)
        let image = NSImage(systemSymbolName: systemName, accessibilityDescription: nil)?
            .withSymbolConfiguration(symbolConfig)
        image?.isTemplate = true
        button.image = image
    }

    private func toggleAudioPanel() {
        if audioPanelVisible {
            hideAudioPanel()
        } else {
            hideSettingsPanel()
            showAudioPanel()
        }
    }

    private func toggleSettingsPanel() {
        if settingsPanelVisible {
            hideSettingsPanel()
        } else {
            hideAudioPanel()
            showSettingsPanel()
        }
    }

    private func showAudioPanel() {
        audioPanel.isHidden = false
        audioPanelVisible = true
        bringToFront(audioPanel)
        hideTimer?.invalidate()
    }

    private func hideAudioPanel() {
        audioPanel.isHidden = true
        audioPanelVisible = false
        scheduleAutoHide()
    }

    private func showSettingsPanel() {
        reloadSettingsTracks()
        settingsPanel.isHidden = false
        settingsPanelVisible = true
        bringToFront(settingsPanel)
        hideTimer?.invalidate()
    }

    private func hideSettingsPanel() {
        settingsPanel.isHidden = true
        settingsPanelVisible = false
        scheduleAutoHide()
    }

    private func reloadSettingsTracks() {
        let tracks = delegate?.chromeDidRequestAudioTracks() ?? []
        settingsPanel.reloadTracks(tracks)
    }

    private func scheduleAutoHide() {
        hideTimer?.invalidate()
        guard config.enableNativeControls, isPlaying, !audioPanelVisible, !settingsPanelVisible else { return }
        hideTimer = Timer.scheduledTimer(
            withTimeInterval: TimeInterval(config.dismissControlTimeMs) / 1000.0,
            repeats: false,
        ) { [weak self] _ in
            self?.setControlsVisible(false)
        }
    }

    @objc private func handleBackgroundClick() {
        if audioPanelVisible {
            hideAudioPanel()
            return
        }
        if settingsPanelVisible {
            hideSettingsPanel()
            return
        }
        toggleControlsVisibility()
    }

    // MARK: - Pan gestures (seek / volume)

    /// Same rule as Android `shouldBlockGestureVolume`: popup open or slider drag wins.
    private var shouldBlockGestureVolume: Bool {
        audioPanelVisible || volumeSliderDragging
    }

    @objc private func handlePanGesture(_ gesture: NSPanGestureRecognizer) {
        guard config.enableNativeControls else { return }

        switch gesture.state {
        case .began:
            hideTimer?.invalidate()
            panKind = .none
            panStartVolume = volumeLevel
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
                } else if shouldBlockGestureVolume {
                    // Volume popup / slider owns volume control — ignore vertical swipe.
                    return
                } else {
                    panKind = .volume
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
            let deltaMs = Int64((translation.x / width) * Double(durationMs))
            let target = max(0, min(durationMs, panStartPositionMs + deltaMs))
            panPreviewPositionMs = target
            progressSlider.value = Float(target) / Float(durationMs)
            currentTimeLabel.stringValue = Self.formatMs(target)
            let total = Self.formatMs(durationMs)
            gestureOverlay.show(
                symbolName: translation.x >= 0 ? "forward.fill" : "backward.fill",
                text: "\(Self.formatMs(target)) / \(total)",
            )
            bringToFront(gestureOverlay)

        case .volume:
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
            bringToFront(gestureOverlay)

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
        case .volume, .none:
            break
        }
        scheduleAutoHide()
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: NSGestureRecognizer) -> Bool {
        let point = gestureRecognizer.location(in: self)
        if audioPanelVisible, audioPanel.frame.contains(point) {
            return false
        }
        if settingsPanelVisible, settingsPanel.frame.contains(point) {
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
            progressSlider,
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

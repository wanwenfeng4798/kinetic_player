import UIKit

protocol SgPlayerChromeDelegate: AnyObject {
    func chromeDidTapPlayPause()
    func chromeDidSeek(toMs: Int)
    func chromeDidTapFullscreen()
    func chromeDidChangeVolume(_ volume: Double)
    func chromeDidToggleMute(_ muted: Bool)
}

/// Native playback chrome: center play/pause, progress bar, fullscreen, volume toolbar.
final class SgPlayerChromeView: UIView, UIGestureRecognizerDelegate {
    weak var delegate: SgPlayerChromeDelegate?

    private let config: SgUiConfig
    private let bottomPanel = UIView()
    private let progressRow = UIStackView()
    private let currentTimeLabel = UILabel()
    private let totalTimeLabel = UILabel()
    private let progressSlider = UISlider()
    private let fullscreenButton = UIButton(type: .system)
    private let centerPlayButton = UIButton(type: .system)
    private let volumeToolbar = SgVolumeToolbarView()

    private var hideTimer: Timer?
    private var controlsVisible = true
    private var isSeeking = false
    private var isPlaying = false
    private var durationMs: Int64 = 0

    init(config: SgUiConfig) {
        self.config = config
        super.init(frame: .zero)
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
    }

    func updateProgress(positionMs: Int64, durationMs: Int64) {
        self.durationMs = max(0, durationMs)
        if !isSeeking {
            currentTimeLabel.text = Self.formatMs(positionMs)
            totalTimeLabel.text = Self.formatMs(durationMs)
            if durationMs > 0 {
                progressSlider.value = Float(positionMs) / Float(durationMs)
            } else {
                progressSlider.value = 0
            }
        }
    }

    func updatePlayState(isPlaying: Bool) {
        self.isPlaying = isPlaying
        updateCenterPlayIcon()
    }

    func syncVolume(volume: Double, muted: Bool) {
        volumeToolbar.sync(volume: volume, muted: muted)
    }

    func setControlsVisible(_ visible: Bool, animated: Bool = true) {
        controlsVisible = visible
        let alpha: CGFloat = visible ? 1 : 0
        let updates = {
            self.bottomPanel.alpha = alpha
            self.centerPlayButton.alpha = alpha
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
        fullscreenButton.setImage(UIImage(systemName: symbol), for: .normal)
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
        progressSlider.minimumTrackTintColor = UIColor(red: 0.30, green: 0.91, blue: 0.71, alpha: 1)
        progressSlider.maximumTrackTintColor = UIColor(white: 1, alpha: 0.35)
        progressSlider.addTarget(self, action: #selector(sliderTouchDown), for: .touchDown)
        progressSlider.addTarget(self, action: #selector(sliderChanged), for: .valueChanged)
        progressSlider.addTarget(self, action: #selector(sliderTouchUp), for: [.touchUpInside, .touchUpOutside, .touchCancel])

        fullscreenButton.tintColor = .white
        fullscreenButton.addTarget(self, action: #selector(fullscreenTapped), for: .touchUpInside)
        fullscreenButton.setContentHuggingPriority(.required, for: .horizontal)

        progressRow.addArrangedSubview(currentTimeLabel)
        progressRow.addArrangedSubview(progressSlider)
        progressRow.addArrangedSubview(totalTimeLabel)
        progressRow.addArrangedSubview(fullscreenButton)

        volumeToolbar.translatesAutoresizingMaskIntoConstraints = false
        volumeToolbar.onVolumeChanged = { [weak self] volume in
            self?.delegate?.chromeDidChangeVolume(volume)
            self?.scheduleAutoHide()
        }
        volumeToolbar.onMuteToggle = { [weak self] muted in
            self?.delegate?.chromeDidToggleMute(muted)
            self?.scheduleAutoHide()
        }

        let bottomStack = UIStackView(arrangedSubviews: [progressRow, volumeToolbar])
        bottomStack.axis = .vertical
        bottomStack.spacing = 0
        bottomStack.translatesAutoresizingMaskIntoConstraints = false
        bottomPanel.addSubview(bottomStack)

        centerPlayButton.tintColor = .white
        centerPlayButton.backgroundColor = UIColor(white: 0, alpha: 0.45)
        centerPlayButton.layer.cornerRadius = 30
        centerPlayButton.translatesAutoresizingMaskIntoConstraints = false
        centerPlayButton.addTarget(self, action: #selector(centerPlayTapped), for: .touchUpInside)
        addSubview(centerPlayButton)

        NSLayoutConstraint.activate([
            bottomPanel.leadingAnchor.constraint(equalTo: leadingAnchor),
            bottomPanel.trailingAnchor.constraint(equalTo: trailingAnchor),
            bottomPanel.bottomAnchor.constraint(equalTo: bottomAnchor),

            bottomStack.leadingAnchor.constraint(equalTo: bottomPanel.leadingAnchor),
            bottomStack.trailingAnchor.constraint(equalTo: bottomPanel.trailingAnchor),
            bottomStack.topAnchor.constraint(equalTo: bottomPanel.topAnchor, constant: 4),
            bottomStack.bottomAnchor.constraint(equalTo: bottomPanel.bottomAnchor, constant: -4),

            progressRow.heightAnchor.constraint(equalToConstant: 36),

            centerPlayButton.centerXAnchor.constraint(equalTo: centerXAnchor),
            centerPlayButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            centerPlayButton.widthAnchor.constraint(equalToConstant: 60),
            centerPlayButton.heightAnchor.constraint(equalToConstant: 60),
        ])

        updateCenterPlayIcon()
        updateFullscreenIcon(isFullscreen: false)

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleBackgroundTap))
        tap.delegate = self
        addGestureRecognizer(tap)
    }

    private func applyConfig() {
        isHidden = !config.showNativeControls
        bottomPanel.isHidden = !config.showNativeControls
        centerPlayButton.isHidden = !config.showNativeControls
        volumeToolbar.isHidden = !config.showVolumeToolbar
        fullscreenButton.isHidden = !config.showFullscreenButton
    }

    private func updateCenterPlayIcon() {
        let symbol = isPlaying ? "pause.fill" : "play.fill"
        let image = UIImage(systemName: symbol)
        centerPlayButton.setImage(image, for: .normal)
    }

    private func scheduleAutoHide() {
        hideTimer?.invalidate()
        guard config.showNativeControls, isPlaying else { return }
        hideTimer = Timer.scheduledTimer(
            withTimeInterval: TimeInterval(config.dismissControlTimeMs) / 1000.0,
            repeats: false,
        ) { [weak self] _ in
            self?.setControlsVisible(false)
        }
    }

    @objc private func handleBackgroundTap() {
        toggleControlsVisibility()
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        let point = touch.location(in: self)
        if bottomPanel.frame.contains(point) {
            return false
        }
        if centerPlayButton.frame.contains(point) {
            return false
        }
        return true
    }

    @objc private func centerPlayTapped() {
        delegate?.chromeDidTapPlayPause()
        scheduleAutoHide()
    }

    @objc private func fullscreenTapped() {
        delegate?.chromeDidTapFullscreen()
        scheduleAutoHide()
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
            isSeeking = false
            return
        }
        let positionMs = Int(max(0, Int64(progressSlider.value * Float(durationMs))))
        delegate?.chromeDidSeek(toMs: positionMs)
        isSeeking = false
        scheduleAutoHide()
    }

    private static func formatMs(_ ms: Int64) -> String {
        let totalSeconds = max(0, ms / 1000)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

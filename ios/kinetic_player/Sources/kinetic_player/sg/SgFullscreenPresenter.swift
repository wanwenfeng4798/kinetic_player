import UIKit

/// Moves the player container into a window-level overlay for immersive playback.
final class SgFullscreenPresenter {
    private(set) var isFullscreen = false

    private weak var hostedContainer: UIView?
    private weak var originalSuperview: UIView?
    private var originalFrame: CGRect = .zero
    private var originalAutoresizingMask: UIView.AutoresizingMask = []
    private var overlayView: UIView?

    func enterFullscreen(container: UIView) {
        guard !isFullscreen, let window = container.window ?? SgFullscreenPresenter.keyWindow else {
            return
        }

        hostedContainer = container
        originalSuperview = container.superview
        originalFrame = container.frame
        originalAutoresizingMask = container.autoresizingMask

        let overlay = UIView(frame: window.bounds)
        overlay.backgroundColor = .black
        overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        window.addSubview(overlay)

        container.removeFromSuperview()
        container.frame = overlay.bounds
        container.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        overlay.addSubview(container)

        overlayView = overlay
        isFullscreen = true
    }

    func exitFullscreen() {
        guard isFullscreen,
              let container = hostedContainer,
              let superview = originalSuperview else {
            return
        }

        container.removeFromSuperview()
        container.frame = originalFrame
        container.autoresizingMask = originalAutoresizingMask
        superview.addSubview(container)

        overlayView?.removeFromSuperview()
        overlayView = nil
        isFullscreen = false
    }

    func toggleFullscreen(container: UIView) {
        if isFullscreen {
            exitFullscreen()
        } else {
            enterFullscreen(container: container)
        }
    }

    private static var keyWindow: UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }
    }
}

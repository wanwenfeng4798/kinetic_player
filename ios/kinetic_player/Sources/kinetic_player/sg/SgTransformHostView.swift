import UIKit

/// Clipping host that keeps Auto Layout identity while an inner content view
/// receives rotate / mirror transforms (safe with Flutter PlatformViews).
final class SgTransformHostView: UIView {
    let contentView = UIView()

    private(set) var rotationDegrees = 0
    private(set) var mirrorHorizontal = false
    private(set) var mirrorVertical = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        clipsToBounds = true
        backgroundColor = .black
        contentView.backgroundColor = .black
        contentView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(contentView)
        NSLayoutConstraint.activate([
            contentView.leadingAnchor.constraint(equalTo: leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: trailingAnchor),
            contentView.topAnchor.constraint(equalTo: topAnchor),
            contentView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        applyContentTransform()
    }

    func setRenderTransform(
        rotationDegrees: Int,
        mirrorHorizontal: Bool,
        mirrorVertical: Bool,
    ) {
        self.rotationDegrees = ((rotationDegrees % 360) + 360) % 360
        self.mirrorHorizontal = mirrorHorizontal
        self.mirrorVertical = mirrorVertical
        applyContentTransform()
    }

    private func applyContentTransform() {
        let w = bounds.width
        let h = bounds.height
        guard w > 1, h > 1 else {
            contentView.transform = .identity
            return
        }

        // UIView.transform is applied around the view center (anchor 0.5, 0.5).
        let sx: CGFloat = mirrorHorizontal ? -1 : 1
        let sy: CGFloat = mirrorVertical ? -1 : 1
        var transform = CGAffineTransform(scaleX: sx, y: sy)
        if rotationDegrees != 0 {
            let radians = CGFloat(rotationDegrees) * .pi / 180
            transform = transform.rotated(by: radians)
        }
        // 90/270 swap the AABB; scale to cover this host (clipsToBounds crops overflow).
        if rotationDegrees % 180 != 0 {
            let fillScale = max(w / h, h / w)
            transform = transform.scaledBy(x: fillScale, y: fillScale)
        }
        contentView.transform = transform
    }
}

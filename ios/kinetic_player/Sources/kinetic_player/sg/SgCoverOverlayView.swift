import UIKit

/// Poster / cover overlay above the video renderer (below chrome).
final class SgCoverOverlayView: UIView {
    private let imageView = UIImageView()
    private var loadGeneration = 0
    private var currentUrl: String?

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = .black
        clipsToBounds = true
        isHidden = true

        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            imageView.topAnchor.constraint(equalTo: topAnchor),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    var hasCoverImage: Bool { imageView.image != nil }

    var hasCover: Bool {
        currentUrl?.isEmpty == false || imageView.image != nil
    }

    /// Invoked on the main queue after a remote/local cover image is applied.
    var onCoverImageUpdated: (() -> Void)?

    func setCoverUrl(_ urlString: String?) {
        if urlString == nil || urlString?.isEmpty == true {
            loadGeneration += 1
            currentUrl = nil
            imageView.image = nil
            onCoverImageUpdated?()
            return
        }
        guard urlString != currentUrl else { return }
        currentUrl = urlString
        let generation = loadGeneration + 1
        loadGeneration = generation

        if let local = loadLocalImage(urlString!) {
            imageView.image = local
            onCoverImageUpdated?()
            return
        }

        guard let url = URL(string: urlString!) else { return }
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let self,
                  let data,
                  let image = UIImage(data: data) else { return }
            DispatchQueue.main.async {
                guard generation == self.loadGeneration else { return }
                self.imageView.image = image
                self.onCoverImageUpdated?()
            }
        }.resume()
    }

    private func loadLocalImage(_ urlString: String) -> UIImage? {
        if urlString.hasPrefix("file://"),
           let path = URL(string: urlString)?.path {
            return UIImage(contentsOfFile: path)
        }
        if FileManager.default.fileExists(atPath: urlString) {
            return UIImage(contentsOfFile: urlString)
        }
        return nil
    }
}

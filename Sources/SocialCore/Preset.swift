import Foundation

/// A social network for which output sizes are provided.
public enum Platform: String, CaseIterable, Sendable {
    case instagram = "Instagram", youtube = "YouTube", facebook = "Facebook", linkedin = "LinkedIn", x = "X"
}

/// A named output size in pixels. Custom sizes must be positive when rendered.
public struct Preset: Identifiable, Hashable, Sendable {
    public let id: String
    public let platform: Platform
    public let name: String
    public let width: Int
    public let height: Int

    public init(id: String, platform: Platform, name: String, width: Int, height: Int) {
        self.id = id; self.platform = platform; self.name = name
        self.width = width; self.height = height
    }

    /// Common output sizes; callers can also construct their own presets.
    public static let all: [Preset] = [
        .init(id: "instagram-portrait", platform: .instagram, name: "Post verticale", width: 1080, height: 1350),
        .init(id: "instagram-3-4", platform: .instagram, name: "Post verticale 3:4", width: 1080, height: 1440),
        .init(id: "instagram-landscape", platform: .instagram, name: "Post orizzontale", width: 1080, height: 566),
        .init(id: "instagram-square", platform: .instagram, name: "Post quadrato", width: 1080, height: 1080),
        .init(id: "instagram-story", platform: .instagram, name: "Storia / Copertina Reel", width: 1080, height: 1920),
        .init(id: "instagram-profile", platform: .instagram, name: "Immagine profilo", width: 320, height: 320),
        .init(id: "youtube-thumbnail", platform: .youtube, name: "Miniatura 4K", width: 3840, height: 2160),
        .init(id: "youtube-shorts", platform: .youtube, name: "Copertina Shorts 4K", width: 2160, height: 3840),
        .init(id: "youtube-profile", platform: .youtube, name: "Immagine profilo", width: 800, height: 800),
        .init(id: "youtube-banner", platform: .youtube, name: "Copertina", width: 2560, height: 1440),
        .init(id: "facebook-post", platform: .facebook, name: "Post orizzontale", width: 1200, height: 630),
        .init(id: "facebook-portrait", platform: .facebook, name: "Post verticale", width: 1080, height: 1350),
        .init(id: "facebook-square", platform: .facebook, name: "Post quadrato", width: 1080, height: 1080),
        .init(id: "facebook-story", platform: .facebook, name: "Storia", width: 1080, height: 1920),
        .init(id: "facebook-profile", platform: .facebook, name: "Immagine profilo", width: 320, height: 320),
        .init(id: "facebook-cover", platform: .facebook, name: "Copertina", width: 1640, height: 624),
        .init(id: "linkedin-post", platform: .linkedin, name: "Post orizzontale", width: 1200, height: 627),
        .init(id: "linkedin-portrait", platform: .linkedin, name: "Post verticale", width: 1080, height: 1350),
        .init(id: "linkedin-square", platform: .linkedin, name: "Post quadrato", width: 1080, height: 1080),
        .init(id: "linkedin-profile", platform: .linkedin, name: "Immagine profilo", width: 400, height: 400),
        .init(id: "linkedin-cover", platform: .linkedin, name: "Copertina", width: 1584, height: 396),
        .init(id: "linkedin-company-cover", platform: .linkedin, name: "Copertina aziendale", width: 1512, height: 256),
        .init(id: "x-portrait", platform: .x, name: "Post verticale", width: 1080, height: 1350),
        .init(id: "x-square", platform: .x, name: "Post quadrato", width: 1080, height: 1080),
        .init(id: "x-post", platform: .x, name: "Post orizzontale", width: 1200, height: 675),
        .init(id: "x-profile", platform: .x, name: "Immagine profilo", width: 400, height: 400),
        .init(id: "x-header", platform: .x, name: "Copertina", width: 1500, height: 500)
    ]
}

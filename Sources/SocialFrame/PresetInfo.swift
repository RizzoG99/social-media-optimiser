import Foundation
import SocialCore

enum SpecificationStatus {
    case officialRequirement, officialRecommendation, practical
    var title: String {
        switch self {
        case .officialRequirement: return L10n.text("Requisito ufficiale")
        case .officialRecommendation: return L10n.text("Raccomandazione ufficiale")
        case .practical: return L10n.text("Formato pratico, da verificare")
        }
    }
}

extension Preset {
    var localizedName: String { L10n.text(name) }
    var referenceURL: URL {
        switch platform {
        case .instagram: return URL(string: "https://help.instagram.com/1631821640426723")!
        case .youtube: return URL(string: id.contains("thumbnail") || id.contains("shorts") ? "https://support.google.com/youtube/answer/72431" : "https://support.google.com/youtube/answer/10456525")!
        case .facebook: return URL(string: "https://www.facebook.com/help/125379114252045")!
        case .linkedin:
            let answer = id == "linkedin-company-cover" ? "a567368" : (id == "linkedin-profile" || id == "linkedin-cover") ? "a549049" : "a527229"
            return URL(string: "https://www.linkedin.com/help/\(id == "linkedin-company-cover" ? "lms" : "linkedin")/answer/" + answer)!
        case .x: return URL(string: id == "x-profile" || id == "x-header" ? "https://help.x.com/en/managing-your-account/common-issues-when-uploading-profile-photo" : "https://help.x.com/en/using-x/posting-gifs-and-pictures")!
        }
    }
    var specificationStatus: SpecificationStatus {
        switch id {
        case "linkedin-profile": return .officialRequirement
        case "youtube-thumbnail", "youtube-shorts", "youtube-banner", "linkedin-cover", "x-profile", "x-header": return .officialRecommendation
        default: return .practical
        }
    }
    /// Only these destinations were successfully rechecked; never use a global date.
    var verifiedOn: String? {
        switch id {
        case "youtube-thumbnail", "youtube-shorts", "youtube-banner", "youtube-profile", "linkedin-profile", "linkedin-cover", "x-profile", "x-header": return "12/11/2026"
        default: return nil
        }
    }
    var verificationNote: String {
        if let verifiedOn { return L10n.format("Fonte verificata il %@", verifiedOn) }
        return L10n.text("Dimensioni non verificate in una fonte ufficiale accessibile.")
    }
    var referenceNote: String {
        let detail: String
        switch id {
        case "linkedin-profile": detail = L10n.text("400 × 400 px è il minimo, non l’unica dimensione ammessa. JPG/PNG, massimo 8 MB.")
        case "linkedin-cover": detail = L10n.text("1584 × 396 px consigliati. JPG/PNG, massimo 8 MB.")
        case "youtube-banner": detail = L10n.text("2560 × 1440 px consigliati; minimo 2048 × 1152, massimo 6 MB. Il ritaglio varia per dispositivo.")
        case "youtube-thumbnail", "youtube-shorts": detail = L10n.text("Dimensioni 4K consigliate. JPG/PNG; massimo 50 MB da computer, 2 MB per miniature video da mobile. Shorts: caricamento da Studio su computer.")
        case "youtube-profile": detail = L10n.text("800 × 800 px è una scelta pratica. La fonte indica resa a 98 × 98 px e massimo 15 MB.")
        case "x-profile": detail = L10n.text("400 × 400 px consigliati, massimo 2 MB. JPEG/GIF/PNG.")
        case "x-header": detail = L10n.text("1500 × 500 px consigliati. Il ritaglio varia per schermo e browser.")
        default: detail = L10n.text("Target di esportazione, non un requisito di caricamento verificato.")
        }
        return specificationStatus.title + ". " + detail + " " + L10n.text("I limiti di peso della piattaforma non sono controllati dall’app.")
    }
}

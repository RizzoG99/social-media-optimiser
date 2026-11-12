import Foundation
import SocialCore

extension Preset {
    var referenceURL: URL {
        switch platform {
        case .instagram: return URL(string: "https://help.instagram.com/1631821640426723")!
        case .youtube: return URL(string: id.contains("thumbnail") || id.contains("shorts") ? "https://support.google.com/youtube/answer/72431" : "https://support.google.com/youtube/answer/10456525")!
        case .facebook: return URL(string: "https://www.facebook.com/help/125379114252045")!
        case .linkedin:
            let answer = id.contains("company") ? "a567368" : id.contains("profile") ? "a549049" : id.contains("cover") ? "a568217" : "a527229"
            return URL(string: "https://www.linkedin.com/help/linkedin/answer/" + answer)!
        case .x: return URL(string: id.contains("post") || id.contains("portrait") || id.contains("square") ? "https://help.x.com/en/using-x/posting-gifs-and-pictures" : "https://help.x.com/en/managing-your-account/common-issues-when-uploading-profile-photo.html")!
        }
    }
    var referenceNote: String {
        switch platform {
        case .facebook: return "Preset pratico; specifiche ufficiali da ricontrollare."
        case .x: return id.contains("post") || id.contains("portrait") || id.contains("square") ? "Preset pratico per immagini nei post." : "Misura consigliata dall’assistenza X."
        default: return "Preset di esportazione; può differire dai limiti di caricamento."
        }
    }
}

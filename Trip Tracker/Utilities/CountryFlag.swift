import Foundation

enum CountryFlag {
    static func emoji(for rawCountry: String) -> String? {
        let trimmed = rawCountry.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let code = isoCode(forInput: trimmed) {
            return flag(for: code)
        }

        let normalized = normalize(trimmed)
        if let code = lookup[normalized] {
            return flag(for: code)
        }

        if let code = Locale.Region.isoRegions
            .first(where: { region in
                let identifier = region.identifier
                let localized = Locale(identifier: "en_US").localizedString(forRegionCode: identifier) ?? ""
                return normalize(localized) == normalized
            })?
            .identifier {
            return flag(for: code)
        }

        return nil
    }

    private static func isoCode(forInput value: String) -> String? {
        guard value.count == 2 else { return nil }
        let upper = value.uppercased()
        guard upper.allSatisfy({ ("A"..."Z").contains($0) }) else { return nil }
        return upper
    }

    private static func flag(for isoCode: String) -> String? {
        let upper = isoCode.uppercased()
        guard upper.count == 2 else { return nil }
        var scalarString = ""
        for character in upper.unicodeScalars {
            guard let scalar = UnicodeScalar(127397 + character.value) else { return nil }
            scalarString.unicodeScalars.append(scalar)
        }
        return scalarString.isEmpty ? nil : scalarString
    }

    private static func normalize(_ value: String) -> String {
        let folded = value.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        return folded
            .replacingOccurrences(of: "&", with: "and")
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: "'", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    private static let lookup: [String: String] = {
        var map: [String: String] = [:]

        for region in Locale.Region.isoRegions where region.identifier.count == 2 {
            let code = region.identifier
            for languageID in ["en_US", "en_GB"] {
                if let name = Locale(identifier: languageID).localizedString(forRegionCode: code) {
                    map[normalize(name)] = code
                }
            }
        }

        let aliases: [String: String] = [
            "usa": "US",
            "us": "US",
            "united states": "US",
            "united states of america": "US",
            "america": "US",
            "uk": "GB",
            "great britain": "GB",
            "britain": "GB",
            "england": "GB",
            "scotland": "GB",
            "wales": "GB",
            "northern ireland": "GB",
            "south korea": "KR",
            "korea": "KR",
            "north korea": "KP",
            "russia": "RU",
            "vietnam": "VN",
            "czech republic": "CZ",
            "czechia": "CZ",
            "ivory coast": "CI",
            "cote divoire": "CI",
            "burma": "MM",
            "myanmar": "MM",
            "uae": "AE",
            "emirates": "AE",
            "holland": "NL",
            "the netherlands": "NL",
            "netherlands": "NL",
            "vatican": "VA",
            "vatican city": "VA",
            "palestine": "PS",
            "swaziland": "SZ",
            "macedonia": "MK",
            "north macedonia": "MK",
            "cape verde": "CV",
            "east timor": "TL",
            "timor leste": "TL",
            "laos": "LA",
            "moldova": "MD",
            "tanzania": "TZ",
            "venezuela": "VE",
            "bolivia": "BO",
            "iran": "IR",
            "syria": "SY"
        ]

        for (key, value) in aliases {
            map[normalize(key)] = value
        }

        return map
    }()
}

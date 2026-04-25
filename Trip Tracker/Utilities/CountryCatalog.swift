import Foundation
import SwiftUI

enum Continent: String, CaseIterable, Identifiable, Hashable {
    case africa
    case americas
    case asia
    case europe
    case oceania
    case antarctica

    var id: String { rawValue }

    var label: String {
        switch self {
        case .africa: "Africa"
        case .americas: "Americas"
        case .asia: "Asia"
        case .europe: "Europe"
        case .oceania: "Oceania"
        case .antarctica: "Antarctica"
        }
    }

    var color: Color {
        switch self {
        case .africa: AppTheme.ColorToken.routeGold
        case .americas: AppTheme.ColorToken.routeBlue
        case .asia: AppTheme.ColorToken.routeRose
        case .europe: AppTheme.ColorToken.routeViolet
        case .oceania: AppTheme.ColorToken.positive
        case .antarctica: AppTheme.ColorToken.routeSlate
        }
    }
}

struct CountryRecord: Identifiable, Hashable {
    let isoCode: String
    let name: String
    let continent: Continent?

    var id: String { isoCode }

    var flag: String? {
        CountryFlag.flag(forISO: isoCode)
    }
}

enum CountryCatalog {
    static let allRecords: [CountryRecord] = {
        let englishLocale = Locale(identifier: "en_US")
        return Locale.Region.isoRegions
            .filter { $0.identifier.count == 2 }
            .compactMap { region -> CountryRecord? in
                let code = region.identifier
                guard let name = englishLocale.localizedString(forRegionCode: code) else { return nil }
                return CountryRecord(
                    isoCode: code,
                    name: name,
                    continent: continentMap[code]
                )
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }()

    static func record(forCountryName name: String) -> CountryRecord? {
        guard let iso = CountryFlag.isoCode(forCountryName: name) else { return nil }
        return record(forISO: iso)
    }

    static func record(forISO isoCode: String) -> CountryRecord? {
        let upper = isoCode.uppercased()
        return allRecords.first { $0.isoCode == upper }
    }

    private static let continentMap: [String: Continent] = [
        "DZ": .africa, "AO": .africa, "BJ": .africa, "BW": .africa, "BF": .africa, "BI": .africa,
        "CM": .africa, "CV": .africa, "CF": .africa, "TD": .africa, "KM": .africa, "CG": .africa,
        "CD": .africa, "CI": .africa, "DJ": .africa, "EG": .africa, "GQ": .africa, "ER": .africa,
        "SZ": .africa, "ET": .africa, "GA": .africa, "GM": .africa, "GH": .africa, "GN": .africa,
        "GW": .africa, "KE": .africa, "LS": .africa, "LR": .africa, "LY": .africa, "MG": .africa,
        "MW": .africa, "ML": .africa, "MR": .africa, "MU": .africa, "YT": .africa, "MA": .africa,
        "MZ": .africa, "NA": .africa, "NE": .africa, "NG": .africa, "RE": .africa, "RW": .africa,
        "SH": .africa, "ST": .africa, "SN": .africa, "SC": .africa, "SL": .africa, "SO": .africa,
        "ZA": .africa, "SS": .africa, "SD": .africa, "TZ": .africa, "TG": .africa, "TN": .africa,
        "UG": .africa, "EH": .africa, "ZM": .africa, "ZW": .africa, "IO": .africa,

        "AI": .americas, "AG": .americas, "AR": .americas, "AW": .americas, "BS": .americas,
        "BB": .americas, "BZ": .americas, "BM": .americas, "BO": .americas, "BQ": .americas,
        "BR": .americas, "VG": .americas, "CA": .americas, "KY": .americas, "CL": .americas,
        "CO": .americas, "CR": .americas, "CU": .americas, "CW": .americas, "DM": .americas,
        "DO": .americas, "EC": .americas, "SV": .americas, "FK": .americas, "GF": .americas,
        "GL": .americas, "GD": .americas, "GP": .americas, "GT": .americas, "GY": .americas,
        "HT": .americas, "HN": .americas, "JM": .americas, "MQ": .americas, "MX": .americas,
        "MS": .americas, "NI": .americas, "PA": .americas, "PY": .americas, "PE": .americas,
        "PR": .americas, "BL": .americas, "KN": .americas, "LC": .americas, "MF": .americas,
        "PM": .americas, "VC": .americas, "SX": .americas, "SR": .americas, "TT": .americas,
        "TC": .americas, "US": .americas, "VI": .americas, "UY": .americas, "VE": .americas,

        "AF": .asia, "AM": .asia, "AZ": .asia, "BH": .asia, "BD": .asia, "BT": .asia,
        "BN": .asia, "KH": .asia, "CN": .asia, "CY": .asia, "GE": .asia, "HK": .asia,
        "IN": .asia, "ID": .asia, "IR": .asia, "IQ": .asia, "IL": .asia, "JP": .asia,
        "JO": .asia, "KZ": .asia, "KW": .asia, "KG": .asia, "LA": .asia, "LB": .asia,
        "MO": .asia, "MY": .asia, "MV": .asia, "MN": .asia, "MM": .asia, "NP": .asia,
        "KP": .asia, "OM": .asia, "PK": .asia, "PS": .asia, "PH": .asia, "QA": .asia,
        "SA": .asia, "SG": .asia, "KR": .asia, "LK": .asia, "SY": .asia, "TW": .asia,
        "TJ": .asia, "TH": .asia, "TL": .asia, "TR": .asia, "TM": .asia, "AE": .asia,
        "UZ": .asia, "VN": .asia, "YE": .asia,

        "AX": .europe, "AL": .europe, "AD": .europe, "AT": .europe, "BY": .europe,
        "BE": .europe, "BA": .europe, "BG": .europe, "HR": .europe, "CZ": .europe,
        "DK": .europe, "EE": .europe, "FO": .europe, "FI": .europe, "FR": .europe,
        "DE": .europe, "GI": .europe, "GR": .europe, "GG": .europe, "VA": .europe,
        "HU": .europe, "IS": .europe, "IE": .europe, "IM": .europe, "IT": .europe,
        "JE": .europe, "XK": .europe, "LV": .europe, "LI": .europe, "LT": .europe,
        "LU": .europe, "MT": .europe, "MD": .europe, "MC": .europe, "ME": .europe,
        "NL": .europe, "MK": .europe, "NO": .europe, "PL": .europe, "PT": .europe,
        "RO": .europe, "RU": .europe, "SM": .europe, "RS": .europe, "SK": .europe,
        "SI": .europe, "ES": .europe, "SJ": .europe, "SE": .europe, "CH": .europe,
        "UA": .europe, "GB": .europe,

        "AS": .oceania, "AU": .oceania, "CX": .oceania, "CC": .oceania, "CK": .oceania,
        "FJ": .oceania, "PF": .oceania, "GU": .oceania, "KI": .oceania, "MH": .oceania,
        "FM": .oceania, "NR": .oceania, "NC": .oceania, "NZ": .oceania, "NU": .oceania,
        "NF": .oceania, "MP": .oceania, "PW": .oceania, "PG": .oceania, "PN": .oceania,
        "WS": .oceania, "SB": .oceania, "TK": .oceania, "TO": .oceania, "TV": .oceania,
        "UM": .oceania, "VU": .oceania, "WF": .oceania,

        "AQ": .antarctica, "BV": .antarctica, "TF": .antarctica, "HM": .antarctica,
        "GS": .antarctica
    ]
}

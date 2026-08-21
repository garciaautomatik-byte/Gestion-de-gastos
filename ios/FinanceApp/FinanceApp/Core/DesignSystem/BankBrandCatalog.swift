import Foundation

struct BankBrand {
    let name: String
    let colorHex: String
    /// Official web domain, used to fetch the real brand logo at runtime via Google's public
    /// favicon service (https://www.google.com/s2/favicons?domain={domain}) — the same technique
    /// browsers use for favicons, so no trademarked artwork is bundled in the app itself.
    let domain: String
}

/// Auto-suggests a brand color and logo when an account name matches a known Spanish
/// bank/fintech (e.g. typing "Revolut" fetches Revolut's real logo and tints the account
/// like Revolut does).
enum BankBrandCatalog {
    private static let entries: [(keywords: [String], brand: BankBrand)] = [
        (["revolut"], BankBrand(name: "Revolut", colorHex: "#0A0A0A", domain: "revolut.com")),
        (["bbva"], BankBrand(name: "BBVA", colorHex: "#004481", domain: "bbva.es")),
        (["santander"], BankBrand(name: "Santander", colorHex: "#EC0000", domain: "santander.com")),
        (["caixabank", "la caixa", "caixa"], BankBrand(name: "CaixaBank", colorHex: "#0066B3", domain: "caixabank.es")),
        (["sabadell"], BankBrand(name: "Sabadell", colorHex: "#0047BB", domain: "bancsabadell.com")),
        (["bankinter"], BankBrand(name: "Bankinter", colorHex: "#F5821F", domain: "bankinter.com")),
        (["openbank"], BankBrand(name: "Openbank", colorHex: "#EE1C25", domain: "openbank.es")),
        (["ing"], BankBrand(name: "ING", colorHex: "#FF6200", domain: "ing.es")),
        (["n26"], BankBrand(name: "N26", colorHex: "#48AC96", domain: "n26.com")),
        (["kutxabank", "kutxa"], BankBrand(name: "Kutxabank", colorHex: "#E30613", domain: "kutxabank.es")),
        (["unicaja"], BankBrand(name: "Unicaja", colorHex: "#00953B", domain: "unicajabanco.es")),
        (["ibercaja"], BankBrand(name: "Ibercaja", colorHex: "#0066CC", domain: "ibercaja.es")),
        (["abanca"], BankBrand(name: "Abanca", colorHex: "#00A19A", domain: "abanca.com")),
        (["evobanco", "evo banco"], BankBrand(name: "EVO Banco", colorHex: "#6D2077", domain: "evobanco.com")),
        (["imagin"], BankBrand(name: "imagin", colorHex: "#FF4694", domain: "imagin.com")),
        (["wise"], BankBrand(name: "Wise", colorHex: "#9FE870", domain: "wise.com")),
        (["paypal"], BankBrand(name: "PayPal", colorHex: "#003087", domain: "paypal.com")),
        (["bizum"], BankBrand(name: "Bizum", colorHex: "#00C7B1", domain: "bizum.es")),
        (["trade republic", "traderepublic"], BankBrand(name: "Trade Republic", colorHex: "#000000", domain: "traderepublic.com")),
    ]

    static func match(for accountName: String) -> BankBrand? {
        let normalized = accountName.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        guard !normalized.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        for entry in entries {
            for keyword in entry.keywords where normalized.contains(keyword) {
                return entry.brand
            }
        }
        return nil
    }
}

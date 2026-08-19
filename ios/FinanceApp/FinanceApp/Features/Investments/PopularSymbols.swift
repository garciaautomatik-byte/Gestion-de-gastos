import Foundation

/// A small curated "quick pick" list shown by default in the symbol search, before the user
/// types anything. Twelve Data has no endpoint to browse instruments, so this is hardcoded —
/// tapping an entry runs a real search for it (not an instant pick), so the result still comes
/// from live data with the correct exchange for price lookups.
enum PopularSymbols {
    static func suggestions(for assetType: AssetType) -> [(symbol: String, name: String)] {
        switch assetType {
        case .stock: return stocks
        case .etf: return etfs
        case .fund: return funds
        case .crypto: return crypto
        case .other: return []
        }
    }

    private static let stocks: [(symbol: String, name: String)] = [
        ("AAPL", "Apple"),
        ("MSFT", "Microsoft"),
        ("GOOGL", "Alphabet (Google)"),
        ("AMZN", "Amazon"),
        ("NVDA", "Nvidia"),
        ("META", "Meta Platforms"),
        ("TSLA", "Tesla"),
        ("BRK.B", "Berkshire Hathaway"),
        ("JPM", "JPMorgan Chase"),
        ("V", "Visa"),
        ("UNH", "UnitedHealth Group"),
        ("JNJ", "Johnson & Johnson"),
        ("WMT", "Walmart"),
        ("PG", "Procter & Gamble"),
        ("MA", "Mastercard"),
        ("HD", "Home Depot"),
        ("DIS", "Walt Disney"),
        ("NFLX", "Netflix"),
        ("KO", "Coca-Cola"),
        ("PEP", "PepsiCo")
    ]

    private static let etfs: [(symbol: String, name: String)] = [
        ("VWCE", "Vanguard FTSE All-World UCITS ETF"),
        ("SPY", "SPDR S&P 500 ETF Trust"),
        ("VOO", "Vanguard S&P 500 ETF"),
        ("IVV", "iShares Core S&P 500 ETF"),
        ("QQQ", "Invesco QQQ Trust (Nasdaq-100)"),
        ("VTI", "Vanguard Total Stock Market ETF"),
        ("IWDA", "iShares Core MSCI World UCITS ETF"),
        ("EUNL", "iShares Core MSCI World UCITS ETF (Xetra)"),
        ("VUSA", "Vanguard S&P 500 UCITS ETF"),
        ("CSPX", "iShares Core S&P 500 UCITS ETF"),
        ("EIMI", "iShares Core MSCI EM IMI UCITS ETF"),
        ("VGK", "Vanguard FTSE Europe ETF"),
        ("EWJ", "iShares MSCI Japan ETF"),
        ("GLD", "SPDR Gold Shares"),
        ("IEMG", "iShares Core MSCI Emerging Markets ETF"),
        ("XLK", "Technology Select Sector SPDR"),
        ("ARKK", "ARK Innovation ETF"),
        ("VIG", "Vanguard Dividend Appreciation ETF"),
        ("AGG", "iShares Core U.S. Aggregate Bond ETF"),
        ("BND", "Vanguard Total Bond Market ETF")
    ]

    private static let funds: [(symbol: String, name: String)] = [
        ("VFIAX", "Vanguard 500 Index Fund"),
        ("FXAIX", "Fidelity 500 Index Fund"),
        ("VTSAX", "Vanguard Total Stock Market Index Fund"),
        ("SWPPX", "Schwab S&P 500 Index Fund"),
        ("VTIAX", "Vanguard Total International Stock Index Fund"),
        ("VBTLX", "Vanguard Total Bond Market Index Fund"),
        ("FSKAX", "Fidelity Total Market Index Fund"),
        ("VGTSX", "Vanguard Total International Stock Index Fund (Investor)")
    ]

    private static let crypto: [(symbol: String, name: String)] = [
        ("BTC/USD", "Bitcoin"),
        ("ETH/USD", "Ethereum"),
        ("USDT/USD", "Tether"),
        ("BNB/USD", "BNB"),
        ("SOL/USD", "Solana"),
        ("XRP/USD", "XRP"),
        ("USDC/USD", "USD Coin"),
        ("ADA/USD", "Cardano"),
        ("DOGE/USD", "Dogecoin"),
        ("AVAX/USD", "Avalanche"),
        ("DOT/USD", "Polkadot"),
        ("MATIC/USD", "Polygon"),
        ("LTC/USD", "Litecoin"),
        ("SHIB/USD", "Shiba Inu"),
        ("TRX/USD", "TRON"),
        ("LINK/USD", "Chainlink"),
        ("ATOM/USD", "Cosmos"),
        ("XLM/USD", "Stellar"),
        ("BCH/USD", "Bitcoin Cash"),
        ("NEAR/USD", "NEAR Protocol")
    ]
}

import Foundation

enum PriceServiceError: LocalizedError {
    case invalidResponse
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Respuesta inesperada del servicio de precios."
        case .apiError(let message):
            return message
        }
    }
}

struct SymbolSearchResult: Identifiable, Decodable, Hashable {
    var id: String { "\(symbol)-\(exchange ?? "")" }
    let symbol: String
    let instrumentName: String?
    let exchange: String?
    let instrumentType: String?

    enum CodingKeys: String, CodingKey {
        case symbol
        case longname
        case shortname
        case exchDisp
        case quoteType
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        symbol = try container.decode(String.self, forKey: .symbol)
        instrumentName = try container.decodeIfPresent(String.self, forKey: .longname)
            ?? container.decodeIfPresent(String.self, forKey: .shortname)
        exchange = try container.decodeIfPresent(String.self, forKey: .exchDisp)
        instrumentType = try container.decodeIfPresent(String.self, forKey: .quoteType)
    }

    init(symbol: String, instrumentName: String?, exchange: String?, instrumentType: String?) {
        self.symbol = symbol
        self.instrumentName = instrumentName
        self.exchange = exchange
        self.instrumentType = instrumentType
    }
}

struct PriceQuote {
    let price: Decimal
    let currency: String?
}

/// Thin client for Yahoo Finance's unofficial, undocumented endpoints (no API key, no signup —
/// chosen after Twelve Data's free tier turned out to gate real-time quotes for many European
/// ETFs behind a paid plan). Being unofficial, it isn't guaranteed stable: Yahoo can change or
/// block these endpoints without notice.
struct PriceService {
    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.httpAdditionalHeaders = ["User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15"]
        return URLSession(configuration: config)
    }()

    func fetchQuote(symbol: String) async throws -> PriceQuote {
        guard var components = URLComponents(string: "https://query1.finance.yahoo.com/v8/finance/chart/\(symbol)") else {
            throw PriceServiceError.invalidResponse
        }
        components.queryItems = [
            URLQueryItem(name: "interval", value: "1d"),
            URLQueryItem(name: "range", value: "1d")
        ]
        guard let url = components.url else { throw PriceServiceError.invalidResponse }

        let (data, _) = try await session.data(from: url)
        let decoded = try JSONDecoder().decode(ChartResponse.self, from: data)

        if let description = decoded.chart.error?.description {
            throw PriceServiceError.apiError(description)
        }
        guard let meta = decoded.chart.result?.first?.meta, let price = meta.regularMarketPrice else {
            throw PriceServiceError.apiError("Símbolo no encontrado.")
        }
        return PriceQuote(price: Decimal(price), currency: meta.currency)
    }

    /// No official "browse all instruments" endpoint exists — this is search-as-you-type instead.
    func searchSymbols(query: String) async throws -> [SymbolSearchResult] {
        guard var components = URLComponents(string: "https://query1.finance.yahoo.com/v1/finance/search") else {
            throw PriceServiceError.invalidResponse
        }
        components.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "quotesCount", value: "20"),
            URLQueryItem(name: "newsCount", value: "0")
        ]
        guard let url = components.url else { throw PriceServiceError.invalidResponse }

        let (data, _) = try await session.data(from: url)
        let decoded = try JSONDecoder().decode(SearchResponse.self, from: data)
        return decoded.quotes ?? []
    }
}

private struct ChartResponse: Decodable {
    let chart: Chart

    struct Chart: Decodable {
        let result: [Result]?
        let error: ChartError?
    }

    struct Result: Decodable {
        let meta: Meta
    }

    struct Meta: Decodable {
        let regularMarketPrice: Double?
        let currency: String?
    }

    struct ChartError: Decodable {
        let description: String?
    }
}

private struct SearchResponse: Decodable {
    let quotes: [SymbolSearchResult]?
}

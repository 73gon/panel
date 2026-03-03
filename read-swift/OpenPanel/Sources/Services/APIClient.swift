import Foundation

// MARK: - API Errors

enum APIError: LocalizedError {
    case noServer
    case invalidURL
    case httpError(Int, String)
    case decodingError(Error)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .noServer: return "No server configured"
        case .invalidURL: return "Invalid URL"
        case .httpError(let code, let msg): return "HTTP \(code): \(msg)"
        case .decodingError(let err): return "Decode error: \(err.localizedDescription)"
        case .networkError(let err): return err.localizedDescription
        }
    }
}

// MARK: - API Client

@MainActor
final class APIClient: ObservableObject, Sendable {
    private let session: URLSession
    private let baseURL: URL
    private let deviceId: String
    @Published var profileToken: String?

    init(baseURL: URL, deviceId: String, profileToken: String? = nil) {
        self.baseURL = baseURL
        self.deviceId = deviceId
        self.profileToken = profileToken

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 300
        config.urlCache = URLCache(
            memoryCapacity: 50 * 1024 * 1024,   // 50 MB
            diskCapacity: 200 * 1024 * 1024,     // 200 MB
            diskPath: "openpanel_cache"
        )
        self.session = URLSession(configuration: config)
    }

    // MARK: - URL Builders

    func pageURL(bookId: String, page: Int) -> URL {
        baseURL.appendingPathComponent("api/books/\(bookId)/pages/\(page)")
    }

    func thumbnailURL(bookId: String) -> URL {
        baseURL.appendingPathComponent("api/books/\(bookId)/thumbnail")
    }

    func seriesThumbnailURL(seriesId: String) -> URL {
        baseURL.appendingPathComponent("api/series/\(seriesId)/thumbnail")
    }

    // MARK: - Core Request

    private func request<T: Decodable>(
        _ path: String,
        method: String = "GET",
        body: Data? = nil
    ) async throws -> T {
        let url = baseURL.appendingPathComponent("api\(path)")
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(deviceId, forHTTPHeaderField: "X-Device-Id")

        if let token = profileToken {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body {
            req.httpBody = body
        }

        let (data, response) = try await session.data(for: req)

        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidURL
        }

        guard (200...299).contains(http.statusCode) else {
            let msg = String(data: data, encoding: .utf8) ?? ""
            throw APIError.httpError(http.statusCode, msg)
        }

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }

    private func requestVoid(
        _ path: String,
        method: String = "GET",
        body: Data? = nil
    ) async throws {
        let url = baseURL.appendingPathComponent("api\(path)")
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(deviceId, forHTTPHeaderField: "X-Device-Id")

        if let token = profileToken {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body {
            req.httpBody = body
        }

        let (data, response) = try await session.data(for: req)

        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidURL
        }

        guard (200...299).contains(http.statusCode) else {
            let msg = String(data: data, encoding: .utf8) ?? ""
            throw APIError.httpError(http.statusCode, msg)
        }
    }

    // MARK: - Libraries

    func fetchLibraries() async throws -> [Library] {
        let resp: LibrariesResponse = try await request("/libraries")
        return resp.libraries
    }

    func fetchSeries(libraryId: String, page: Int = 1, perPage: Int = 200) async throws -> SeriesResponse {
        return try await request("/libraries/\(libraryId)/series?page=\(page)&per_page=\(perPage)")
    }

    func fetchAllSeries(page: Int = 1, perPage: Int = 200) async throws -> SeriesResponse {
        return try await request("/series?page=\(page)&per_page=\(perPage)")
    }

    // MARK: - Books

    func fetchBooks(seriesId: String) async throws -> BooksResponse {
        return try await request("/series/\(seriesId)/books")
    }

    func fetchBookDetail(bookId: String) async throws -> BookDetail {
        return try await request("/books/\(bookId)")
    }

    // MARK: - Progress

    func fetchProgress(bookId: String) async throws -> ReadingProgress? {
        do {
            return try await request("/progress?book_id=\(bookId)")
        } catch APIError.httpError(404, _) {
            return nil
        }
    }

    func updateProgress(bookId: String, page: Int, isCompleted: Bool = false) async throws {
        let body = try JSONEncoder().encode([
            "book_id": bookId,
            "page": "\(page)",
            "is_completed": isCompleted ? "true" : "false"
        ])
        try await requestVoid("/progress", method: "PUT", body: body)
    }

    func fetchBatchProgress(bookIds: [String]) async throws -> [String: ReadingProgress] {
        guard !bookIds.isEmpty else { return [:] }
        let query = bookIds.joined(separator: ",")
        let resp: BatchProgressResponse = try await request("/progress/batch?book_ids=\(query)")
        return resp.progress
    }

    // MARK: - Profiles

    func fetchProfiles() async throws -> [Profile] {
        let resp: ProfilesResponse = try await request("/profiles")
        return resp.profiles
    }

    func selectProfile(id: String, pin: String? = nil) async throws -> ProfileSelectResponse {
        var payload: [String: String] = [:]
        if let pin { payload["pin"] = pin }
        let body = try JSONEncoder().encode(payload)
        return try await request("/profiles/\(id)/select", method: "POST", body: body)
    }

    func logout() async throws {
        try await requestVoid("/profiles/logout", method: "POST")
    }

    // MARK: - Admin

    func adminStatus() async throws -> AdminStatusResponse {
        return try await request("/admin/status")
    }

    func adminUnlock(password: String) async throws -> String {
        let body = try JSONEncoder().encode(["password": password])
        let resp: [String: String] = try await request("/admin/unlock", method: "POST", body: body)
        return resp["token"] ?? ""
    }

    func triggerScan(adminToken: String) async throws {
        let url = baseURL.appendingPathComponent("api/admin/scan")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Admin \(adminToken)", forHTTPHeaderField: "Authorization")
        let (_, _) = try await session.data(for: req)
    }

    func scanStatus(adminToken: String) async throws -> ScanStatusResponse {
        let url = baseURL.appendingPathComponent("api/admin/scan/status")
        var req = URLRequest(url: url)
        req.setValue("Admin \(adminToken)", forHTTPHeaderField: "Authorization")
        let (data, _) = try await session.data(for: req)
        return try JSONDecoder().decode(ScanStatusResponse.self, from: data)
    }

    // MARK: - Health

    func healthCheck() async throws -> Bool {
        let url = baseURL.appendingPathComponent("api/health")
        let (_, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse else { return false }
        return http.statusCode == 200
    }
}

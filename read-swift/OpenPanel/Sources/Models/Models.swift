import Foundation

// MARK: - Library

struct Library: Codable, Identifiable, Sendable {
    let id: String
    let name: String
    let seriesCount: Int

    enum CodingKeys: String, CodingKey {
        case id, name
        case seriesCount = "series_count"
    }
}

struct LibrariesResponse: Codable, Sendable {
    let libraries: [Library]
}

// MARK: - Series

struct Series: Codable, Identifiable, Sendable {
    let id: String
    let name: String
    let bookCount: Int
    let bookType: String
    let year: Int?

    enum CodingKeys: String, CodingKey {
        case id, name, year
        case bookCount = "book_count"
        case bookType = "book_type"
    }
}

struct SeriesResponse: Codable, Sendable {
    let series: [Series]
    let total: Int
    let page: Int?
    let perPage: Int?

    enum CodingKeys: String, CodingKey {
        case series, total, page
        case perPage = "per_page"
    }
}

// MARK: - Book

struct Book: Codable, Identifiable, Sendable {
    let id: String
    let title: String
    let pageCount: Int
    let sortOrder: Int

    enum CodingKeys: String, CodingKey {
        case id, title
        case pageCount = "page_count"
        case sortOrder = "sort_order"
    }
}

struct BooksResponse: Codable, Sendable {
    let series: SeriesInfo
    let books: [Book]
}

struct SeriesInfo: Codable, Sendable {
    let id: String
    let name: String
}

struct BookDetail: Codable, Identifiable, Sendable {
    let id: String
    let title: String
    let seriesId: String
    let seriesName: String
    let pageCount: Int
    let fileSize: Int
    let metadata: BookMetadata

    enum CodingKeys: String, CodingKey {
        case id, title, metadata
        case seriesId = "series_id"
        case seriesName = "series_name"
        case pageCount = "page_count"
        case fileSize = "file_size"
    }
}

struct BookMetadata: Codable, Sendable {
    let writer: String?
    let year: Int?
    let summary: String?
}

// MARK: - Profile

struct Profile: Codable, Identifiable, Sendable {
    let id: String
    let name: String
    let hasPin: Bool

    enum CodingKeys: String, CodingKey {
        case id, name
        case hasPin = "has_pin"
    }
}

struct ProfilesResponse: Codable, Sendable {
    let profiles: [Profile]
}

struct ProfileSelectResponse: Codable, Sendable {
    let token: String
    let profile: Profile
}

// MARK: - Reading Progress

struct ReadingProgress: Codable, Sendable {
    let bookId: String
    let page: Int
    let isCompleted: Bool
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case page
        case bookId = "book_id"
        case isCompleted = "is_completed"
        case updatedAt = "updated_at"
    }
}

struct BatchProgressResponse: Codable, Sendable {
    let progress: [String: ReadingProgress]
}

// MARK: - Admin

struct AdminStatusResponse: Codable, Sendable {
    let isSetUp: Bool
    let isUnlocked: Bool

    enum CodingKeys: String, CodingKey {
        case isSetUp = "is_set_up"
        case isUnlocked = "is_unlocked"
    }
}

struct ScanStatusResponse: Codable, Sendable {
    let scanning: Bool
    let progress: String?
}

// MARK: - Page Manifest

struct PageManifest: Codable, Sendable {
    let bookId: String
    let pageCount: Int
    let pages: [PageInfo]

    enum CodingKeys: String, CodingKey {
        case bookId = "book_id"
        case pageCount = "page_count"
        case pages
    }
}

struct PageInfo: Codable, Sendable {
    let index: Int
    let filename: String
    let size: Int
}

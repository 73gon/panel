import SwiftUI

// MARK: - Reading Mode

enum ReadingMode: String, CaseIterable {
    case scroll = "Continuous Scroll"
    case singlePage = "Single Page"
}

enum ReadingDirection: String, CaseIterable {
    case ltr = "Left to Right"
    case rtl = "Right to Left"
}

// MARK: - Reader View

struct ReaderView: View {
    @EnvironmentObject var serverManager: ServerManager
    @Environment(\.dismiss) private var dismiss

    let bookId: String
    let seriesId: String
    let books: [Book]

    @State private var book: BookDetail?
    @State private var currentPage = 1
    @State private var totalPages = 0
    @State private var readingMode: ReadingMode = .scroll
    @State private var direction: ReadingDirection = .rtl
    @State private var showOverlay = false
    @State private var showSettings = false
    @State private var isLoading = true

    // Adjacent chapter navigation
    private var sortedBooks: [Book] {
        books.sorted { $0.sortOrder < $1.sortOrder }
    }
    private var currentIndex: Int? {
        sortedBooks.firstIndex { $0.id == bookId }
    }
    private var previousBookId: String? {
        guard let idx = currentIndex, idx > 0 else { return nil }
        return sortedBooks[idx - 1].id
    }
    private var nextBookId: String? {
        guard let idx = currentIndex, idx < sortedBooks.count - 1 else { return nil }
        return sortedBooks[idx + 1].id
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if isLoading {
                ProgressView()
                    .tint(.white)
            } else {
                Group {
                    switch readingMode {
                    case .scroll:
                        ScrollReaderContent(
                            bookId: bookId,
                            totalPages: totalPages,
                            direction: direction,
                            currentPage: $currentPage,
                            onTap: { showOverlay.toggle() }
                        )
                    case .singlePage:
                        SinglePageReaderContent(
                            bookId: bookId,
                            totalPages: totalPages,
                            direction: direction,
                            currentPage: $currentPage,
                            previousBookId: previousBookId,
                            nextBookId: nextBookId,
                            onTap: { showOverlay.toggle() }
                        )
                    }
                }
            }

            // Overlay
            if showOverlay {
                readerOverlay
            }
        }
        .navigationBarHidden(true)
        .statusBarHidden(!showOverlay)
        .ignoresSafeArea()
        .task { await loadBook() }
        .onChange(of: currentPage) { _, newPage in
            saveProgress(page: newPage)
        }
        .sheet(isPresented: $showSettings) {
            readerSettingsSheet
        }
    }

    // MARK: - Overlay

    private var readerOverlay: some View {
        VStack {
            // Top bar
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(10)
                        .background(.black.opacity(0.5), in: Circle())
                }

                Spacer()

                VStack(spacing: 2) {
                    Text(book?.title ?? "")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.white)
                    Text("Page \(currentPage) / \(totalPages)")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.7))
                }

                Spacer()

                Button { showSettings = true } label: {
                    Image(systemName: "gearshape")
                        .font(.title3)
                        .foregroundStyle(.white)
                        .padding(10)
                        .background(.black.opacity(0.5), in: Circle())
                }
            }
            .padding(.horizontal)
            .padding(.top, 60)

            Spacer()

            // Bottom slider
            VStack(spacing: 8) {
                Slider(
                    value: Binding(
                        get: { Double(currentPage) },
                        set: { currentPage = Int($0) }
                    ),
                    in: 1...max(Double(totalPages), 1),
                    step: 1
                )
                .tint(.white)

                HStack {
                    if let prevId = previousBookId,
                       let prevBook = sortedBooks.first(where: { $0.id == prevId }) {
                        NavigationLink {
                            ReaderView(bookId: prevId, seriesId: seriesId, books: books)
                        } label: {
                            Label(prevBook.title, systemImage: "chevron.left")
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.7))
                                .lineLimit(1)
                        }
                    }

                    Spacer()

                    if let nextId = nextBookId,
                       let nextBook = sortedBooks.first(where: { $0.id == nextId }) {
                        NavigationLink {
                            ReaderView(bookId: nextId, seriesId: seriesId, books: books)
                        } label: {
                            Label(nextBook.title, systemImage: "chevron.right")
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.7))
                                .lineLimit(1)
                        }
                    }
                }
            }
            .padding()
            .padding(.bottom, 30)
            .background(
                LinearGradient(
                    colors: [.clear, .black.opacity(0.8)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
        }
        .background(
            Color.black.opacity(0.001)
                .onTapGesture { showOverlay = false }
        )
    }

    // MARK: - Settings Sheet

    private var readerSettingsSheet: some View {
        NavigationStack {
            Form {
                Section("Reading Mode") {
                    Picker("Mode", selection: $readingMode) {
                        ForEach(ReadingMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Direction") {
                    Picker("Direction", selection: $direction) {
                        ForEach(ReadingDirection.allCases, id: \.self) { dir in
                            Text(dir.rawValue).tag(dir)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    if direction == .rtl {
                        Label("Manga mode: swipe left to advance", systemImage: "arrow.left")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Label("Comic mode: swipe right to advance", systemImage: "arrow.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Reader Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { showSettings = false }
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Data Loading

    private func loadBook() async {
        guard let client = serverManager.apiClient else { return }
        isLoading = true
        do {
            let detail = try await client.fetchBookDetail(bookId: bookId)
            book = detail
            totalPages = detail.pageCount

            // Restore progress
            if let prog = try await client.fetchProgress(bookId: bookId) {
                if !prog.isCompleted {
                    currentPage = prog.page
                }
            }

            // Prefetch first few pages
            let urls = (1...min(5, totalPages)).map { client.pageURL(bookId: bookId, page: $0) }
            await ImageCache.shared.prefetch(urls: urls)
        } catch {
            // Error handled silently
        }
        isLoading = false
    }

    private func saveProgress(page: Int) {
        guard let client = serverManager.apiClient else { return }
        let completed = page >= totalPages
        Task {
            try? await client.updateProgress(bookId: bookId, page: page, isCompleted: completed)
        }
    }
}

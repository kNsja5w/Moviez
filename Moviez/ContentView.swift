//
//  ContentView.swift
//  Moviez
//
//  Created by Florian Lüdtke on 10.07.24.
//

import SwiftUI
import AppKit

// Modell für Film
struct Movie: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let rating: String
    let releaseYear: String
    let dateWatched: String
    let description: String
    let tags: [String]

    static func == (lhs: Movie, rhs: Movie) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// Modell für Fehlernachrichten
struct ErrorMessage: Identifiable {
    let id = UUID()
    let message: String
}

// Hauptansicht
struct ContentView: View {
    @State private var movies: [Movie] = []
    @State private var allMovies: [Movie] = []
    @State private var query: String = ""
    @State private var ratingThreshold: String = ""
    @State private var isRatingGreaterThan = true
    @State private var errorMessage: ErrorMessage?
    @State private var selectedTag: String?
    @State private var selectedMovie: Movie?
    @State private var isAddingMovie = false
    @State private var txtFileURL: URL?

    var body: some View {
        VStack {
            HStack {
                TextField("Search...", text: $query)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 250)
                    .padding()
                Button(action: search) {
                    Text("Search")
                }
                .padding()
                Spacer()
                
                HStack {
                    Button(action: {
                        isRatingGreaterThan = false
                        filterByRating()
                    }) {
                        Text("Lower")
                    }
                    .padding()
                    .fixedSize()
                    
                    Button(action: {
                        isRatingGreaterThan = true
                        filterByRating()
                    }) {
                        Text("Higher")
                    }
                    .padding()
                    .fixedSize()
                    
                    TextField("Rating", text: $ratingThreshold)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 100)
                        .padding()
                }
                
                Button(action: clearFilter) {
                    Text("Delete Filter")
                }
                .padding()
            }

            List(selection: $selectedMovie) {
                if let selectedTag = selectedTag {
                    Text("Filtered by tag: \(selectedTag)")
                        .font(.headline)
                        .padding()
                }
                ForEach(movies) { movie in
                    VStack(alignment: .leading) {
                        Text(movie.title)
                            .font(.headline)
                        Text("Release Year: \(movie.releaseYear)")
                        Text("Date Watched: \(movie.dateWatched)")
                        Text("Rating: \(movie.rating)")
                        Text("Description: \(movie.description)")
                        Text("Tags: \(movie.tags.joined(separator: ", "))")
                            .italic()
                    }
                    .padding()
                    .background(selectedMovie == movie ? Color.gray.opacity(0.3) : Color.clear)
                    .cornerRadius(8)
                    .onTapGesture {
                        selectedMovie = movie
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button(action: {
                        openFilePanel()
                    }) {
                        Text("Import File")
                    }
                }
              
                ToolbarItem(placement: .automatic) {
                    Button(action: {
                        isAddingMovie = true
                    }) {
                        Text("Add Movie")
                    }
                }
                ToolbarItem(placement: .automatic) {
                    Button(action: deleteSelectedMovie) {
                        Text("Delete Movie")
                    }
                    .disabled(selectedMovie == nil)
                }
            }
        }
        .navigationTitle("Movies")
        .alert(item: $errorMessage) { error in
            Alert(title: Text("Error"), message: Text(error.message), dismissButton: .default(Text("OK")))
        }
        .sheet(isPresented: $isAddingMovie) {
            AddMovieView { newMovie in
                addMovie(newMovie)
            }
        }
    }

    func search() {
        // Filterung der Filme basierend auf der Abfrage
        if query.isEmpty {
            movies = allMovies
            return
        }

        movies = allMovies.filter { movie in
            movie.title.lowercased().contains(query.lowercased()) ||
            movie.description.lowercased().contains(query.lowercased()) ||
            movie.tags.contains(where: { $0.lowercased().contains(query.lowercased()) })
        }
    }

    func clearFilter() {
        selectedTag = nil
        query = ""
        ratingThreshold = ""
        movies = allMovies
    }

    func openFilePanel() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedFileTypes = ["txt"]

        panel.begin { response in
            if response == .OK, let url = panel.url {
                txtFileURL = url
                importFile(at: url)
            }
        }
    }

    func importFile(at url: URL) {
        do {
            let content = try String(contentsOf: url, encoding: .utf8)
            parseTXT(content: content)
        } catch {
            errorMessage = ErrorMessage(message: "Error reading the file: \(error.localizedDescription)")
        }
    }

    func parseTXT(content: String) {
        let movieBlocks = content.components(separatedBy: "Title:").dropFirst()
        var parsedMovies: [Movie] = []

        for block in movieBlocks {
            let title = extractMatch(for: "^\\s*(.*)", in: block)
            let rating = extractMatch(for: "Rating:\\s*(.*)", in: block)
            let releaseYear = extractMatch(for: "Release Year:\\s*(.*)", in: block)
            let dateWatched = extractMatch(for: "Date Watched:\\s*(.*)", in: block)
            let description = extractMatch(for: "Description:\\s*(.*)", in: block)
            let tags = extractMatch(for: "Tags:\\s*(.*)", in: block)?.components(separatedBy: " ") ?? []

            let movie = Movie(
                title: title ?? "",
                rating: rating ?? "",
                releaseYear: releaseYear ?? "",
                dateWatched: dateWatched ?? "",
                description: description ?? "",
                tags: tags
            )

            parsedMovies.append(movie)
        }

        allMovies = parsedMovies
        movies = parsedMovies
    }

    func extractMatch(for pattern: String, in text: String) -> String? {
        let regex = try? NSRegularExpression(pattern: pattern, options: [])
        let nsString = text as NSString
        let results = regex?.matches(in: text, options: [], range: NSRange(location: 0, length: nsString.length))
        return results?.first.map { nsString.substring(with: $0.range(at: 1)).trimmingCharacters(in: .whitespaces) }
    }

    func getAllUniqueTags(from movies: [Movie]) -> [String] {
        var tagsSet = Set<String>()
        for movie in movies {
            tagsSet.formUnion(movie.tags)
        }
        return Array(tagsSet).sorted()
    }

    func filterMovies(by tag: String) {
        selectedTag = tag
        movies = allMovies.filter { $0.tags.contains(tag) }
    }

    func filterByRating() {
        guard let threshold = Int(ratingThreshold), threshold >= 0 && threshold <= 100 else {
            errorMessage = ErrorMessage(message: "Please type in a rating between 0 and 100.")
            return
        }
        
        if isRatingGreaterThan {
            movies = allMovies.filter { Int($0.rating) ?? 0 >= threshold }
        } else {
            movies = allMovies.filter { Int($0.rating) ?? 0 <= threshold }
        }
    }

    func addMovie(_ newMovie: Movie) {
        guard let url = txtFileURL else { return }

        let newMovieText = """
        Title: \(newMovie.title)
        Rating: \(newMovie.rating)
        Release Year: \(newMovie.releaseYear)
        Date Watched: \(newMovie.dateWatched)
        Description: \(newMovie.description)
        Tags: \(newMovie.tags.joined(separator: " "))
        
        """

        do {
            var currentTXT = try String(contentsOf: url, encoding: .utf8)
            if !currentTXT.contains("Movies and Series 2024") {
                currentTXT = "Movies and Series 2024\n\n" + currentTXT
            }
            if let headerRange = currentTXT.range(of: "Movies and Series 2024\n\n") {
                currentTXT.insert(contentsOf: newMovieText + "\n\n", at: headerRange.upperBound)
            } else {
                currentTXT = newMovieText + "\n\n" + currentTXT
            }
            try currentTXT.write(to: url, atomically: true, encoding: .utf8)
            importFile(at: url)
        } catch {
            errorMessage = ErrorMessage(message: "Error adding the Movie: \(error.localizedDescription)")
        }
    }

    func deleteSelectedMovie() {
        guard let selectedMovie = selectedMovie, let url = txtFileURL else { return }

        do {
            var currentTXT = try String(contentsOf: url, encoding: .utf8)
            if let range = currentTXT.range(of: selectedMovieTXTText(selectedMovie)) {
                currentTXT.removeSubrange(range)
                try currentTXT.write(to: url, atomically: true, encoding: .utf8)
                importFile(at: url)
            }
        } catch {
            errorMessage = ErrorMessage(message: "Error deleting the movie: \(error.localizedDescription)")
        }
    }

    func selectedMovieTXTText(_ movie: Movie) -> String {
        return """
        Title: \(movie.title)
        Rating: \(movie.rating)
        Release Year: \(movie.releaseYear)
        Date Watched: \(movie.dateWatched)
        Description: \(movie.description)
        Tags: \(movie.tags.joined(separator: " "))
        
        """
    }
}

// Tag-Liste Ansicht
struct TagListView: View {
    let tags: [String]
    var onSelectTag: (String) -> Void

    var body: some View {
        List(tags, id: \.self) { tag in
            Button(action: {
                onSelectTag(tag)
            }) {
                Text(tag)
            }
        }
        .navigationTitle("Tags")
    }
}

// Ansicht zum Hinzufügen eines Films
struct AddMovieView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var title = ""
    @State private var rating = ""
    @State private var releaseYear = ""
    @State private var dateWatched = ""
    @State private var description = ""
    @State private var tags = ""

    var onAdd: (Movie) -> Void

    var body: some View {
        NavigationView {
            Form {
                VStack(alignment: .leading) { // Setzt die Ausrichtung auf linksbündig
                    TextField("Title", text: $title)
                        .padding(.vertical, 5)
                    TextField("Rating", text: $rating)
                        .padding(.vertical, 5)
                    TextField("Release Year", text: $releaseYear)
                        .padding(.vertical, 5)
                    TextField("Date Watched", text: $dateWatched)
                        .padding(.vertical, 5)
                    TextField("Description", text: $description)
                        .padding(.vertical, 5)
                    TextField("Tags (separated by space)", text: $tags)
                        .padding(.vertical, 5)
                }
                .padding(50) // Fügt 50px Padding um den Inhalt hinzu
            }
            .navigationTitle("New Movie")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    HStack {
                        Button("Cancel") {
                            presentationMode.wrappedValue.dismiss()
                        }
                        Button(action: addMovie) {
                            Text("Add")
                        }
                    }
                }
            }
        }
        .frame(minWidth: 400, minHeight: 500) // Mindestgröße für bessere Responsivität
    }

    func addMovie() {
        let newMovie = Movie(title: title, rating: rating, releaseYear: releaseYear, dateWatched: dateWatched, description: description, tags: tags.components(separatedBy: " "))
        onAdd(newMovie)
        presentationMode.wrappedValue.dismiss()
    }
}







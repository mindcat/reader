//
//  TagSearch.swift
//  reader
//
//  Created by Jacob Carryer on 3/20/25.
//

import Foundation
import SwiftUI
import Flow

struct TagResult: Codable, Hashable {
    var id: String
    var name: String
}

class TagSearchField: ObservableObject {
    @Published var text: String = ""
    @Published var debounce_text: String = ""
    
    init() {
        $text
            .debounce(for: .seconds(1), scheduler: RunLoop.main)
            .assign(to: &$debounce_text)
    }
    
    func perform_search(search_type: String) async -> [TagResult] {
        let url_str = "https://archiveofourown.org/autocomplete/\(search_type)?term=\(debounce_text)"
        let url = URL(string: url_str)!
        
        var search_results: [TagResult] = []
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoder = JSONDecoder()
            search_results = try decoder.decode([TagResult].self, from: data)
        } catch {
            print(error)
        }
        
        return search_results
    }
}

struct TagSearch: View {
    @Binding var selected_tags: [String]
    @State var search_text: String = ""
    @State var search_results: [TagResult] = []
    @StateObject var search_field: TagSearchField = TagSearchField()
    let search_type: String
    
    var body: some View {
        VStack {
            HFlow {
                ForEach(selected_tags.indices, id: \.self) { index in
                    Label(selected_tags[index], systemImage: "tag")
                        .font(.caption)
                        .labelStyle(.titleOnly)
                        .padding(5)
                        .overlay {
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .stroke(.gray, lineWidth: 1)
                        }
                        .onTapGesture {
                            selected_tags.remove(at: index)
                        }
                }
            }
            .padding(.top)
            
            List {
                ForEach(search_results, id: \.self) { tag in
                    Text(tag.name)
                        .onTapGesture {
                            selected_tags.append(tag.name)
                        }
                }
            }
            .searchable(text: $search_field.text, placement: .navigationBarDrawer(displayMode: .always))
            .onSubmit(of: .search) {
                // append new tag, and clear text
                if !search_field.text.isEmpty {
                    selected_tags.append(search_field.text)
                }
                search_field.text = ""
            }
        }
        .onChange(of: search_field.debounce_text) { old, new in
            // only search if not empty
            if !new.isEmpty {
                Task {
                    search_results = await search_field.perform_search(search_type: search_type)
                }
            }
        }
    }
}

#Preview {
    @Previewable @State var tags: [String] = ["sample tag"]
    @Previewable @State var text: String = ""
    @Previewable @State var results: [TagResult] = [TagResult(id: "1", name: "tag 1"), TagResult(id: "2", name: "tag 2")]
    
    NavigationStack {
        TagSearch(selected_tags: $tags, search_results: results, search_type: "freeform")
    }
    .preferredColorScheme(.dark)
}

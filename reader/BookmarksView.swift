//
//  BookmarksView.swift
//  reader
//
//  Created by Jacob Carryer on 4/3/25.
//

import Foundation
import SwiftUI
import SwiftSoup

struct BookmarksView: View {
    @Binding var current_user: String
    @State private var loading: Bool = true
    @State private var results: [WorkStub] = []
    @State private var active_work_stub: WorkStub?
    @State private var preview_sheet: Bool = false
    @State private var toast: Toast?
    @Environment(\.modelContext) private var context

    func load_bookmarks() async {
        results = []
        let url_str = "https://archiveofourown.org/users/\(current_user)/bookmarks"
        let url = URL(string: url_str)!
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let contents = String(data: data, encoding: .utf8) else { return }
            
            let doc: Document = try SwiftSoup.parse(contents)
            let bookmarks = try doc.select("ol.bookmark.index.group > li[role=article]")
            for bookmark in bookmarks {
                let classes_str = try bookmark.attr("class")
                let classes = classes_str.components(separatedBy: .whitespacesAndNewlines)
                var work_class = classes[3] // TODO: maybe need to filter for this class instead of hard code index
                work_class.trimPrefix("work-")
                let work_id = Int(work_class)!
                
                let stub = WorkStub(work_id: work_id)
                results.append(stub)
            }
        } catch {
            print(error)
        }
        
        loading = false
    }
    
    var body: some View {
        if !loading {
            List {
                ForEach(results) {stub in
                    WorkCard(work_stub: stub, search_mode: true)
                        .labelStyle(.titleAndIcon)
                        .onTapGesture {
                            active_work_stub = stub
                            preview_sheet = true
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button() {
                                context.insert(stub)
                                try? context.save()
                                toast = Toast(system_icon: "bookmark.fill", message: "Added", color: .green)
                            } label: {
                                Label("Add", systemImage: "bookmark.fill")
                                    .labelStyle(.iconOnly)
                            }
                            .tint(.green)
                        }
                }
            }
            .navigationTitle("Bookmarks")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $preview_sheet) {
                WorkPreview(work_stub: $active_work_stub)
            }
            .onChange(of: toast) {old, new in
                guard let t = new else { return }
                toast = t
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    toast = nil
                }
            }
            .preference(key: ToastPreferenceKey.self, value: toast)
        } else {
            ProgressView()
                .frame(maxWidth: .infinity, alignment: .center)
                .task {
                    await load_bookmarks()
                }
        }
    }
}

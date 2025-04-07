//
//  WorkPreview.swift
//  reader
//
//  Created by Jacob Carryer on 3/21/25.
//

import Foundation
import SwiftUI
import SwiftData
import SwiftSoup
import Flow

struct WorkPreview: View {
    @Binding var work_stub: WorkStub?
    @State var show_summary: Bool = true
    @State var show_tags: Bool = true
    @State var series_sheet: Bool = false
    @State private var toast: Toast?

    func bookmark_work(work_id: Int) async {
        let url_str = "https://archiveofourown.org/works/\(work_id)?view_adult=true&view_full_work=true"
        let url = URL(string: url_str)!
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let contents = String(data: data, encoding: .utf8) else { return }
            let doc: Document = try SwiftSoup.parse(contents)
            
            // setup request components
            var components = URLComponents(string: "https://archiveofourown.org/works/\(work_id)/bookmarks")!
            components.queryItems = []

            // get authenticity token
            if let token_element = try doc.select("meta[name=csrf-token]").first() {
                let token = try token_element.attr("content")
                // self.auth_token = token
                components.queryItems?.append(URLQueryItem(name: "authenticity_token", value: token))
            } else {
                return
            }
            
            // get bookmark pseud_id
            if let pseud_element = try doc.select("#bookmark_pseud_id").first() {
                let pseud_id = try pseud_element.attr("value")
                components.queryItems?.append(URLQueryItem(name: "bookmark[pseud_id]", value: pseud_id))
            } else {
                return
            }
            
            // fill in rest of request items
            components.queryItems?.append(URLQueryItem(name: "bookmark[bookmarker_notes]", value: ""))
            components.queryItems?.append(URLQueryItem(name: "bookmark[tag_string]", value: ""))
            components.queryItems?.append(URLQueryItem(name: "bookmark[collection_names]", value: ""))
            components.queryItems?.append(URLQueryItem(name: "bookmark[private]", value: "0"))
            components.queryItems?.append(URLQueryItem(name: "bookmark[private]", value: "1"))
            components.queryItems?.append(URLQueryItem(name: "bookmark[rec]", value: "0"))
            components.queryItems?.append(URLQueryItem(name: "commit", value: "Create"))
            
            // make request
            let req_url = components.url!
            var req = URLRequest(url: req_url)
            req.httpMethod = "POST"
            req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            
            let (req_data, _) = try await URLSession.shared.data(for: req)
            guard let req_contents = String(data: req_data, encoding: .utf8) else { return }
            
            // check response
            let req_doc: Document = try SwiftSoup.parse(req_contents)
            if (try req_doc.select("div.flash.notice").first()) != nil {
                self.toast = Toast(system_icon: "bookmark.fill", message: "Bookmark Created", color: .green)
            } else {
                self.toast = Toast(system_icon: "exclamationmark.triangle.fill", message: "Error Creating Bookmark", color: .yellow)
            }
        } catch {
            print(error)
        }
    }
    
    var body: some View {
        if let work_stub {
            if work_stub.stub_loaded {
                let sorted = work_stub.tags.sorted(by: {$0.value.sort_index < $1.value.sort_index})
                NavigationStack {
                    ScrollView {
                        VStack {
                            Text("Published: \(work_stub.stats.published)")
                            if !work_stub.stats.updated.isEmpty {
                                Text("Updated: \(work_stub.stats.updated)")
                            } else if !work_stub.stats.completed.isEmpty {
                                Text("Completed: \(work_stub.stats.completed)")
                            }
                        }.padding(.top)
                        DisclosureGroup("Summary", isExpanded: $show_summary) {
                            VStack(alignment: .leading) {
                                ForEach(work_stub.summary, id: \.self) {paragraph in
                                    Text(.init(paragraph))
                                }
                            }.padding()
                        }.padding([.horizontal, .top])
                        DisclosureGroup("Tags:", isExpanded: $show_tags) {
                            VStack(alignment: .leading) {
                                ForEach(sorted, id: \.self.value.hashValue) {group in
                                    Text(group.key).foregroundStyle(.secondary)
                                    HFlow {
                                        ForEach(group.value.tags, id: \.self) {tag in
                                            Label(tag, systemImage: "tag")
                                                .font(.caption)
                                                .labelStyle(.titleOnly)
                                                .padding(5)
                                                .overlay {
                                                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                                                        .stroke(.gray, lineWidth: 1)
                                                }
                                        }
                                    }
                                }
                                
                                if let series = work_stub.series {
                                    Text("Series:").foregroundStyle(.secondary)
                                    HStack {
                                        Text(series.prefix)
                                        Button(series.name) {
                                            series_sheet = true
                                        }
                                    }
                                }
                            }.padding()
                        }
                        .padding([.horizontal, .bottom])
                        .preference(key: ToastPreferenceKey.self, value: toast)
                    }
                    .sheet(isPresented: $series_sheet) {
                        SeriesView(series_id: work_stub.series!.series_id, series_title: work_stub.series!.name)
                    }
                    .onChange(of: toast) {old, new in
                        guard let t = new else { return }
                        toast = t
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            toast = nil
                        }
                    }
                    .toaster()
                    .toolbar {
                        ToolbarItemGroup {
                            Button("Bookmark") {
                                // print("bookmark button")
                                Task {
                                    await bookmark_work(work_id: work_stub.work_id)
                                }
                            }
                        }
                    }
                }
            }
        } else {
            ProgressView()
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }
}

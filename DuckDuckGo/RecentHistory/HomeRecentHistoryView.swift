//
//  AppIconView.swift
//  DuckDuckGo
//
//  Copyright 2025 DuckDuckGo. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import SwiftUI
import History

struct RecentHistoryItemView: View {
    let history: HistoryEntry
    var onRemove: () -> Void = {}
    var onRemoveAll: () -> Void = {}
    @ObserveInjection var redraw

    var body: some View {
        VStack(spacing: 8) {
            FaviconImage(domain: history.host)
                .padding(6)
                .frame(width: 32, height: 32)
                .padding(8)
                .background(Color(.white))
                .clipShape(Circle())

            Text(history.displayTitle)
                .font(.system(size: 11))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .foregroundColor(.white)
        }
        .frame(width: 60)
        .contextMenu {
            Button("Remove from Recent") {
                onRemove()
            }
            Button("Remove All") {
                onRemoveAll()
            }
        }
        .enableInjection()
    }
}

struct HomeRecentHistoryView: View {
    let histories: [HistoryEntry]
    var didTap: (HistoryEntry) -> Void = { _ in }
    var onRemoveHistory: (HistoryEntry) -> Void = { _ in }
    var onRemoveAllHistories: () -> Void = {}
    @ObserveInjection var redraw
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(alignment: .top, spacing: 16) {
                ForEach(histories) { history in
                    RecentHistoryItemView(history: history,
                                        onRemove: { onRemoveHistory(history) },
                                        onRemoveAll: onRemoveAllHistories)
                        .onTapGesture {
                            print("tapped \(history.host)")
                            didTap(history)
                        }
                }
            }
            .padding(.top, 16)
            .padding(.horizontal, 8)
        }
        .background(Color(uiColor: .black.withAlphaComponent(0.5)))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .enableInjection()
    }
}

private extension HistoryEntry {

    var displayTitle: String {
        if let title = title?.trimmingWhitespace() {
            return title
        }

        if let host = url.host?.droppingWwwPrefix() {
            return host
        }

        assertionFailure("Unable to create display title")
        return ""
    }

    var host: String {
        return url.host ?? ""
    }

}

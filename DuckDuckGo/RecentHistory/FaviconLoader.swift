//
//  FaviconLoader.swift
//  DuckDuckGo
//
//  Copyright © 2025 DuckDuckGo. All rights reserved.
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
import Combine

class FaviconLoader: ObservableObject {
    @Published var image: UIImage?

    private static var cache = NSCache<NSString, UIImage>()

    init(domain: String?) {
        guard let domain = domain else { return }
        loadFavicon(for: domain)
    }

    private func loadFavicon(for domain: String) {
        if let cachedImage = Self.cache.object(forKey: domain as NSString) {
            self.image = cachedImage
            return
        }
        
        let urlString = "https://www.google.com/s2/favicons?domain=\(domain)&sz=128"
        guard let url = URL(string: urlString) else { return }

        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let self = self,
                  let data = data,
                  let uiImage = UIImage(data: data) else {
                DispatchQueue.main.async {
                    let fakeFavicon = FaviconsHelper.createFakeFavicon(forDomain: domain,
                                                                       size: 30,
                                                                       backgroundColor: UIColor.forDomain(domain),
                                                                       bold: false)
                    if let fakeFavicon = fakeFavicon {
                        Self.cache.setObject(fakeFavicon, forKey: domain as NSString)
                        self?.image = fakeFavicon
                    }
                }
                return
            }
            DispatchQueue.main.async {
                Self.cache.setObject(uiImage, forKey: domain as NSString)
                self.image = uiImage
            }
        }.resume()
    }
}

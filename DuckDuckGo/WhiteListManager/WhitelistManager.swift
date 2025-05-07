// swiftlint:disable inclusive_language

//
//  WhitelistManager.swift
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

import Foundation

public class WhitelistManager {
    // MARK: - Singleton
    public static let shared = WhitelistManager()
    
    // MARK: - Constants
    private let whitelistURL = "https://raw.githubusercontent.com/Kahf-Browser/public/refs/heads/main/config/whitelist.txt"
    private let cacheFileName = "whitelist_cache.txt"
    private let cacheValidityDuration: TimeInterval = 24 * 60 * 60
    
    // MARK: - Properties
    private(set) var whitelistedURLs: [String] = []
    private let fileManager = FileManager.default
    
    private init() {
        loadWhitelist()
    }
    
    // MARK: - Public Methods
    
    /// Loads whitelist either from cache or remote URL based on cache validity
    public func loadWhitelist() {
        if shouldRefreshCache() {
            Task {
                await fetchAndSaveWhitelist()
            }
        } else {
            loadFromCache()
        }
    }
    
    /// Checks if a given URL is whitelisted
    public func isWhitelisted(_ urlString: String) -> Bool {
        return whitelistedURLs.contains(where: { $0.contains(urlString) })
    }
    
    // MARK: - Private Methods
    
    private func getCacheURL() -> URL? {
        guard let cacheDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            return nil
        }
        return cacheDirectory.appendingPathComponent(cacheFileName)
    }
    
    private func shouldRefreshCache() -> Bool {
        guard let cacheURL = getCacheURL(),
              let attributes = try? fileManager.attributesOfItem(atPath: cacheURL.path),
              let modificationDate = attributes[.modificationDate] as? Date else {
            return true
        }
        
        let timeSinceLastUpdate = Date().timeIntervalSince(modificationDate)
        return timeSinceLastUpdate > cacheValidityDuration
    }
    
    private func loadFromCache() {
        guard let cacheURL = getCacheURL(),
              let content = try? String(contentsOf: cacheURL, encoding: .utf8) else {
            return
        }
        
        whitelistedURLs = content.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
    
    private func fetchAndSaveWhitelist() async {
        guard let url = URL(string: whitelistURL) else { return }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let content = String(data: data, encoding: .utf8) else { return }
            
            let urls = content.components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            
            // Save to cache
            if let cacheURL = getCacheURL() {
                try content.write(to: cacheURL, atomically: true, encoding: .utf8)
            }
            
            // Update in memory
            await MainActor.run {
                self.whitelistedURLs = urls
            }
        } catch {
            debugPrint("Error fetching whitelist: \(error)")
        }
    }
}

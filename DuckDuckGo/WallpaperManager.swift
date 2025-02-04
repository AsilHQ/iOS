//
//  WallpaperManager.swift
//  Kahf Browser
//
//  Copyright © 2024 Kahf Browser. All rights reserved.
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
import UIKit
import CryptoKit

struct Wallpaper: Codable {
    let name: String
    let downloadUrl: String
    let title: String
    let subtitle: String
    let credit: String
    let url: String
    
    enum CodingKeys: String, CodingKey {
        case name
        case downloadUrl = "download_url"
        case title
        case subtitle
        case credit
        case url
    }
}

class WallpaperManager {
    static var filesDir: URL {
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    private static let metadataFileName = "wallpapers_metadata.json"
    
    // Save metadata to local storage
    private static func saveMetadata(_ wallpapers: [Wallpaper]) {
        let metadataUrl = filesDir.appendingPathComponent(metadataFileName)
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(wallpapers)
            try data.write(to: metadataUrl)
            print("WallpaperManager: metadata saved successfully")
        } catch {
            print("WallpaperManager: failed to save metadata: \(error)")
        }
    }
    
    // Load metadata from local storage
    private static func loadMetadata() -> [Wallpaper] {
        let metadataUrl = filesDir.appendingPathComponent(metadataFileName)
        do {
            let data = try Data(contentsOf: metadataUrl)
            let decoder = JSONDecoder()
            return try decoder.decode([Wallpaper].self, from: data)
        } catch {
            print("WallpaperManager: failed to load metadata: \(error)")
            return []
        }
    }
    
    private static func downloadImages(wallpapers: [Wallpaper]) {
        let shuffledWallpapers = wallpapers.shuffled()
        var downloadedCount = 0
        
        for wallpaper in shuffledWallpapers {
            let fileName = getFileNameFromUrl(url: wallpaper.downloadUrl)
            let file = filesDir.appendingPathComponent("wp").appendingPathComponent(fileName)
            
            if !FileManager.default.fileExists(atPath: file.deletingLastPathComponent().path) {
                try? FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            }
            
            if FileManager.default.fileExists(atPath: file.path) {
                print("WallpaperManager: File already exists: \(file.path)")
                continue
            }
            
            do {
                guard let url = URL(string: wallpaper.downloadUrl) else { continue }
                let imageData = try Data(contentsOf: url)
                if let image = UIImage(data: imageData),
                   let data = image.jpegData(compressionQuality: 1.0) {
                    try data.write(to: file)
                    print("WallpaperManager: image saved: \(file.path)")
                }
                downloadedCount += 1
                if downloadedCount >= 3 {
                    break
                }
            } catch {
                print("WallpaperManager: failed to download image from: \(wallpaper.downloadUrl)")
            }
        }
    }
    
    private static func getFileNameFromUrl(url: String) -> String {
        guard let data = url.data(using: .utf8) else { return "" }
        let hash = Insecure.MD5.hash(data: data)
        return hash.map { String(format: "%02hhx", $0) }.joined()
    }
    
    static func fetchWallpapers() {
        let jsonUrl = URL(string: "https://raw.githubusercontent.com/Kahf-Browser/public/main/wallpapers/labels.json")!
        
        DispatchQueue.global().async {
            do {
                let jsonData = try Data(contentsOf: jsonUrl)
                let decoder = JSONDecoder()
                let wallpapers = try decoder.decode([Wallpaper].self, from: jsonData)
                
                print("WallpaperManager: wallpaper's list downloaded successfully")
                saveMetadata(wallpapers)
                downloadImages(wallpapers: wallpapers)
            } catch {
                print("WallpaperManager: error downloading wallpaper's list: \(error)")
            }
        }
    }
    
    // Get a random wallpaper with its metadata
    static func getRandomWallpaper() -> (image: UIImage?, metadata: Wallpaper?) {
        let metadata = loadMetadata()
        guard !metadata.isEmpty else {
            return (nil, nil)
        }
        
        var attemptedWallpapers = Set<String>()
        
        while attemptedWallpapers.count < metadata.count {
            guard let randomWallpaper = metadata.randomElement(),
                  !attemptedWallpapers.contains(randomWallpaper.downloadUrl) else {
                continue
            }
            
            attemptedWallpapers.insert(randomWallpaper.downloadUrl)
            
            let fileName = getFileNameFromUrl(url: randomWallpaper.downloadUrl)
            let file = filesDir.appendingPathComponent("wp").appendingPathComponent(fileName)
            
            if let data = try? Data(contentsOf: file),
               let image = UIImage(data: data) {
                return (image, randomWallpaper)
            }
        }
        return (nil, nil)
    }
}
extension WallpaperManager {
    static func createAttributedString(from text: String) -> NSAttributedString? {
        return try? NSAttributedString(
            data: Data(text.utf8),
            options: [
                .documentType: NSAttributedString.DocumentType.html,
                .characterEncoding: String.Encoding.utf8.rawValue
            ],
            documentAttributes: nil
        )
    }
}

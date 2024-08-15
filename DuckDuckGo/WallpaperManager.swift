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

class WallpaperManager {
    
    static var filesDir: URL {
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    /**
     * If there are multiple images in the list, randomly download only 3 to avoid high data consumption at first launch
     */
    private static func downloadImages(urls: [String]) {
        let shuffledUrls = urls.shuffled() // Shuffle the list of URLs to pick randomly
        var downloadedCount = 0
        
        for url in shuffledUrls {
            let fileName = getFileNameFromUrl(url: url)
            let file = filesDir.appendingPathComponent("wp").appendingPathComponent(fileName)
            
            if !FileManager.default.fileExists(atPath: file.deletingLastPathComponent().path) {
                try? FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            }
            
            // Check if the file already exists
            if FileManager.default.fileExists(atPath: file.path) {
                print("WallpaperManager: File already exists: \(file.path)")
                continue
            }
            
            // Download and save the image
            do {
                let imageData = try Data(contentsOf: URL(string: url)!)
                if let image = UIImage(data: imageData) {
                    if let data = image.jpegData(compressionQuality: 1.0) {
                        try data.write(to: file)
                        print("WallpaperManager: image saved: \(file.path)")
                    }
                }
                downloadedCount += 1
                if (downloadedCount >= 3) {
                    break
                }
            } catch {
                print("WallpaperManager: failed to download image from: \(url)")
            }
        }
    }
    
    private static func getFileNameFromUrl(url: String) -> String {
        guard let data = url.data(using: .utf8) else { return "" }
        let hash = Insecure.MD5.hash(data: data)
        return hash.map { String(format: "%02hhx", $0) }.joined()
    }
    
    static func fetchWallpapers() {
        let jsonUrl = URL(string: "https://api.github.com/repos/Kahf-Browser/public/contents/wallpapers?ref=main")!
        
        DispatchQueue.global().async {
            do {
                let jsonData = try Data(contentsOf: jsonUrl)
                let jsonArray = try JSONSerialization.jsonObject(with: jsonData, options: []) as! [[String: Any]]
                
                print("WallpaperManager: wallpaper's list downloaded successfully.")
                let urls = jsonArray.compactMap { $0["download_url"] as? String }
                downloadImages(urls: urls)
            } catch {
                print("WallpaperManager: error downloading wallpaper's list: \(error)")
            }
        }
    }
    
    static func getSavedImagePaths() -> [URL] {
        let wpDir = filesDir.appendingPathComponent("wp")
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(at: wpDir, includingPropertiesForKeys: nil)
            return fileURLs
        } catch {
            print("WallpaperManager: error while fetching image paths: \(error)")
            return []
        }
    }
    
    static func loadImageFrom(path: URL) -> UIImage? {
        if let data = try? Data(contentsOf: path) {
            return UIImage(data: data)
        }
        return nil
    }
}

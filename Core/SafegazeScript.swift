//  SafegazeScript.swift
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
import WebKit
import UserScript
import Vision
import SafeGaze_iOS

public class SafegazeScript: NSObject, UserScript {
    
    // MARK: - Singleton
    public static let shared = SafegazeScript()
    
    public var source: String = {
        let sendMessage = """
                            function sendMessageToIOS(messageType, data) {
                                webkit.messageHandlers.safegazeMessage.postMessage(messageType);
                            }
                            sendMessageToIOS("Script injection completed", "dummy data");
                          """
        //        guard var script = SafegazeScript.loadJavaScript(named: "Safegaze") else {
        //            return sendMessage
        //        }
        guard var script = SafegazeScript.loadJavaScript(named: "test") else {
            debugPrint("video_filter not found")
            return sendMessage
        }
        
        return script
    }()
    
    public var messageNames: [String] = ["safegazeMessage"]
    public let injectionTime: WKUserScriptInjectionTime = .atDocumentEnd
    public let forMainFrameOnly = true
    public let requiresRunInPageContentWorld = true
    
    public var increaseSafegazeBlurredImageCount: (() -> Void)?
    
    private let imageProcessingSemaphore = DispatchSemaphore(value: 1)
    private let imageProcessingQueue = DispatchQueue(label: "com.kahf.imageProcessing", qos: .userInitiated)
    
    // Private initializer
    private override init() {
        super.init()
    }
    
    // Make helper methods static since they don't need instance access
    //    static func loadUserScriptFileManager(named: String) -> String? {
    //        let fileManager = FileManager.default
    //        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
    //        let localFileURL = documentsURL.appendingPathComponent(named).appendingPathExtension("js").path
    //
    //        do {
    //            // Attempt to load the file contents
    //            let source = try String(contentsOfFile: localFileURL, encoding: .utf8)
    //            return source
    //        } catch {
    //            // Log error and handle failure
    //            assertionFailure("Failed to Load Script: \(named).js - \(error.localizedDescription)")
    //            return nil
    //        }
    //    }
    
    static func loadJavaScript(named fileName: String) -> String? {
        guard let path = Bundle.main.path(forResource: fileName, ofType: "js") else {
            debugPrint("[SafegazeScript] JavaScript file \(fileName) not found in bundle.")
            return nil
        }
        
        do {
            let script = try String(contentsOfFile: path, encoding: .utf8)
            return script
        } catch {
            debugPrint("[SafegazeScript] Failed to load JavaScript file: \(error.localizedDescription)")
            return nil
        }
    }
    
    public static func downloadAndSaveJavaScriptFile() {
#if DEBUG
        let urlString = "https://raw.githubusercontent.com/AsilHQ/Android/js_code_dev/node_modules/%40duckduckgo/privacy-dashboard/build/app/safe_gaze_v2.js"
#else
        let urlString = "https://raw.githubusercontent.com/AsilHQ/Android/js_code_release/node_modules/%40duckduckgo/privacy-dashboard/build/app/safe_gaze_v2.js"
#endif
        
        let remoteHostFileURL = URL(string: urlString)!
        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let localFileURL = documentsURL.appendingPathComponent("SafegazeScript.js")
        
        // Create the download task
        let task = URLSession.shared.dataTask(with: remoteHostFileURL) { data, _, error in
            if let error = error {
                debugPrint("[SafegazeScript] Failed to download file: \(error)")
                return
            }
            
            guard let data = data else {
                debugPrint("[SafegazeScript] No data downloaded.")
                return
            }
            
            do {
                // Write the downloaded data to the file
                try data.write(to: localFileURL)
                debugPrint("[SafegazeScript] JavaScript file downloaded and saved successfully.")
            } catch {
                debugPrint("[SafegazeScript] Failed to save JavaScript file: \(error)")
            }
        }
        task.resume()
    }
    
    private func asyncDownloadImage(from imageURL: URL) async -> Data? {
        do {
            let (data, _) = try await URLSession.shared.data(from: imageURL)
            return data
        } catch {
            debugPrint("[SafegazeScript] Error downloading image: \(error.localizedDescription)")
            return nil
        }
    }
    
    struct ImageData: Codable {
        let src: String
        let id: String
        let width: Int
        let height: Int
    }
    
    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        
        guard let body = message.body as? [String: Any],
              let dataString = body["data"] as? String,
              let messageType = body["messageType"] as? String,
              messageType == "detectImg" else {
            print("❌ Invalid message format")
            return
        }
        
        guard let innerData = dataString.data(using: .utf8) else {
            print("❌ Failed to convert inner JSON string to Data \(dataString)")
            return
        }
        
        do {
            let imageData = try JSONDecoder().decode(ImageData.self, from: innerData)
            print("📥 Received image: src: \(imageData.src), id: \(imageData.id), width: \(imageData.width), height: \(imageData.height)")
            
            guard let url = URL(string: imageData.src) else {
                print("❌ Failed to convert image URL string to URL \(imageData.src)")
                return
            }
            
            Task {
                await ImageProcessingQueue.shared.enqueueProcessing(
                    url: url,
                    id: imageData.id,
                    webView: message.webView!,
                    frameInfo: message.frameInfo
                )
            }
        } catch {
            print("❌ Failed to decode inner JSON:", error)
        }
    }
}

extension UIImage {
    var base64: String? {
        self.jpegData(compressionQuality: 0.6)?.base64EncodedString()
    }
}

public actor ImageProcessingQueue {
    static let shared = ImageProcessingQueue()
    var index = 0
    private let visionTools = ImageProcessor.shared
    
    func enqueueProcessing(url: URL, id: String, webView: WKWebView, frameInfo: WKFrameInfo) async {
        let base64 = await downloadAndProcessImage(from: url)
        let base64Prefix = base64 != nil ? "data:image/png;base64," : "null"
        let jsResult = base64 != nil ? "\(base64Prefix)\(base64!)" : base64Prefix

        let jsString = """
        (function() {
            receiveMessageFromKotlin("detectionResult", "{\\\"result\\\": \\\"\(jsResult)\\\", \\\"id\\\": \\\"\(id)\\\"}");
        })();
        """
        
        await MainActor.run {
            webView.evaluateJavaScript(jsString, in: frameInfo, in: .page) { result in
                switch result {
                case .failure(let error):
                    debugPrint("[SafegazeScript] evaluateJavaScript failed: \(error)")
                case .success:
                    break
                }
            }
        }
    }
    
    func downloadAndProcessImage(from imageURL: URL) async -> String? {
        debugPrint("downloadAndProcessImage url \(imageURL.absoluteString) start at \(Date())")

        if index < 1 {
            await visionTools.configure()
            index += 1
        }

        guard let imageData = await asyncDownloadImage(from: imageURL),
              let image = UIImage(data: imageData) else {
            return nil
        }

        let startDate = Int(Date().timeIntervalSince1970 * 1000)
        if let processedImage = await visionTools.processImage(image: image),
           let base64String = processedImage.base64 {
            let endDate = Int(Date().timeIntervalSince1970 * 1000)
            print("execution time, \(endDate - startDate)ms")
            debugPrint("got output image")
            return base64String
        } else {
            debugPrint("got no output image")
            return nil
        }
    }
    
    private func asyncDownloadImage(from imageURL: URL) async -> Data? {
        do {
            let (data, _) = try await URLSession.shared.data(from: imageURL)
            return data
        } catch {
            debugPrint("[SafegazeScript] Error downloading image: \(error.localizedDescription)")
            return nil
        }
    }
}

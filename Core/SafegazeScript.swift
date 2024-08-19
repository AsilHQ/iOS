//
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

public class SafegazeScript: NSObject, UserScript {

    public var source: String = {
        let sendMessage = """
                            window.blurIntensity = 1.0;
                          
                            function sendMessage(message) {
                                webkit.messageHandlers.safegazeMessage.postMessage(message);
                            }
                          
                            window.sendMessage = sendMessage
                          
                            sendMessage("Script injection completed");
                          """
        guard var script = loadUserScriptFileManager(named: "SafegazeScript") else {
            return sendMessage // Add local js too
        }
        
        return sendMessage + script
    }()

    public var messageNames: [String] = ["safegazeMessage"]
    
    public let injectionTime: WKUserScriptInjectionTime = .atDocumentEnd
    public let forMainFrameOnly = true
    public let requiresRunInPageContentWorld = true
    
    let nsfwDetector = NsfwDetector()
    let genderDetector = GenderDetector()

    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if let messageString = message.body as? String {
            if messageString == "replaced" {
//                BraveGlobalShieldStats.shared.safegazeCount += 1
//                tab.contentBlocker.stats = tab.contentBlocker.stats.adding(safegazeCount: 1)
                // TODO: increase safegazeCount +1
            } else if messageString.contains("coreML") {
                let messageArray = messageString.components(separatedBy: "/-/")
                if messageArray.count == 3 {
                    if let url = URL(string: messageArray[1]) {
                        downloadAndProcessImage(from: url) { isBlur in
                            let jsString =
                            """
                                (function() {
                                    safegazeOnDeviceModelHandler(\(isBlur),\(messageArray[2]));
                                })();
                            """

                            if let webview = message.webView {
                                webview.evaluateJavaScript(jsString, in: message.frameInfo, in: .page, completionHandler: { (result) in
                                    switch result {
                                    case.failure(let error):
                                        print("Safegaze evaluateJavaScript failure \(error)")
                                    case.success(_):
                                        return
                                    }
                                })
                            }
                        }
                    }
                }
            } else {
                print("Safegaze logger: " + messageString)
            }
        }
    }
    
    static func loadUserScriptFileManager(named: String) -> String? {
      let fileManager = FileManager.default
      let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
      let localFileURL = documentsURL.appendingPathComponent(named).appendingPathExtension("js").path
      
      do {
          // Attempt to load the file contents
          let source = try String(contentsOfFile: localFileURL, encoding: .utf8)
          return source
      } catch {
          // Log error and handle failure
          assertionFailure("Failed to Load Script: \(named).js - \(error.localizedDescription)")
          return nil
      }
    }
    
    public static func downloadAndSaveJavaScriptFile() {
        let remoteHostFileURL = URL(string: "https://raw.githubusercontent.com/AsilHQ/Android/js_code_release/node_modules/%40duckduckgo/privacy-dashboard/build/app/safe_gaze_v2.js")!
        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let localFileURL = documentsURL.appendingPathComponent("SafegazeScript.js")
        
        // Create the download task
        let task = URLSession.shared.dataTask(with: remoteHostFileURL) { data, _, error in
            if let error = error {
                print("Failed to download file: \(error)")
                return
            }
            
            guard let data = data else {
                print("No data downloaded.")
                return
            }
            
            do {
                // Write the downloaded data to the file
                try data.write(to: localFileURL)
                print("SafegazeManager: JavaScript file downloaded and saved successfully.")
            } catch {
                print("SafegazeManager: Failed to save JavaScript file: \(error)")
            }
        }
        
        // Start the download task
        task.resume()
    }
    
    @available(iOS 15.0, *)
    func downloadAndProcessImage(from imageURL: URL, completion: @escaping (Bool) -> Void) {
        // Use a background queue for network operations
        DispatchQueue.global(qos: .userInitiated).async {
            self.asyncDownloadImage(from: imageURL) { imageData in
                guard let imageData = imageData else {
                    DispatchQueue.main.async {
                        completion(true)
                    }
                    return
                }

                guard let image = UIImage(data: imageData) else {
                    return
                }
                
                if let prediction = self.nsfwDetector.isNsfw(image: image) {
                    if prediction.isSafe() {
                        self.genderDetector.predict(image: image, data: imageData) { prediction in
                            if prediction.faceCount > 0 {
                                DispatchQueue.main.async {
                                    completion(prediction.hasFemale)
                                }
                            } else {
                                DispatchQueue.main.async {
                                    completion(false)
                                }
                            }
                        }
                    } else {
                        DispatchQueue.main.async {
                            completion(true)
                        }
                    }
                } else {
                    DispatchQueue.main.async {
                        completion(true)
                    }
                }
            }
        }
    }

    func asyncDownloadImage(from imageURL: URL, completion: @escaping (Data?) -> Void) {
        URLSession.shared.dataTask(with: imageURL) { data, _, error in
            if let error = error {
                print("Error downloading image: \(error.localizedDescription)")
                completion(nil)
            } else {
                completion(data)
            }
        }.resume()
    }

}

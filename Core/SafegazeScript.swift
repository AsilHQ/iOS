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
import Vision

public class SafegazeScript: NSObject, UserScript {
    
    // MARK: - Singleton
    public static let shared = SafegazeScript()
    
    public var source: String = {
        let sendMessage = """
                            window.blurIntensity = 1.0;
                          
                            function sendMessage(message) {
                                webkit.messageHandlers.safegazeMessage.postMessage(message);
                            }
                          
                            window.sendMessage = sendMessage
                          
                            sendMessage("Script injection completed");
                          """
        guard var script = SafegazeScript.loadJavaScript(named: "Safegaze") else {
            return sendMessage
        }
        
        return sendMessage + script
    }()

    public var messageNames: [String] = ["safegazeMessage"]
    public let injectionTime: WKUserScriptInjectionTime = .atDocumentEnd
    public let forMainFrameOnly = true
    public let requiresRunInPageContentWorld = true
    
    // Make properties private
    private let safegazeDefaultBlurValue = 50
    private let safegazeMinFaceSize = 15
    private let safegazeMinImgSize: CGFloat = 45
    private let safegazeMaxImgSize: CGFloat = 800
    private let visionTools = ImageProcessor.shared
    
    public var increaseSafegazeBlurredImageCount: (() -> Void)?
    
    // Private initializer
    private override init() {
        super.init()
    }

    // Make helper methods static since they don't need instance access
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
        
        // Start the download task
        task.resume()
    }
    
    @available(iOS 15.0, *)
    func downloadAndProcessImage(from imageURL: URL, completion: @escaping (Bool, String, CGSize, [Person]) -> Void) {
        // Perform network and image processing in a background queue
        DispatchQueue.global(qos: .userInitiated).async {
            self.asyncDownloadImage(from: imageURL) { imageData in
                guard let imageData = imageData else {
                    DispatchQueue.main.async {
                        print("[SafegazeScript] downloadAndProcessImage imageData nil")
                        completion(true, "", CGSize(width: 0.0, height: 0.0), [])
                    }
                    return
                }
                
                guard let image = UIImage(data: imageData) else {
                    DispatchQueue.main.async {
                        print("[SafegazeScript] downloadAndProcessImage image nil")
                        completion(true, "", CGSize(width: 0.0, height: 0.0), [])
                    }
                    return
                }
                
                var processedImage = image
                let imageSize = CGSize(width: image.size.width, height: image.size.height)
                let base64 = imageData.base64EncodedString()

                if image.size.width < self.safegazeMinImgSize || image.size.height < self.safegazeMinImgSize {
                    DispatchQueue.main.async {
                        print("[SafegazeScript] downloadAndProcessImage smaller")
                        completion(false, base64, imageSize, [])
                    }
                    return
                }

                if image.size.width > self.safegazeMaxImgSize || image.size.height > self.safegazeMaxImgSize {
                    let maxSize = self.safegazeMaxImgSize
                    let aspectRatio = image.size.width / image.size.height
                    let newSize: CGSize
                    if aspectRatio > 1 {
                        newSize = CGSize(width: maxSize, height: maxSize / aspectRatio)
                    } else {
                        newSize = CGSize(width: maxSize * aspectRatio, height: maxSize)
                    }
                    processedImage = processedImage.resize(to: newSize) ?? processedImage
                }
                
                if let nsfwPrediction = self.visionTools.nsfwDetector.isNsfw(image: processedImage) {
                    if !nsfwPrediction.isSafe() {
                        debugPrint("[SafegazeScript] downloadAndProcessImage found a nsfw image -> \(imageURL.absoluteString)")
                        DispatchQueue.main.async {
                            completion(true, base64, CGSize(width: processedImage.size.width, height: processedImage.size.height), [])
                        }
                        return
                    } else {
                        print("[SafegazeScript] downloadAndProcessImage not nsfw")
                    }
                } else {
                    print("[SafegazeScript] downloadAndProcessImage nsfwPrediction is nil")
                }

                self.visionTools.processImage(image: image, imageData: imageData, imageUrl: imageURL.absoluteString) { _, persons in
                    for person in persons where person.isFemale {
                        self.increaseSafegazeBlurredImageCount?()
                        break
                    }
                    completion(false, base64, CGSize(width: image.size.width, height: image.size.height), persons)
                }
            }
        }
    }
    
    private func asyncDownloadImage(from imageURL: URL, completion: @escaping (Data?) -> Void) {
        URLSession.shared.dataTask(with: imageURL) { data, _, error in
            if let error = error {
                debugPrint("[SafegazeScript] Error downloading image: \(error.localizedDescription)")
                completion(nil)
            } else {
                completion(data)
            }
        }.resume()
    }
    
    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if let messageString = message.body as? String {
            if messageString.contains("coreML") {
                let messageArray = messageString.components(separatedBy: "/-/")
                if messageArray.count > 2 {
                    if let url = URL(string: messageArray[1]) {
                        print("coreML has came to me \(url)")
                        
                        let uid = messageArray[2]
                        
                        let jsString = """
                        (function() {
                            safegazeOnDeviceModelHandler("\(uid)");
                        })();
                        """

                        if let webview = message.webView {
                            webview.evaluateJavaScript(jsString, in: message.frameInfo, in: .page) { (result) in
                                switch result {
                                case .failure(let error):
                                    debugPrint("[SafegazeScript] Safegaze evaluateJavaScript failure \(error)")
                                case .success:
                                    debugPrint("[SafegazeScript] Safegaze evaluateJavaScript success")
                                }
                            }
                        }
                        
                        downloadAndProcessImage(from: url) { isNSFW, base64, size, persons in
                            let uid = messageArray[2]
                    
                            var escapedDetectionResultStrReal = ""
                            
                            var escapedBase64 = base64.replacingOccurrences(of: "\\", with: "\\\\")
                                                      .replacingOccurrences(of: "\"", with: "\\\"")

                            if base64.isEmpty {
                                escapedDetectionResultStrReal = "null"
                                escapedBase64 = "null"
                            } else if !persons.isEmpty {
                                let detectionResult = DetectionResult(imageWidth: size.width, imageHeight: size.height, persons: persons).manualEncode() ?? ""
                                escapedDetectionResultStrReal = detectionResult.replacingOccurrences(of: "\\", with: "\\\\")
                                                                                  .replacingOccurrences(of: "\"", with: "\\\"")
                            } else {
                                escapedDetectionResultStrReal = "{\"isNSFW\":\(isNSFW)}".replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
                            }
                            
                            
                            print("[SafegazeScript] escapedDetectionResultStrReal \(url.absoluteString) \(escapedDetectionResultStrReal)")
                            
                            let jsString = """
                            (function() {
                                safegazeOnDeviceModelHandler("\(uid)", "\(escapedDetectionResultStrReal)", "\(escapedBase64)");
                            })();
                            """

                            if let webview = message.webView {
                                webview.evaluateJavaScript(jsString, in: message.frameInfo, in: .page) { (result) in
                                    switch result {
                                    case .failure(let error):
                                        debugPrint("[SafegazeScript] Safegaze evaluateJavaScript failure \(error)")
                                    case .success(_):
                                        return
                                    }
                                }
                            }
                        }
                    }
                } else {
                    print("coreML detection \(messageString)")
                }
            } else {
                debugPrint("[SafegazeScript] Safegaze logger: " + messageString)
            }
        }
    }
}

// Define DetectionResult structure
struct DetectionResult {
    let imageWidth: CGFloat
    let imageHeight: CGFloat
    let persons: [Person]
}

extension DetectionResult {
    func manualEncode() -> String? {
        var jsonObject: [String: Any] = [:]

        jsonObject["imageWidth"] = imageWidth
        jsonObject["imageHeight"] = imageHeight

        // Encode the persons array
        let encodedPersons = persons.map { person -> [String: Any] in
            var personObject: [String: Any] = [:]

            // Encode keypoints
            let encodedKeypoints = person.keyPoints.map { keyPoint -> [String: Any] in
                return [
                    "name": keyPoint.bodyPart.rawValue,
                    "x": keyPoint.coordinate.x, // Extract x and y from CGPoint
                    "y": keyPoint.coordinate.y,
                    "score": keyPoint.score
                ]
            }
            personObject["keypoints"] = encodedKeypoints

            // Encode poseScore
            personObject["poseScore"] = person.score

            // Encode faceBox
            if let faceBox = person.faceBox {
                let faceBoxWidth = faceBox.right - faceBox.left
                let faceBoxHeight = faceBox.bottom - faceBox.top
                personObject["faceBox"] = [
                    "xMin": faceBox.left,
                    "xMax": faceBox.right,
                    "yMin": faceBox.top,
                    "yMax": faceBox.bottom,
                    "width": faceBoxWidth,
                    "height": faceBoxHeight
                ]
            }

            // Encode isFemale and genderScore
            personObject["isFemale"] = person.isFemale
            personObject["genderScore"] = person.genderScore

            return personObject
        }
        jsonObject["persons"] = encodedPersons

        // Serialize to JSON
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: jsonObject, options: [])
            return String(data: jsonData, encoding: .utf8)
        } catch {
            debugPrint("Error serializing DetectionResult to JSON: \(error.localizedDescription)")
            return nil
        }
    }
}

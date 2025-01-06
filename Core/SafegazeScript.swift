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

    public var source: String = {
        let sendMessage = """
                            window.blurIntensity = 1.0;
                          
                            function sendMessage(message) {
                                webkit.messageHandlers.safegazeMessage.postMessage(message);
                            }
                          
                            window.sendMessage = sendMessage
                          
                            sendMessage("Script injection completed");
                          """
        guard var script = loadJavaScript(named: "Safegaze") else {
            return sendMessage // Add local js too
        }
        
        return sendMessage + script
    }()

    public var messageNames: [String] = ["safegazeMessage"]
    public let injectionTime: WKUserScriptInjectionTime = .atDocumentEnd
    public let forMainFrameOnly = true
    public let requiresRunInPageContentWorld = true
    public var increaseSafegazeBlurredImageCount: (() -> Void)?
    private let safegazeDefaultBlurValue = 50
    private let safegazeMinFaceSize = 15
    private let safegazeMinImgSize: CGFloat = 45
    private let safegazeMaxImgSize: CGFloat = 800
    private let visionTools = ImageProcessor()
    
    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if let messageString = message.body as? String {
            if messageString == "replaced" {
                increaseSafegazeBlurredImageCount?()
            } else if messageString.contains("coreML") {
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
                                case .success(_):
                                    return
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
        let remoteHostFileURL = URL(string: "https://raw.githubusercontent.com/AsilHQ/Android/js_code_release/node_modules/%40duckduckgo/privacy-dashboard/build/app/safe_gaze_v2.js")!
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

                // Check if the image is smaller than the minimum allowed size
                if image.size.width < self.safegazeMinImgSize || image.size.height < self.safegazeMinImgSize {
                    DispatchQueue.main.async {
                        print("[SafegazeScript] downloadAndProcessImage smaller")
                        completion(false, base64, imageSize, [])
                    }
                    return
                }

                // Resize the image if it exceeds the maximum allowed size
                if image.size.width > self.safegazeMaxImgSize || image.size.height > self.safegazeMaxImgSize {
                    let maxSize = self.safegazeMaxImgSize
                    let aspectRatio = image.size.width / image.size.height
                    let newSize: CGSize
                    if aspectRatio > 1 { // Landscape
                        newSize = CGSize(width: maxSize, height: maxSize / aspectRatio)
                    } else { // Portrait
                        newSize = CGSize(width: maxSize * aspectRatio, height: maxSize)
                    }
                    processedImage = processedImage.resize(to: newSize) ?? processedImage
                }
                
                // Perform NSFW detection
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
                    completion(false, base64, CGSize(width: image.size.width, height: image.size.height), persons)
                }
            }
        }
    }
    
    func asyncDownloadImage(from imageURL: URL, completion: @escaping (Data?) -> Void) {
        URLSession.shared.dataTask(with: imageURL) { data, _, error in
            if let error = error {
                debugPrint("[SafegazeScript] Error downloading image: \(error.localizedDescription)")
                completion(nil)
            } else {
                completion(data)
            }
        }.resume()
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

//                            let detectionResultStr = """
//                                {"imageWidth":414,"imageHeight":207,"persons":[{"keypoints":[{"score":0.48335975,"name":"nose","x":209.49875,"y":90.37934},{"score":0.52006876,"name":"left_eye","x":211.48721,"y":88.55023},{"score":0.51049715,"name":"right_eye","x":208.11307,"y":88.92366},{"score":0.39864045,"name":"left_ear","x":213.24652,"y":89.451004},{"score":0.43715522,"name":"right_ear","x":203.83746,"y":90.498695},{"score":0.5424707,"name":"left_shoulder","x":217.14085,"y":97.83629},{"score":0.47812748,"name":"right_shoulder","x":199.71634,"y":98.491234},{"score":0.33641198,"name":"left_elbow","x":222.7871,"y":106.661964},{"score":0.40456522,"name":"right_elbow","x":198.83649,"y":108.68178},{"score":0.373184,"name":"left_wrist","x":220.83745,"y":116.53363},{"score":0.32049152,"name":"right_wrist","x":205.12093,"y":117.96529},{"score":0.6409448,"name":"left_hip","x":214.71506,"y":119.18343},{"score":0.549166,"name":"right_hip","x":203.1348,"y":119.40144},{"score":0.34891987,"name":"left_knee","x":222.90875,"y":123.281944},{"score":0.31873438,"name":"right_knee","x":202.31104,"y":122.82173},{"score":0.2047919,"name":"left_ankle","x":218.71565,"y":132.20503},{"score":0.219927,"name":"right_ankle","x":210.30887,"y":131.79192}],"poseScore":0.23066473,"faceBox":{"xMin":204.0,"xMax":214.0,"yMin":83.0,"yMax":96.0,"width":10.0,"height":13.0},"isFemale":true,"genderScore":0.0},{"keypoints":[{"score":0.45940265,"name":"nose","x":130.47768,"y":97.181015},{"score":0.4867166,"name":"left_eye","x":130.05806,"y":94.27808},{"score":0.4690871,"name":"right_eye","x":129.269,"y":94.77897},{"score":0.5314826,"name":"left_ear","x":127.14932,"y":95.36135},{"score":0.42947784,"name":"right_ear","x":122.08324,"y":96.37183},{"score":0.45079082,"name":"left_shoulder","x":120.482254,"y":110.47898},{"score":0.45862558,"name":"right_shoulder","x":119.34548,"y":110.11444},{"score":0.46728644,"name":"left_elbow","x":127.25191,"y":126.535164},{"score":0.37138048,"name":"right_elbow","x":122.14168,"y":128.52753},{"score":0.36765227,"name":"left_wrist","x":136.54405,"y":130.21999},{"score":0.3357184,"name":"right_wrist","x":133.02052,"y":132.09245},{"score":0.36202013,"name":"left_hip","x":114.92509,"y":141.13564},{"score":0.29685104,"name":"right_hip","x":117.99221,"y":141.5942},{"score":0.37489933,"name":"left_knee","x":134.3711,"y":142.00935},{"score":0.32608625,"name":"right_knee","x":129.9615,"y":146.99683},{"score":0.18457255,"name":"left_ankle","x":126.53769,"y":156.83337},{"score":0.19637191,"name":"right_ankle","x":126.53311,"y":157.72986}],"poseScore":0.21314265,"faceBox":{"xMin":125.0,"xMax":126.0,"yMin":92.0,"yMax":103.0,"width":1.0,"height":11.0},"isFemale":true,"genderScore":0.0},{"keypoints":[{"score":0.4815296,"name":"nose","x":88.85169,"y":105.57074},{"score":0.5174399,"name":"left_eye","x":88.971405,"y":101.214775},{"score":0.46825776,"name":"right_eye","x":87.47126,"y":101.36527},{"score":0.45422715,"name":"left_ear","x":81.97744,"y":100.984314},{"score":0.39516997,"name":"right_ear","x":78.4846,"y":101.383965},{"score":0.48446274,"name":"left_shoulder","x":88.24777,"y":114.644394},{"score":0.42136517,"name":"right_shoulder","x":73.41896,"y":118.34106},{"score":0.3467031,"name":"left_elbow","x":97.2222,"y":135.37328},{"score":0.37679943,"name":"right_elbow","x":88.0703,"y":138.22214},{"score":0.23823434,"name":"left_wrist","x":118.579834,"y":143.88557},{"score":0.2759233,"name":"right_wrist","x":95.730515,"y":152.98575},{"score":0.46058747,"name":"left_hip","x":95.251785,"y":149.7878},{"score":0.45387137,"name":"right_hip","x":92.73732,"y":150.4199},{"score":0.30441988,"name":"left_knee","x":114.05832,"y":154.39755},{"score":0.21559419,"name":"right_knee","x":104.184746,"y":166.76346},{"score":0.36361867,"name":"left_ankle","x":110.011665,"y":171.82811},{"score":0.26049066,"name":"right_ankle","x":93.05301,"y":175.27216}],"poseScore":0.17745304,"faceBox":{"xMin":77.0,"xMax":90.0,"yMin":97.0,"yMax":115.0,"width":13.0,"height":18.0},"isFemale":true,"genderScore":0.0},{"keypoints":[{"score":0.31454396,"name":"nose","x":318.03976,"y":105.065315},{"score":0.3203813,"name":"left_eye","x":317.09042,"y":100.39169},{"score":0.31174856,"name":"right_eye","x":318.82043,"y":103.07885},{"score":0.28766704,"name":"left_ear","x":328.8722,"y":102.19843},{"score":0.24289641,"name":"right_ear","x":323.4946,"y":98.18907},{"score":0.27861193,"name":"left_shoulder","x":335.92035,"y":110.49191},{"score":0.27228805,"name":"right_shoulder","x":336.29416,"y":106.52985},{"score":0.30058065,"name":"left_elbow","x":325.28998,"y":132.81984},{"score":0.24255754,"name":"right_elbow","x":330.3197,"y":128.63283},{"score":0.25793564,"name":"left_wrist","x":327.81726,"y":144.95374},{"score":0.23341368,"name":"right_wrist","x":325.82748,"y":142.18477},{"score":0.47981808,"name":"left_hip","x":360.36362,"y":133.69905},{"score":0.48864847,"name":"right_hip","x":365.0436,"y":131.09578},{"score":0.3174529,"name":"left_knee","x":344.0747,"y":148.52821},{"score":0.29116124,"name":"right_knee","x":344.09933,"y":144.29509},{"score":0.16397975,"name":"left_ankle","x":347.06696,"y":162.59816},{"score":0.22726764,"name":"right_ankle","x":346.6206,"y":161.47208}],"poseScore":0.119451076,"faceBox":{"xMin":322.0,"xMax":323.0,"yMin":95.0,"yMax":113.0,"width":1.0,"height":18.0},"isFemale":true,"genderScore":0.0}]}
//                            """

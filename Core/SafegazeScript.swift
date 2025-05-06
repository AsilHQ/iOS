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
import NSFWDetector

public class SafegazeScript: NSObject, UserScript {
    
    // MARK: - Singleton
    public static let shared = SafegazeScript()
    
    public var source: String = {
        return ImageProcessor.shared.loadJavaScript() ?? ""
    }()
    
    public var messageNames: [String] = ["safegazeMessage"]
    public let injectionTime: WKUserScriptInjectionTime = .atDocumentStart
    public let forMainFrameOnly = true
    public let requiresRunInPageContentWorld = true
    
    public var increaseSafegazeBlurredImageCount: () -> Void = {}
    private var taskContinuation: AsyncStream<() async -> Void>.Continuation?
    private var taskStream: AsyncStream<() async -> Void>?
    
    private override init() {
        super.init()
        setupTaskStream()
        ImageProcessingQueue.shared.increaseSafegazeBlurredImageCount = { [weak self] in
            self?.increaseSafegazeBlurredImageCount()
        }
    }
    
    deinit {
        taskContinuation?.finish()
    }
    
    func setupTaskStream() {
        let (stream, continuation) = AsyncStream<() async -> Void>.makeStream()
        self.taskStream = stream
        self.taskContinuation = continuation

        Task {
            await processDynamicTasksWithLimitedConcurrency(
                incomingTaskStream: stream,
                maxConcurrentTasks: 1
            )
        }
    }
    
    func processDynamicTasksWithLimitedConcurrency<T>(
        incomingTaskStream: AsyncStream<() async -> T>,
        maxConcurrentTasks: Int = 1
    ) async -> [T] {
        var results: [T] = []
        
        await withTaskGroup(of: T.self) { group in
            var activeTasks = 0
            
            for await task in incomingTaskStream {
                while activeTasks >= maxConcurrentTasks {
                    _ = await group.next()
                    activeTasks -= 1
                }
                
                group.addTask {
                    await task()
                }
                activeTasks += 1
            }
            
            // Wait for remaining active tasks to finish
            while activeTasks > 0 {
                if let result = await group.next() {
                    results.append(result)
                    activeTasks -= 1
                }
            }
        }
        
        return results
    }
    
    struct ImageData: Codable {
        let src: String
        let id: String
        let baseImg: String
        let width: CGFloat?
        let height: CGFloat?
        
        var size: CGSize? {
            if width == nil || height == nil {
                return nil
            }
            return CGSize(width: width!, height: height!)
        }
    }
    
    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.webView == nil {
            debugPrint("❌ No webview found inside message")
            return
        }
        
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
        
//        print("inner JSON string to Data: --------", dataString)
        
        do {
            let imageData = try JSONDecoder().decode(ImageData.self, from: innerData)
            print("📥 Received image: src: \(imageData.src), id: \(imageData.id), baseImg: \(imageData.baseImg.prefix(30)), width: \(imageData.width ?? 0), height: \(imageData.height ?? 0)")
            
            if imageData.src.hasPrefix("data:image/") {
                if let image = UIImage(base64: imageData.src) {
                    print("------ uiiimage found from base64")
                    taskContinuation?.yield {
                        await ImageProcessingQueue.shared.enqueueProcessing(
                            src: imageData.src,
                            image: (imageData.size != nil ? image.imageResized(to: imageData.size!) : image) ?? image,
                            id: imageData.id,
                            webView: message.webView,
                            frameInfo: message.frameInfo
                        )
                    }
                    return
                } else {
                    Task {
                        await sendNullImage(id: imageData.id, webView: message.webView, frameInfo: message.frameInfo)
                    }
                }
            }
            
            if imageData.baseImg.starts(with: "data:image/") {
                if let image = UIImage(base64: imageData.baseImg) {
                    print("------ uiiimage found from base64")
                    taskContinuation?.yield {
                        await ImageProcessingQueue.shared.enqueueProcessing(
                            src: imageData.src,
                            image: (imageData.size != nil ? image.imageResized(to: imageData.size!) : image) ?? image,
                            id: imageData.id,
                            webView: message.webView,
                            frameInfo: message.frameInfo
                        )
                    }
                    return
                } else {
                    Task {
                        await sendNullImage(id: imageData.id, webView: message.webView, frameInfo: message.frameInfo)
                    }
                }
            }
            
            guard let url = URL(string: imageData.src) else {
                print("❌ Failed to convert image URL string to URL \(imageData.src)")
                Task {
                    await sendNullImage(id: imageData.id, webView: message.webView, frameInfo: message.frameInfo)
                }
                return
            }
            
            taskContinuation?.yield {
                await ImageProcessingQueue.shared.enqueueProcessing(
                    url: url,
                    id: imageData.id,
                    targetSize: imageData.size,
                    webView: message.webView,
                    frameInfo: message.frameInfo
                )
            }
        } catch {
            print("❌ Failed to decode inner JSON:", error)
        }
    }
    
    func sendNullImage(id: String, webView: WKWebView?, frameInfo: WKFrameInfo) async {
        guard let webView else {
            return
        }
        let jsString = """
        (function() {
            receiveMessageFromKotlin("detectionResult", "{\\\"result\\\": \\\"\("null")\\\", \\\"id\\\": \\\"\(id)\\\"}");
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
}

extension UIImage {
    var base64: String? {
        self.jpegData(compressionQuality: 0.6)?.base64EncodedString()
    }
}

public actor ImageProcessingQueue {
    static let shared = ImageProcessingQueue()
    private let visionTools = ImageProcessor.shared
    private let nsfwDetector = NSFWDetector.shared
    @MainActor var increaseSafegazeBlurredImageCount: () -> Void = {}
    
    private init() {}
    
    func sendNSFWImage(id: String, webView: WKWebView, frameInfo: WKFrameInfo) async {
        let jsString = """
        (function() {
            receiveMessageFromKotlin("detectionResult", "{\\\"result\\\": \\\"\("nsfw")\\\", \\\"id\\\": \\\"\(id)\\\"}");
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
    
    func configure(blurImageMode: ImageProcessingMode, shouldBlurFace: Bool) async {
        Task {
            await visionTools.changeBlurMode(mode: blurImageMode, shouldBlurFace: shouldBlurFace)
        }
        Task {
            await visionTools.configure()
        }
    }
    
    func enqueueProcessing(url: URL, id: String, targetSize: CGSize?, webView: WKWebView?, frameInfo: WKFrameInfo) async {
        guard let webView = webView else {
            return
        }
        let src = url.absoluteString
        let startDate = Int(Date().timeIntervalSince1970 * 1000)

        // Check disk cache first
        if let cachedBase64 = ImageDiskCache.shared.get(for: src) {
            let jsResult = cachedBase64
            let jsString = """
            (function() {
                receiveMessageFromKotlin(\"detectionResult\", \"{\\\"result\\\": \\\"\(jsResult)\\\", \\\"id\\\": \\\"\(id)\\\"}\");
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
            return
        }

        // Not cached, process as before
        let (isNSFW, base64) = await downloadAndProcessImage(from: url, targetSize: targetSize)
        if isNSFW {
            debugPrint("NSFW image detected: \(src)")
            await sendNSFWImage(id: id, webView: webView, frameInfo: frameInfo)
            return
        }
        let base64Prefix = base64 != nil ? "data:image/png;base64," : "null"
        let jsResult = base64 != nil ? "\(base64Prefix)\(base64!)" : base64Prefix

        // Cache result if available
        if let base64 = base64 {
            ImageDiskCache.shared.set(src: src, base64: "\(base64Prefix)\(base64)")
        }

        let jsString = """
        (function() {
            receiveMessageFromKotlin(\"detectionResult\", \"{\\\"result\\\": \\\"\(jsResult)\\\", \\\"id\\\": \\\"\(id)\\\"}\");
        })();
        """
        await MainActor.run {
            webView.evaluateJavaScript(jsString, in: frameInfo, in: .page) { result in
                switch result {
                case .failure(let error):
                    debugPrint("[SafegazeScript] evaluateJavaScript failed: \(error)")
                case .success:
                    let endDate = Int(Date().timeIntervalSince1970 * 1000)
                    print("execution time for src: \(src) is , \(endDate - startDate)ms")
                }
            }
        }
    }
    
    func enqueueProcessing(src: String, image: UIImage, id: String, webView: WKWebView?, frameInfo: WKFrameInfo) async {
        guard let webView = webView else {
            return
        }
        // For base64 images, use id as the cache key (or pass src if possible)
        let cacheKey = src
        let startDate = Int(Date().timeIntervalSince1970 * 1000)

        if let cachedBase64 = ImageDiskCache.shared.get(for: cacheKey) {
            let jsResult = cachedBase64
            let jsString = """
            (function() {
                receiveMessageFromKotlin(\"detectionResult\", \"{\\\"result\\\": \\\"\(jsResult)\\\", \\\"id\\\": \\\"\(id)\\\"}\");
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
            return
        }
        
        let isNSFWImage = await isNSFWImage(image: image)
        if isNSFWImage {
            debugPrint("NSFW image detected: \(src)")
            await sendNSFWImage(id: id, webView: webView, frameInfo: frameInfo)
            return
        }

        let base64 = await processImage(from: image)
        let base64Prefix = base64 != nil ? "data:image/png;base64," : "null"
        let jsResult = base64 != nil ? "\(base64Prefix)\(base64!)" : base64Prefix

        // Cache result if available
        if let base64 = base64 {
            ImageDiskCache.shared.set(src: cacheKey, base64: "\(base64Prefix)\(base64)")
        }

        let jsString = """
        (function() {
            receiveMessageFromKotlin(\"detectionResult\", \"{\\\"result\\\": \\\"\(jsResult)\\\", \\\"id\\\": \\\"\(id)\\\"}\");
        })();
        """
        await MainActor.run {
            webView.evaluateJavaScript(jsString, in: frameInfo, in: .page) { result in
                switch result {
                case .failure(let error):
                    debugPrint("[SafegazeScript] evaluateJavaScript failed: \(error)")
                case .success:
                    let endDate = Int(Date().timeIntervalSince1970 * 1000)
                    print("execution time end for src: \(src) is , \(endDate - startDate)ms")
                }
            }
        }
    }
    
    func downloadAndProcessImage(from imageURL: URL, targetSize: CGSize?) async -> (Bool, String?) {
        guard let imageData = await asyncDownloadImage(from: imageURL, targetSize: targetSize),
              let image = UIImage(data: imageData) else {
            return (false, nil)
        }
        let isNSFWImage = await isNSFWImage(image: image)
        if isNSFWImage {
            return (true, nil)
        }
        return (false, await processImage(from: image))
    }
    
    func isNSFWImage(image: UIImage) async -> Bool {
        let result = await nsfwDetector.check(image: image)
        switch result {
        case .error(let error):
            debugPrint("nsfw check failed error \(error.localizedDescription)")
            return false
        case .success(let nsfwConfidence):
            debugPrint("nsfw check success confidence: \(nsfwConfidence)")
            if nsfwConfidence > 0.5 {
                await increaseSafegazeBlurredImageCount()
                return true
            } else {
                return false
            }
        }
    }
    
    func processImage(from image: UIImage) async -> String? {
        if let processedImage = try? await visionTools.processImage(image: image),
           let base64String = processedImage.base64 {
            debugPrint("got output image")
            await increaseSafegazeBlurredImageCount()
            return base64String
        } else {
            debugPrint("got no output image")
            return nil
        }
    }
    
    private func asyncDownloadImage(from imageURL: URL, targetSize: CGSize?) async -> Data? {
        do {
            let (data, _) = try await URLSession.shared.data(from: imageURL)
            guard let targetSize  = targetSize else {
                return data
            }
            guard let image = UIImage(data: data) else { return nil }
            let resizedImage = image.imageResized(to: targetSize)
            debugPrint("url: \(imageURL.absoluteString), image size: \(image.size), resized size: \(resizedImage?.size ?? .zero)")
            return resizedImage?.pngData()
        } catch {
            debugPrint("[SafegazeScript] Error downloading image: \(error.localizedDescription)")
            return nil
        }
    }
}

extension UIImage {
    convenience init?(base64: String) {
        var cleanBase64 = base64
        if let range = cleanBase64.range(of: "base64,") {
            cleanBase64 = String(cleanBase64[range.upperBound...])
        }
        guard let imageData = Data(base64Encoded: cleanBase64, options: .ignoreUnknownCharacters) else {
            return nil
        }
        self.init(data: imageData)
    }
    
    func imageResized(to size: CGSize) -> UIImage? {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}

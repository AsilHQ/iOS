//
//  Extensions+.swift
//  DuckDuckGo
//
//  Copyright © 2024 DuckDuckGo. All rights reserved.
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

import Vision

/// Represents a detected person in an image.
class Person: Encodable {
    /// Unique identifier for the person.
    var id: Int

    /// Keypoints representing body parts (e.g., nose, left shoulder, etc.).
    var keyPoints: [KeyPoint]

    /// A confidence score representing the accuracy of pose detection.
    var score: Float

    /// Bounding box for the detected face, if available.
    var faceBox: CGRect?

    /// Bounding box for the detected pose, if available.
    var poseBox: CGRect?

    /// Indicates whether the person is identified as female.
    var isFemale: Bool = false

    /// Confidence score for the person being female.
    var genderScore: Float = 0.0

    /// Initializes a new `Person` object.
    /// - Parameters:
    ///   - id: Unique identifier for the person.
    ///   - keyPoints: Array of detected body keypoints.
    ///   - score: Confidence score for the pose detection.
    ///   - faceBox: Bounding box for the detected face (optional).
    ///   - poseBox: Bounding box for the detected pose (optional).
    init(id: Int, keyPoints: [KeyPoint], score: Float, faceBox: CGRect?, poseBox: CGRect?) {
        self.id = id
        self.keyPoints = keyPoints
        self.score = score
        self.faceBox = faceBox
        self.poseBox = poseBox
    }

    /// Custom encoding logic to handle `CGRect`.
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(keyPoints, forKey: .keyPoints)
        try container.encode(score, forKey: .score)
        try container.encode(isFemale, forKey: .isFemale)
        try container.encode(genderScore, forKey: .genderScore)

        // Encode `CGRect` as a dictionary
        if let faceBox = faceBox {
            try container.encode(["x": faceBox.origin.x, "y": faceBox.origin.y, "width": faceBox.size.width, "height": faceBox.size.height], forKey: .faceBox)
        }
        if let poseBox = poseBox {
            try container.encode(["x": poseBox.origin.x, "y": poseBox.origin.y, "width": poseBox.size.width, "height": poseBox.size.height], forKey: .poseBox)
        }
    }

    /// Coding keys to match the JSON structure.
    enum CodingKeys: String, CodingKey {
        case id
        case keyPoints
        case score
        case faceBox
        case poseBox
        case isFemale
        case genderScore
    }
}

struct CodableCGRect: Codable {
    var x: CGFloat
    var y: CGFloat
    var width: CGFloat
    var height: CGFloat

    init(from rect: CGRect) {
        self.x = rect.origin.x
        self.y = rect.origin.y
        self.width = rect.size.width
        self.height = rect.size.height
    }

    func toCGRect() -> CGRect {
        return CGRect(x: x, y: y, width: width, height: height)
    }
}

struct KeyPoint: Codable {
    /// Body part name as a string.
    var bodyPart: String

    /// Coordinates of the keypoint in the image.
    var coordinate: CGPoint

    /// Confidence score for the keypoint detection.
    var score: Float

    /// Initialize `KeyPoint` with a `JointName`.
    init(bodyPart: VNHumanBodyPoseObservation.JointName, coordinate: CGPoint, score: Float) {
        self.bodyPart = bodyPart.rawValue.rawValue // Convert `JointName` to its string value
        self.coordinate = coordinate
        self.score = score
    }
}

extension UIImage {
    func resize(to size: CGSize) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
        draw(in: CGRect(origin: .zero, size: size))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return resizedImage
    }
}

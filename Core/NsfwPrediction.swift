//
//  NsfwPrediction.swift
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

struct NsfwPrediction: Equatable, Hashable {
    static let labels = ["drawing", "hentai", "neutral", "porn", "sexy"]
    
    let predictions: [Float]
    
    func drawing() -> Float {
        return predictions[0]
    }
    
    func hentai() -> Float {
        return predictions[1]
    }
    
    func neutral() -> Float {
        return predictions[2]
    }
    
    func porn() -> Float {
        return predictions[3]
    }
    
    func sexy() -> Float {
        return predictions[4]
    }
    
    func getLabelWithConfidence() -> (label: String, confidence: Float) {
        guard let maxIndex = predictions.indices.max(by: { predictions[$0] < predictions[$1] }) else {
            return ("Unknown", 0.0)
        }
        
        let label = (maxIndex < NsfwPrediction.labels.count) ? NsfwPrediction.labels[maxIndex] : "Unknown"
        return (label, predictions[maxIndex])
    }
    
    func safeScore() -> Float {
        return drawing() + neutral()
    }
    
    func unsafeScore() -> Float {
        return hentai() + porn() + sexy()
    }
    
    func isSafe() -> Bool {
        print("nsfw Unsafe score \(unsafeScore()) Safe score \(safeScore())")
        return unsafeScore() < 0.85
    }
    
    static func == (lhs: NsfwPrediction, rhs: NsfwPrediction) -> Bool {
        return lhs.predictions == rhs.predictions
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(predictions)
    }
}

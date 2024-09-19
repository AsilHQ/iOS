//
// Copyright 2023 Kahf Messenger, LLC
// SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation
import UIKit
    
extension UIFont {
    static func interVariable(ofSize size: CGFloat, weight: UIFont.Weight) -> UIFont? {
        let descriptor = UIFontDescriptor(fontAttributes: [
            .name: "InterVariable",
            .traits: [
                UIFontDescriptor.TraitKey.weight: weight
            ]
        ])
        
        return UIFont(descriptor: descriptor, size: size)
    }
}


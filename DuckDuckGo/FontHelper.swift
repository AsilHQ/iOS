// Copyright 2024 The Kahf Browser Authors. All rights reserved.
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import SwiftUI
import UIKit

struct FontHelper {
    
    // MARK: - SwiftUI Font Methods
    
    static func quicksand(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let weightString = weight.fontWeightString()
        return Font.custom("Quicksand-\(weightString)", size: size)
    }
    
    static func lato(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let weightString = weight.fontWeightString()
        return Font.custom("Lato-\(weightString)", size: size)
    }
    
    static func poppins(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let weightString = weight.fontWeightString()
        return Font.custom("Poppins-\(weightString)", size: size)
    }
    
    static func inter(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let weightString = weight.fontWeightString()
        return Font.custom("Inter-\(weightString)", size: size)
    }
    
    // MARK: - UIKit UIFont Methods
    
    static func quicksandUIFont(size: CGFloat, weight: UIFont.Weight = .regular) -> UIFont {
        let weightString = weight.uiFontWeightString()
        return UIFont(name: "Quicksand-\(weightString)", size: size) ?? UIFont.systemFont(ofSize: size, weight: weight)
    }

    static func latoUIFont(size: CGFloat, weight: UIFont.Weight = .regular) -> UIFont {
        let weightString = weight.uiFontWeightString()
        return UIFont(name: "Lato-\(weightString)", size: size) ?? UIFont.systemFont(ofSize: size, weight: weight)
    }

    static func poppinsUIFont(size: CGFloat, weight: UIFont.Weight = .regular) -> UIFont {
        let weightString = weight.uiFontWeightString()
        return UIFont(name: "Poppins-\(weightString)", size: size) ?? UIFont.systemFont(ofSize: size, weight: weight)
    }

    static func interUIFont(size: CGFloat, weight: UIFont.Weight = .regular) -> UIFont {
        let weightString = weight.uiFontWeightString()
        return UIFont(name: "Inter-\(weightString)", size: size) ?? UIFont.systemFont(ofSize: size, weight: weight)
    }
}

// MARK: - Extensions for Font Weights
extension Font.Weight {
    func fontWeightString() -> String {
        switch self {
        case .ultraLight: return "UltraLight"
        case .thin: return "Thin"
        case .light: return "Light"
        case .regular: return "Regular"
        case .medium: return "Medium"
        case .semibold: return "SemiBold"
        case .bold: return "Bold"
        case .heavy: return "Heavy"
        case .black: return "Black"
        default: return "Regular"
        }
    }
}

extension UIFont.Weight {
    func uiFontWeightString() -> String {
        switch self {
        case .ultraLight: return "UltraLight"
        case .thin: return "Thin"
        case .light: return "Light"
        case .regular: return "Regular"
        case .medium: return "Medium"
        case .semibold: return "SemiBold"
        case .bold: return "Bold"
        case .heavy: return "Heavy"
        case .black: return "Black"
        default: return "Regular"
        }
    }
}

// Copyright 2024 The Kahf Browser Authors. All rights reserved.
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import SwiftUI

struct FontHelper {
    static func quicksand(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let weightString: String

        switch weight {
        case .ultraLight: weightString = "UltraLight"
        case .thin: weightString = "Thin"
        case .light: weightString = "Light"
        case .regular: weightString = "Regular"
        case .medium: weightString = "Medium"
        case .semibold: weightString = "Semibold"
        case .bold: weightString = "Bold"
        case .heavy: weightString = "Heavy"
        case .black: weightString = "Black"
        default: weightString = "Regular"
        }

        return Font.custom("Quicksand-\(weightString)", size: size)
    }
    
    static func lato(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let weightString: String

        switch weight {
        case .regular: weightString = "Regular"
        case .bold: weightString = "Bold"
        default: weightString = "Regular"
        }

        return Font.custom("Lato-\(weightString)", size: size)
    }
    
    static func poppins(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let weightString: String

        switch weight {
        case .semibold: weightString = "SemiBold"
        case .regular: weightString = "Regular"
        case .bold: weightString = "Bold"
        default: weightString = "Regular"
        }

        return Font.custom("Poppins-\(weightString)", size: size)
    }
    
    static func inter(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let weightString: String
        
        switch weight {
        case .bold: weightString = "Bold"
        case .regular: weightString = "Regular"
        default: weightString = "Regular"
        }
        
        return Font.custom("Inter-\(weightString)", size: size)
    }
}

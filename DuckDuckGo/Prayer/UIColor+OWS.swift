//
//  KahfBrowserOnboardingView.swift
//  DuckDuckGo
//
//  Copyright © 2024 KahfBrowser. All rights reserved.
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

// swiftlint:disable all

import Foundation
import UIKit


// MARK: - Palette

@objc
public extension UIColor {

    // MARK: Brand Colors

    @objc(ows_signalBlueColor)
    class var ows_signalBlue: UIColor {
        return UIColor(rgbHex: 0x3E8DFF)
    }

    @objc(ows_signalBlueDarkColor)
    class var ows_signalBlueDark: UIColor {
        return UIColor(rgbHex: 0x1851B4)
    }

    // MARK: Accent Colors

    /// Nav Bar, Primary Buttons
    @objc(ows_accentBlueColor)
    class var ows_accentBlue: UIColor {
        // Ultramarine UI
        return UIColor(rgbHex: 0x2C6BED)
    }

    @objc(ows_accentBlueDarkColor)
    class var ows_accentBlueDark: UIColor {
        // Ultramarine UI Light
        return UIColor(rgbHex: 0x6191F3)
    }

    @objc(ows_accentBlueTintColor)
    class var ows_accentBlueTint: UIColor {
        return UIColor(rgbHex: 0xB0C8F9)
    }

    /// Making calls, success states
    @objc(ows_accentGreenColor)
    class var ows_accentGreen: UIColor {
        return UIColor(rgbHex: 0x4CAF50)
    }

    /// Warning, update states
    @objc(ows_accentYellowColor)
    class var ows_accentYellow: UIColor {
        return UIColor(rgbHex: 0xFFD624)
    }

    /// Ending calls, error states
    @objc(ows_accentRedColor)
    class var ows_accentRed: UIColor {
        return UIColor(rgbHex: 0xEB5757)
    }

    /// mute unmute background color
    @objc(ows_accentIndigoColor)
    class var ows_accentIndigo: UIColor {
        return UIColor(rgbHex: 0x5951c8)
    }

    // MARK: - GreyScale

    @objc(ows_whiteColor)
    class var ows_white: UIColor {
        return UIColor(rgbHex: 0xFFFFFF)
    }

    @objc(ows_gray01Color)
    class var ows_gray01: UIColor {
        return UIColor(rgbHex: 0x333333)
    }
    
    @objc(ows_gray02Color)
    class var ows_gray02: UIColor {
        return UIColor(rgbHex: 0xF6F6F6)
    }
    
    @objc(ows_gray03Color)
    class var ows_gray03: UIColor {
        return UIColor(rgbHex: 0x828282)
    }

    @objc(ows_gray05Color)
    class var ows_gray05: UIColor {
        return UIColor(rgbHex: 0xE9E9E9)
    }
    
    @objc(ows_gray06Color)
    class var ows_gray06: UIColor {
        return UIColor(rgbHex: 0xF2F2F2)
    }

    @objc(ows_gray10Color)
    class var ows_gray10: UIColor {
        return UIColor(rgbHex: 0xf0f0f0)
    }

    @objc(ows_gray12Color)
    class var ows_gray12: UIColor {
        return UIColor(rgbHex: 0xe0e0e0)
    }

    @objc(ows_gray15Color)
    class var ows_gray15: UIColor {
        return UIColor(rgbHex: 0xD4D4D4)
    }

    @objc(ows_gray20Color)
    class var ows_gray20: UIColor {
        return UIColor(rgbHex: 0xCCCCCC)
    }

    @objc(ows_gray22Color)
    class var ows_gray22: UIColor {
        return UIColor(rgbHex: 0xC6C6C6)
    }

    @objc(ows_gray25Color)
    class var ows_gray25: UIColor {
        return UIColor(rgbHex: 0xB9B9B9)
    }

    @objc(ows_gray40Color)
    class var ows_gray40: UIColor {
        return UIColor(rgbHex: 0x999999)
    }

    @objc(ows_gray45Color)
    class var ows_gray45: UIColor {
        return UIColor(rgbHex: 0x848484)
    }

    @objc(ows_gray60Color)
    class var ows_gray60: UIColor {
        return UIColor(rgbHex: 0x5E5E5E)
    }

    @objc(ows_gray65Color)
    class var ows_gray65: UIColor {
        return UIColor(rgbHex: 0x4A4A4A)
    }

    @objc(ows_gray75Color)
    class var ows_gray75: UIColor {
        return UIColor(rgbHex: 0x3B3B3B)
    }

    @objc(ows_gray80Color)
    class var ows_gray80: UIColor {
        return UIColor(rgbHex: 0x2E2E2E)
    }

    @objc(ows_gray85Color)
    class var ows_gray85: UIColor {
        return UIColor(rgbHex: 0x23252A)
    }

    @objc(ows_gray90Color)
    class var ows_gray90: UIColor {
        return UIColor(rgbHex: 0x1B1B1B)
    }

    @objc(ows_gray95Color)
    class var ows_gray95: UIColor {
        return UIColor(rgbHex: 0x121212)
    }

    @objc(ows_blackColor)
    class var ows_black: UIColor {
        return UIColor(rgbHex: 0x000000)
    }

    // MARK: Masks

    @objc(ows_whiteAlpha00Color)
    class var ows_whiteAlpha00: UIColor {
        return UIColor(white: 1.0, alpha: 0)
    }

    @objc(ows_whiteAlpha20Color)
    class var ows_whiteAlpha20: UIColor {
        return UIColor(white: 1.0, alpha: 0.2)
    }

    @objc(ows_whiteAlpha25Color)
    class var ows_whiteAlpha25: UIColor {
        return UIColor(white: 1.0, alpha: 0.25)
    }

    @objc(ows_whiteAlpha30Color)
    class var ows_whiteAlpha30: UIColor {
        return UIColor(white: 1.0, alpha: 0.3)
    }

    @objc(ows_whiteAlpha40Color)
    class var ows_whiteAlpha40: UIColor {
        return UIColor(white: 1.0, alpha: 0.4)
    }

    @objc(ows_whiteAlpha50Color)
    class var ows_whiteAlpha50: UIColor {
        return UIColor(white: 1.0, alpha: 0.5)
    }

    @objc(ows_whiteAlpha60Color)
    class var ows_whiteAlpha60: UIColor {
        return UIColor(white: 1.0, alpha: 0.6)
    }

    @objc(ows_whiteAlpha70Color)
    class var ows_whiteAlpha70: UIColor {
        return UIColor(white: 1.0, alpha: 0.7)
    }

    @objc(ows_whiteAlpha80Color)
    class var ows_whiteAlpha80: UIColor {
        return UIColor(white: 1.0, alpha: 0.8)
    }

    @objc(ows_whiteAlpha90Color)
    class var ows_whiteAlpha90: UIColor {
        return UIColor(white: 1.0, alpha: 0.9)
    }

    @objc(ows_blackAlpha05Color)
    class var ows_blackAlpha05: UIColor {
        return UIColor(white: 0, alpha: 0.05)
    }

    @objc(ows_blackAlpha10Color)
    class var ows_blackAlpha10: UIColor {
        return UIColor(white: 0, alpha: 0.10)
    }

    @objc(ows_blackAlpha20Color)
    class var ows_blackAlpha20: UIColor {
        return UIColor(white: 0, alpha: 0.20)
    }

    @objc(ows_blackAlpha25Color)
    class var ows_blackAlpha25: UIColor {
        return UIColor(white: 0, alpha: 0.25)
    }

    @objc(ows_blackAlpha40Color)
    class var ows_blackAlpha40: UIColor {
        return UIColor(white: 0, alpha: 0.40)
    }

    @objc(ows_blackAlpha50Color)
    class var ows_blackAlpha50: UIColor {
        return UIColor(white: 0, alpha: 0.50)
    }

    @objc(ows_blackAlpha60Color)
    class var ows_blackAlpha60: UIColor {
        return UIColor(white: 0, alpha: 0.60)
    }

    @objc(ows_blackAlpha80Color)
    class var ows_blackAlpha80: UIColor {
        return UIColor(white: 0, alpha: 0.80)
    }

    // MARK: UI Colors

    // FIXME OFF-PALETTE
    @objc(ows_reminderYellowColor)
    class var ows_reminderYellow: UIColor {
        return UIColor(rgbHex: 0xFCF0D9)
    }
    
    // MARK: - Kahf Color Palette
    
    @objc(ows_bluish)
    class var ows_bluish: UIColor {
        return UIColor(rgbHex: 0xE6EAF2)
    }
    
    @objc(ows_kahf_gray2)
    class var ows_kahf_gray2: UIColor {
        return UIColor(rgbHex: 0x4F4F4F)
    }
    
    @objc(ows_kahf_background)
    class var ows_kahf_background: UIColor {
        return UIColor(rgbHex: 0xFAFBFD)
    }
    
    @objc(ows_kahf_selected_item_blue_background)
    class var ows_kahf_selected_item_blue_background: UIColor {
        return UIColor(rgbHex: 0xECF4FF)
    }
}

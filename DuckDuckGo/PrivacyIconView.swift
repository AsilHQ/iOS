//
//  PrivacyIconView.swift
//  DuckDuckGo
//
//  Copyright © 2022 DuckDuckGo. All rights reserved.
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
import UIKit
import Lottie

enum PrivacyIcon {
    case daxLogo
    case kahfWorld
    case kahfLock
}

class PrivacyIconView: UIView {

    @IBOutlet var daxLogoImageView: UIImageView!

    public required init?(coder aDecoder: NSCoder) {
        icon = .daxLogo
        
        super.init(coder: aDecoder)
        
        
        if #available(iOS 13.4, *) {
            addInteraction(UIPointerInteraction(delegate: self))
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        updateShieldImageView(for: icon)
        updateAccessibilityLabels(for: icon)
    }
    
    func updateIcon(_ newIcon: PrivacyIcon) {
        icon = newIcon
    }
    
    private(set) var icon: PrivacyIcon {
        willSet {
            guard newValue != icon else { return }
            updateShieldImageView(for: newValue)
            updateAccessibilityLabels(for: newValue)
        }
    }
    
    private func updateShieldImageView(for icon: PrivacyIcon) {
        switch icon {
        case .daxLogo:
            daxLogoImageView.isHidden = false
        case .kahfLock:
            daxLogoImageView.image = UIImage(named: "KahfLock")
        case .kahfWorld:
            daxLogoImageView.image = UIImage(named: "KahfWorld")
        }
    }
    
    private func updateAccessibilityLabels(for icon: PrivacyIcon) {
        switch icon {
        case .daxLogo, .kahfLock, .kahfWorld:
            accessibilityLabel = UserText.privacyIconDax
            accessibilityHint = nil
            accessibilityTraits = .image
        }
    }
    
    func refresh() {
        updateShieldImageView(for: icon)
        updateAccessibilityLabels(for: icon)
    }
}

extension PrivacyIconView: UIPointerInteractionDelegate {
    
    public func pointerInteraction(_ interaction: UIPointerInteraction, styleFor region: UIPointerRegion) -> UIPointerStyle? {
        return .init(effect: .lift(.init(view: self)))
    }
    
}

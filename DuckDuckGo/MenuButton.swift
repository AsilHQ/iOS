//
//  MenuButton.swift
//  DuckDuckGo
//
//  Copyright © 2021 DuckDuckGo. All rights reserved.
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
import Core

protocol MenuButtonDelegate: NSObjectProtocol {
    func showMenu(_ button: MenuButton)
    func showBookmarks(_ button: MenuButton)
}

class MenuButton: UIButton {
    
    enum State {
        case menuImage
    }
    
    struct Constants {
        static let labelFadeDuration = 0.3
        static let buttonTouchDuration = 0.2
        static let tintAlpha: CGFloat = 0.5
        static let buttonSize: CGFloat = 24
    }
    
    weak var delegate: MenuButtonDelegate?
    private var currentState: State = .menuImage

    private let bookmarksIconView = UIImageView()
    private let anim = UIImageView(image: UIImage(named: "Menu-Vertical-24"))
    
    var hasUnread: Bool = false
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        configureUI()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        configureUI()
    }
    
    private func configureUI() {
        frame = CGRect(x: 0, y: 0, width: Constants.buttonSize, height: Constants.buttonSize)

        anim.frame = bounds
        anim.isUserInteractionEnabled = false
        bookmarksIconView.frame = bounds
        bookmarksIconView.isHidden = true
        
        addSubview(anim)
        addSubview(bookmarksIconView)
        
        addTarget(self, action: #selector(touchDown), for: .touchDown)
        addTarget(self, action: #selector(touchUp), for: [.touchUpInside, .touchCancel, .touchDragExit])
        
        addInteraction(UIPointerInteraction(delegate: self))
        decorate()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let centerPoint = CGPoint(x: bounds.midX, y: bounds.midY)
        anim.center = centerPoint
        bookmarksIconView.center = centerPoint
    }
    
    @objc private func touchDown() {
        tint(alpha: Constants.tintAlpha)
    }

    @objc private func touchUp() {
        tint(alpha: 1)
        if currentState == .menuImage {
            delegate?.showMenu(self)
        }
    }
    
    func setState(_ state: State, animated: Bool) {
        guard state != currentState else { return }
        
        switch state {
        case .menuImage:
            bookmarksIconView.isHidden = true
            anim.isHidden = false
        }
        
        currentState = state
    }
    
    private func tint(alpha: CGFloat, animated: Bool = true) {
        let setAlpha = {
            self.anim.alpha = alpha
            self.bookmarksIconView.alpha = alpha
        }
        animated ? UIView.animate(withDuration: Constants.buttonTouchDuration, animations: setAlpha) : setAlpha()
    }
}

extension MenuButton {
    
    private func decorate() {
        let theme = ThemeManager.shared.currentTheme
        tintColor = theme.barTintColor
        updateAppearanceForCurrentTheme()
    }

    private func updateAppearanceForCurrentTheme() {}

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            updateAppearanceForCurrentTheme()
        }
    }
}

extension MenuButton: UIPointerInteractionDelegate {
    
    func pointerInteraction(_ interaction: UIPointerInteraction, styleFor region: UIPointerRegion) -> UIPointerStyle? {
        return .init(effect: .highlight(.init(view: self)))
    }
}

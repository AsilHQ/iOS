//
//  TabSwitcherButton.swift
//  DuckDuckGo
//
//  Copyright © 2017 DuckDuckGo. All rights reserved.
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

import UIKit
import Lottie
import Core

protocol TabSwitcherButtonDelegate: NSObjectProtocol {
    func showTabSwitcher(_ button: TabSwitcherButton)
    func launchNewTab(_ button: TabSwitcherButton)
}

class TabSwitcherButton: UIButton {
    
    struct Constants {
        static let fontSize: CGFloat = 10
        static let fontWeight: CGFloat = 5
        static let maxTextTabs = 100
        static let labelFadeDuration = 0.3
        static let buttonTouchDuration = 0.2
        static let tintAlpha: CGFloat = 0.5

        static let pointerViewWidth: CGFloat = 30
        static let pointerViewHeight: CGFloat = 44
    }
    
    weak var delegate: TabSwitcherButtonDelegate?
    private var workItem: DispatchWorkItem?
    
    private let anim = LottieAnimationView(name: "new_tab")
    private let label = UILabel()
    let pointerView = UIView()
    
    var tabCount: Int = 0 {
        didSet { refresh() }
    }
    
    var hasUnread: Bool = false {
        didSet { anim.currentProgress = hasUnread ? 1.0 : 0.0 }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        configureUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureUI()
    }
    
    private func configureUI() {
        frame = CGRect(x: 0, y: 0, width: Constants.pointerViewWidth, height: Constants.pointerViewHeight)
        
        anim.frame = bounds
        anim.isUserInteractionEnabled = false
        anim.configuration = LottieConfiguration(renderingEngine: .mainThread)
        
        label.frame = bounds
        label.textAlignment = .center
        label.isUserInteractionEnabled = false
        
        pointerView.frame = bounds
        pointerView.isUserInteractionEnabled = false
        
        addSubview(pointerView)
        addSubview(label)
        addSubview(anim)
        
        addTarget(self, action: #selector(touchDown), for: .touchDown)
        addTarget(self, action: #selector(touchUp), for: [.touchUpInside, .touchCancel, .touchDragExit])
        addTarget(self, action: #selector(touchLongPress), for: .touchDownRepeat)
        
        decorate()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        let centerPoint = CGPoint(x: bounds.midX, y: bounds.midY)
        anim.center = centerPoint
        label.center = centerPoint
        pointerView.center = centerPoint
    }
    
    private func refresh() {
        if tabCount == 0 {
            label.text = nil
            return
        }
        let text = tabCount >= Constants.maxTextTabs ? "~" : "\(tabCount)"
        label.attributedText = NSAttributedString(string: text, attributes: attributes())
    }
    
    @objc private func touchDown() {
        tint(alpha: Constants.tintAlpha)
        workItem?.cancel()
        
        workItem = DispatchWorkItem {
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            self.delegate?.launchNewTab(self)
            self.workItem = nil
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + GestureToolbarButton.Constants.minLongPressDuration, execute: workItem!)
    }
    
    @objc private func touchUp() {
        tint(alpha: 1)
        workItem?.cancel()
        guard workItem != nil else { return }
        delegate?.showTabSwitcher(self)
    }
    
    @objc private func touchLongPress() {
        tint(alpha: 1)
        delegate?.launchNewTab(self)
    }
    
    func incrementAnimated() {
        anim.play()
        UIView.animate(withDuration: Constants.labelFadeDuration, animations: {
            self.label.alpha = 0.0
        }, completion: { _ in
            self.tabCount += 1
            UIView.animate(withDuration: Constants.labelFadeDuration, animations: {
                self.label.alpha = 1.0
            })
        })
    }
    
    private func attributes() -> [NSAttributedString.Key: Any] {
        
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = NSTextAlignment.center
        
        let font = UIFont.systemFont(ofSize: Constants.fontSize, weight: UIFont.Weight(Constants.fontWeight))
        return [ NSAttributedString.Key.font: font,
                 NSAttributedString.Key.foregroundColor: tintColor as Any,
                 NSAttributedString.Key.paragraphStyle: paragraphStyle ]
    }
    
    private func tint(alpha: CGFloat, animated: Bool = true) {
        let setAlpha = {
            self.anim.alpha = alpha
            self.label.alpha = alpha
        }
        
        if animated {
            UIView.animate(withDuration: Constants.buttonTouchDuration, animations: setAlpha)
        } else {
            setAlpha()
        }
    }
    
    private func decorate() {
        let theme = ThemeManager.shared.currentTheme
        tintColor = theme.barTintColor
        label.textColor = theme.barTintColor
        updateAnimationColor()
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            updateAnimationColor()
        }
    }

    private func updateAnimationColor() {
        anim.animation = LottieAnimation.named(traitCollection.userInterfaceStyle == .dark ? "new_tab" : "new_tab_dark")
    }
}

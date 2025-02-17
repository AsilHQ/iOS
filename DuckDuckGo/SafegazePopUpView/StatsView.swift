//
//  StatsView.swift
//  Kahf Browser
//
//  Copyright © 2025 Kahf Browser. All rights reserved.
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
import SnapKit

class StatsView: UIView {
    
    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        view.layer.cornerRadius = 10
        view.clipsToBounds = true
        return view
    }()
    
    private let stackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 20
        stack.alignment = .leading // Align stats to the leading edge
        stack.distribution = .fillEqually
        return stack
    }()
    
    private func createStatView(numberText: String, descriptionText: String) -> UIStackView {
        let numberLabel = UILabel()
        numberLabel.text = numberText
        numberLabel.font = FontHelper.poppinsUIFont(size: 19, weight: .semibold)
        numberLabel.textColor = .white
        numberLabel.textAlignment = .left
        
        let descriptionLabel = UILabel()
        descriptionLabel.text = descriptionText
        descriptionLabel.font = FontHelper.poppinsUIFont(size: 12, weight: .regular)
        descriptionLabel.textColor = .white
        descriptionLabel.textAlignment = .left
        descriptionLabel.numberOfLines = 2 // Allow a maximum of 2 lines
        descriptionLabel.lineBreakMode = .byWordWrapping // Ensure proper wrapping
        descriptionLabel.adjustsFontSizeToFitWidth = false // Prevents font scaling

        let verticalStack = UIStackView(arrangedSubviews: [numberLabel, descriptionLabel])
        verticalStack.axis = .vertical
        verticalStack.alignment = .leading
        verticalStack.spacing = 4
        
        return verticalStack
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        addSubview(containerView)
        containerView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.height.greaterThanOrEqualTo(80)
        }
        
        containerView.addSubview(stackView)
        stackView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(16)
        }
        
        let stats = [
            ("\(AppUserDefaults().safegazeHarmfulSites)", "Harmful Sites"),
            ("\(AppUserDefaults().safegazeBlurredImageCount)", "Indecent Pictures"),
            ("\(AppUserDefaults().blockedTrackersCount)", "Ads + Trackers")
        ]
        
        for (number, description) in stats {
            let statView = createStatView(numberText: number, descriptionText: description)
            stackView.addArrangedSubview(statView)
        }
    }
}

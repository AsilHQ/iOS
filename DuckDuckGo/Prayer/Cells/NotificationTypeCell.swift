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

import Foundation
import UIKit

class NotificationTypeCell: UITableViewCell {
    
    lazy var bgView: UIView = {
        let view = UIView()
        view.backgroundColor = .white
        view.layer.cornerRadius = 10
        return view
    }()
    
    lazy var nameLabel: UILabel = {
        let view = UILabel()
        view.textColor = .ows_gray01
        view.font = UIFont.interVariable(ofSize: 14, weight: .semibold)
        return view
    }()
    
    lazy var descriptionNameLabel: UILabel = {
        let view = UILabel()
        view.textColor = .ows_gray03
        view.font = UIFont.interVariable(ofSize: 12, weight: .regular)
        return view
    }()
    
    lazy var alertImageView: UIImageView = {
        let view = UIImageView()
        return view
    }()

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

    init(reuseIdentifier: String?, method: NotificationMethod, isSelected: Bool) {
        super.init(style: .default, reuseIdentifier: reuseIdentifier)
        addSubviews()
        setupConstraints()
        self.accessoryType = .none
        self.selectionStyle = .none
        self.backgroundColor = .clear
        self.nameLabel.text = method.title
        self.descriptionNameLabel.text = method.detail
        if isSelected {
            bgView.layer.borderColor = UIColor.ows_signalBlue.cgColor
            bgView.layer.borderWidth = 2
            bgView.backgroundColor = .ows_kahf_selected_item_blue_background
            nameLabel.textColor = UIColor.ows_signalBlue
            alertImageView.image = method.icon.withTintColor(UIColor.ows_signalBlue)
        }
        else {
            bgView.layer.borderColor = UIColor.clear.cgColor
            bgView.layer.borderWidth = 0
            bgView.backgroundColor = .ows_gray06
            nameLabel.textColor = UIColor.ows_gray01
            alertImageView.image = method.icon
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setupConstraints() {
        bgView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalToSuperview()
            make.bottom.equalToSuperview().offset(-10)
        }
        alertImageView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(26)
            make.height.width.equalTo(18)
            make.leading.equalToSuperview().offset(23)
        }
        nameLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(19)
            make.leading.equalTo(alertImageView.snp.trailing).offset(18)
        }
        descriptionNameLabel.snp.makeConstraints { make in
            make.top.equalTo(nameLabel.snp.bottom).offset(2)
            make.leading.equalTo(alertImageView.snp.trailing).offset(18)
        }
    }
    
    func addSubviews() {
        contentView.addSubview(bgView)
        bgView.addSubview(nameLabel)
        bgView.addSubview(descriptionNameLabel)
        bgView.addSubview(alertImageView)
    }
}

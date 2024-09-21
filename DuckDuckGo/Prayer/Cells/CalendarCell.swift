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


import UIKit

class CalendarCell: UITableViewCell {
    
    lazy var bgView: UIView = {
       let view = UIView()
        return view
    }()
    
    lazy var smallTitleLabel: UILabel = {
        let view = UILabel()
        view.textColor = UIColor(hex: "3E8DFF")
        view.font = UIFont.interVariable(ofSize: 12, weight: .semibold)
        return view
    }()
    
    lazy var bigTitleLabel: UILabel = {
        let view = UILabel()
        view.textColor = .white
        view.font = UIFont.interVariable(ofSize: 24, weight: .bold)
        return view
    }()
    
    lazy var contentLabel: UILabel = {
        let view = UILabel()
        view.textColor = .white
        view.font = UIFont.interVariable(ofSize: 12, weight: .regular)
        return view
    }()
    
    lazy var leftButton: UIButton = {
        let button = UIButton()
        button.setImage(UIImage(named: "KahfCalendarLeft"), for: .normal)
        button.snp.makeConstraints { make in make.width.height.equalTo(30) }
        button.addTarget(self, action: #selector(leftButtonTapped), for: .touchUpInside)
        return button
    }()
    
    lazy var rightButton: UIButton = {
        let button = UIButton()
        button.setImage(UIImage(named: "KahfCalendarRight"), for: .normal)
        button.snp.makeConstraints { make in make.width.height.equalTo(30) }
        button.addTarget(self, action: #selector(rightButtonTapped), for: .touchUpInside)
        return button
    }()
    
    var leftButtonAction: (() -> Void)?
    var rightButtonAction: (() -> Void)?

    init(reuseIdentifier: String?, day: Day, city: String) {
        super.init(style: .default, reuseIdentifier: reuseIdentifier)
        addSubviews()
        setupConstraints()
        self.accessoryType = .none
        self.selectionStyle = .none
        self.backgroundColor = .clear
        self.bigTitleLabel.text = day.name
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd MMMM yyyy"
        self.smallTitleLabel.text = city + "  |  " + dateFormatter.string(from: day.date)
        self.contentLabel.text = convertToIslamicDate(day.date)
        if day == .today {
            leftButton.isHidden = false
            rightButton.isHidden = false
        }
        else if day == .tomorrow {
            leftButton.isHidden = false
            rightButton.isHidden = true
        }
        else {
            leftButton.isHidden = true
            rightButton.isHidden = false
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setupConstraints() {
        bgView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        bigTitleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(10)
            make.height.equalTo(29)
            make.centerX.equalToSuperview()
        }
        smallTitleLabel.snp.makeConstraints { make in
            make.top.equalTo(bigTitleLabel.snp.bottom).offset(7)
            make.height.equalTo(15)
            make.centerX.equalToSuperview()
        }
        contentLabel.snp.makeConstraints { make in
            make.top.equalTo(smallTitleLabel.snp.bottom).offset(5)
            make.height.equalTo(15)
            make.centerX.equalToSuperview()
        }
        leftButton.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(20)
            make.top.equalToSuperview().offset(55)
        }
        rightButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-20)
            make.top.equalToSuperview().offset(55)
        }
    }
    
    func addSubviews() {
        contentView.addSubview(bgView)
        bgView.addSubview(smallTitleLabel)
        bgView.addSubview(bigTitleLabel)
        bgView.addSubview(contentLabel)
        bgView.addSubview(leftButton)
        bgView.addSubview(rightButton)
    }
    
    @objc func leftButtonTapped() {
        leftButtonAction?()
    }
    
    @objc func rightButtonTapped() {
        rightButtonAction?()
    }
    
    func convertToIslamicDate(_ date: Date) -> String {
        let calendar = Calendar(identifier: .islamicUmmAlQura)
        let components = calendar.dateComponents([.day, .month, .year], from: date)

        let day = components.day ?? 1
        let month = components.month ?? 1
        let year = components.year ?? 1444

        // Convert month number to its Arabic representation
        let arabicMonths = ["Muharram", "Safar", "Rabi' al-Awwal", "Rabi' al-Thani", "Jumada al-Awwal", "Jumada al-Thani", "Rajab", "Sha'ban", "Ramadan", "Shawwal", "Dhu al-Qi'dah", "Dhu al-Hijjah"]
        let arabicMonth = arabicMonths[month - 1]

        return "Dgy \(arabicMonth) \(day), \(year) AH"
    }
}


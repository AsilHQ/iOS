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

class TimeCell: UITableViewCell {
    
    lazy var bgView: UIView = {
        let view = UIView()
        view.backgroundColor = Date() > time ? .ows_gray06 : .white
        view.isUserInteractionEnabled = !(Date() > time)
        view.layer.cornerRadius = 10
        return view
    }()
    
    lazy var nameLabel: UILabel = {
        let view = UILabel()
        view.textColor = .ows_gray01
        view.font = UIFont.interVariable(ofSize: 16, weight: .medium)
        view.alpha = Date() > time ? 0.3 : 1.0
        return view
    }()
    
    lazy var timeLabel: UILabel = {
        let view = UILabel()
        view.textColor = .ows_kahf_gray2
        view.font = UIFont.interVariable(ofSize: 12, weight: .medium)
        view.alpha = Date() > time ? 0.3 : 1.0
        return view
    }()
    
    lazy var alarmButton: UIButton = {
        let button = UIButton()
        button.addTarget(self, action: #selector(alarmButtonTapped), for: .touchUpInside)
        button.snp.makeConstraints { make in
            make.width.equalTo(18)
            make.height.equalTo(18)
        }
        return button
    }()
    
    var alarmButtonAction: (() -> Void)?
    var time: Date
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

    init(reuseIdentifier: String?, name: String, time: Date, alarm: Alarm?) {
        self.time = time
        super.init(style: .default, reuseIdentifier: reuseIdentifier)
        addSubviews()
        setupConstraints()
        self.accessoryType = .none
        self.selectionStyle = .none
        self.backgroundColor = .clear
        self.nameLabel.text = name
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.timeZone = TimeZone.current
        self.timeLabel.text = "\(formatter.string(from: time))"
        if let alarm = alarm {
            if alarm.mediaLabel == "" {
                alarmButton.setImage(UIImage(named: "KahfAlertNotif")!.withTintColor(UIColor.ows_signalBlue), for: .normal)
            }
            else {
                alarmButton.setImage(UIImage(named: "KahfAlertAdhan")!.withTintColor(UIColor.ows_signalBlue), for: .normal)
            }
        }
        else {
            alarmButton.setImage(UIImage(named: "KahfAlertDisabled")!, for: .normal)
        }
        if Date() > time {
            bgView.setShadow(radius: 0.0, opacity: 0, offset: CGSize(width: 0, height: 0), color: UIColor(red: 0, green: 0, blue: 0, alpha: 0))
        }
        else {
            bgView.setShadow(radius: 10.0, opacity: 1, offset: CGSize(width: 0, height: 4), color: UIColor(red: 0, green: 0, blue: 0, alpha: 0.05))
        }
        
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setupConstraints() {
        bgView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(18)
            make.top.equalToSuperview()
            make.bottom.equalToSuperview().offset(-10)
        }
        nameLabel.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.leading.equalToSuperview().offset(24)
        }
        timeLabel.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.trailing.equalTo(alarmButton.snp.leading).offset(-26)
        }
        alarmButton.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.trailing.equalToSuperview().offset(-20)
        }
    }
    
    func addSubviews() {
        contentView.addSubview(bgView)
        bgView.addSubview(nameLabel)
        bgView.addSubview(timeLabel)
        bgView.addSubview(alarmButton)
    }
    
    @objc func alarmButtonTapped() {
        alarmButtonAction?()
    }
}

extension UIView {
    func setShadow(radius: CGFloat = 2.0, opacity: Float = 0.66, offset: CGSize = .zero, color: UIColor = UIColor.black) {
        layer.shadowRadius = radius
        layer.shadowOpacity = opacity
        layer.shadowOffset = offset
        layer.shadowColor = color.cgColor
    }
}

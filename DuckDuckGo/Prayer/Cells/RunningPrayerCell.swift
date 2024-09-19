//
// Copyright 2021 Kahf Messenger, LLC
// SPDX-License-Identifier: AGPL-3.0-only
//


import UIKit
import Adhan

class RunningPrayerCell: UITableViewCell {

    lazy var backgroundImage: UIImageView = {
       let imageView = UIImageView(image: UIImage(named: "KahfRunningPrayer"))
       imageView.layer.masksToBounds = true
       imageView.layer.cornerRadius = 10
       return imageView
    }()
    
    lazy var smallTitleLabel: UILabel = {
        let view = UILabel()
        view.text = "Running Prayer"
        view.textColor = .white
        view.font = UIFont.interVariable(ofSize: 14, weight: .regular)
        return view
    }()
    
    lazy var bigTitleLabel: UILabel = {
        let view = UILabel()
        view.textColor = .white
        view.font = UIFont.interVariable(ofSize: 36, weight: .bold)
        return view
    }()
    
    lazy var contentLabel: UILabel = {
        let view = UILabel()
        view.textColor = .white
        view.font = UIFont.interVariable(ofSize: 11, weight: .regular)
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
    
    let prayerManager = PrayerManager.shared

    init(reuseIdentifier: String?, current: String, next: Prayer, nextPrayerTime: Date) {
        super.init(style: .default, reuseIdentifier: reuseIdentifier)
        addSubviews()
        setupConstraints()
        self.accessoryType = .none
        self.selectionStyle = .none
        self.backgroundColor = .clear
        self.bigTitleLabel.text = current
        self.contentLabel.text = prayerManager.calculateNextPrayerTime(next: next, date: nextPrayerTime)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setupConstraints() {
        backgroundImage.snp.makeConstraints { make in
            make.height.equalTo(146)
            make.leading.trailing.equalToSuperview().inset(20)
        }
        smallTitleLabel.snp.makeConstraints { make in
            make.height.equalTo(17)
            make.leading.equalToSuperview().offset(55)
            make.top.equalToSuperview().offset(30)
        }
        bigTitleLabel.snp.makeConstraints { make in
            make.height.equalTo(44)
            make.leading.equalToSuperview().offset(55)
            make.top.equalTo(smallTitleLabel.snp.bottom).offset(2)
        }
        contentLabel.snp.makeConstraints { make in
            make.height.equalTo(13)
            make.leading.equalToSuperview().offset(55)
            make.top.equalTo(bigTitleLabel.snp.bottom).offset(3)
        }
    }
    
    func addSubviews() {
        addSubview(backgroundImage)
        addSubview(smallTitleLabel)
        addSubview(bigTitleLabel)
        addSubview(contentLabel)
    }

}

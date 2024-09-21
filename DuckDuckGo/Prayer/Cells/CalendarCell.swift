//
// Copyright 2021 Kahf Messenger, LLC
// SPDX-License-Identifier: AGPL-3.0-only
//


import UIKit

class CalendarCell: UITableViewCell {
    
    lazy var bgView: UIView = {
       let view = UIView()
        return view
    }()
    
    lazy var smallTitleLabel: UILabel = {
        let view = UILabel()
        view.textColor = .blue
//        view.font = UIFont.interSemiBold12
        return view
    }()
    
    lazy var bigTitleLabel: UILabel = {
        let view = UILabel()
        view.textColor = .black
//        view.font = UIFont.interBold24
        return view
    }()
    
    lazy var contentLabel: UILabel = {
        let view = UILabel()
        view.textColor = .ows_gray03
//        view.font = UIFont.interRegular12
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
    
    var leftButtonAction : (() -> Void)?
    var rightButtonAction : (() -> Void)?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

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


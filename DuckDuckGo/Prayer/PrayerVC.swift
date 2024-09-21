//
// Copyright 2021 Kahf Messenger, LLC
// SPDX-License-Identifier: AGPL-3.0-only
//


import Foundation
import SnapKit
import UIKit
import CoreLocation
import Adhan
import PanModal

enum PrayerContent {
    case runningPrayer(current: Prayer, next: Prayer, countdown: Date)
    case calendar(day: Day, city: String)
    case times(name: String, time: Date)
}

enum Day: CaseIterable {
    case yesterday
    case today
    case tomorrow
    
    var date: Date {
        let now = Date()
        var calendar = Calendar.current
        calendar.timeZone = TimeZone.current
        switch self {
        case .yesterday:
            return calendar.date(byAdding: .day, value: -1, to: now) ?? now
        case .today:
            return now
        case .tomorrow:
            return calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: now) ?? now)
        }
    }
    
    var name: String {
        switch self {
        case .yesterday:
            return "Yesterday"
        case .today:
            return "Today"
        case .tomorrow:
            return "Tomorrow"
        }
    }
}

@objc
class PrayerVC: UITableViewController {

    private var contents: [PrayerContent] = []
    private var alarmNotificationOptions:  AlarmNotificationOptionsVC?
    var locationManager = CLLocationManager()
    var coordinate: CLLocationCoordinate2D?
    var day: Day = .today
    var prayerManager = PrayerManager.shared
    private let scheduler: NotificationSchedulerDelegate = NotificationScheduler()
    var alarms = Store.shared.alarms
    var willDisappear: (()-> Void)?
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.separatorStyle = .none
        tableView.rowHeight = UITableView.automaticDimension
        tableView.contentInset = UIEdgeInsets(top: 22, left: 0, bottom: 0, right: 0)
        tableView.showsVerticalScrollIndicator = false
        tableView.backgroundColor = .blue40
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        checkAndRequestLocationAuthorization()
        NotificationCenter.default.addObserver(self, selector: #selector(handleChangeNotification(_:)), name: Store.changedNotification, object: nil)
        scheduler.requestAuthorization()
        scheduler.registerNotificationCategories()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.contents.removeAll()
        self.tableView.reloadData()
        clearOldAlarms()
        if let coordinate = coordinate {
            fetchTimes(coordinate: coordinate)
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if alarmNotificationOptions == nil {
            willDisappear?()
        }
    }
    
//    func settingsContextMenu() -> ContextMenu {
//        var contextMenuActions: [ContextMenuAction] = []
//        contextMenuActions.append(
//            ContextMenuAction(
//                title: NSLocalizedString("KAHF_MADHAB_ASR_TIME",
//                                         comment: "Title for the prayer's default mode."),
//                attributes: [],
//                handler: { [weak self] (_) in
//                    self?.showParameterPickerVC(isCalculationMethods: false)
//                }))
//        contextMenuActions.append(
//            ContextMenuAction(
//                title: NSLocalizedString("KAHF_CALCULATION_METHOD",
//                                         comment: "Title for the prayer's default mode."),
//                attributes: [],
//                handler: { [weak self] (_) in
//                    self?.showParameterPickerVC(isCalculationMethods: true)
//                }))
//        return .init(contextMenuActions)
//    }
    
    func showParameterPickerVC(isCalculationMethods: Bool) {
        let vc = PrayerParameterPickerVC()
        vc.isCalculationMethods = isCalculationMethods
        self.navigationController?.pushViewController(vc, animated: true)
    }
    
    func fetchTimes(coordinate: CLLocationCoordinate2D) {
        getAddressFromCoordinates(latitude: coordinate.latitude, longitude: coordinate.longitude) { city in
            self.contents.removeAll()
            self.prayerManager.getCurrentNextPrayerTimes(coordinate: coordinate, completion: { current, next, countdown in
                guard let current = current, let next = next, let countdown = countdown else { return }
                self.contents.append(.runningPrayer(current: current, next: next, countdown: countdown))
                if let city = city {
                    self.contents.append(.calendar(day: self.day, city: city))
                }
                self.prayerManager.fetchTimes(coordinate: coordinate, day: self.day.date) { times in
                    guard let times = times else { return }
                    self.contents.append(.times(name: "Fajr", time: times.fajr))
                    self.contents.append(.times(name: "Sunrise", time: times.sunrise))
                    self.contents.append(.times(name: "Dhuhr", time: times.dhuhr))
                    self.contents.append(.times(name: "Asr", time: times.asr))
                    self.contents.append(.times(name: "Magrib", time: times.maghrib))
                    self.contents.append(.times(name: "Isha", time: times.isha))
                    self.tableView.reloadData()
                }
            })
        }
    }
    
    func clearOldAlarms() {
        alarms.uuids.forEach { id in
            if let alarm = alarms.getAlarm(ByUUIDStr: id) {
                let now = Date()
                if alarm.date < now {
                    print("\(alarm.id) alarmDate\(alarm.date) now \(now)")
                    alarms.remove(alarm.id)
                }
            }
        }
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return contents.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let content = contents[indexPath.row]

        switch content {
        case .runningPrayer(let current, let next, let nextPrayerTime):
        return RunningPrayerCell(reuseIdentifier: nil, current: PrayerManager.shared.getRawValue(prayer: current), next: next, nextPrayerTime: nextPrayerTime)
        case .calendar(let day, let city):
            let cell = CalendarCell(reuseIdentifier: nil, day: day, city: city)
            cell.leftButtonAction = { self.goToPrevDay() }
            cell.rightButtonAction = { self.goToNextDay() }
            return cell
        case .times(let name, let time):
            let buttonAction = {
                self.alarmNotificationOptions = AlarmNotificationOptionsVC()
                if let vc = self.alarmNotificationOptions {
                    vc.willDisappear = {
                        self.alarmNotificationOptions = nil
                    }
                    if let alarm = self.alarms.getAlarm(ByUUIDStr: "alarm_set_at_\(time.timeIntervalSince1970)") {
                        if alarm.mediaLabel.isEmpty {
                            vc.selectedMethod = .notification
                        }
                        else {
                            vc.selectedMethod = .adhan
                        }
                    } else {
                        vc.selectedMethod = .silent
                    }
                    vc .changeNotificationOption = { method in
                        self.editNotification(method: method, time: time, name: name)
                        vc.dismiss(animated: true)
                    }
                    self.presentPanModal(vc)
                }
            }
            let cell = TimeCell(reuseIdentifier: nil, name: name, time: time, alarm: self.alarms.getAlarm(ByUUIDStr: "alarm_set_at_\(time.timeIntervalSince1970)"))
            cell.alarmButtonAction = buttonAction
            return cell
        }
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let content = contents[indexPath.row]

        switch content {
            case .runningPrayer: return 146
            case .calendar:  return 119
            case .times: return 70
        }
    }
    
    func goToPrevDay() {
        if day == .today {
            day = .yesterday
        } else if day == .tomorrow {
            day = .today
        }
        else {
            return
        }
        update()
    }
    
    func goToNextDay() {
        if day == .today {
            day = .tomorrow
        } else if day == .yesterday {
            day = .today
        }
        else {
            return
        }
        update()
    }
    
    func update() {
        guard let coordinate = coordinate else { return }
        self.fetchTimes(coordinate: coordinate)
    }
    
    func editNotification(method: NotificationMethod, time: Date, name: String) {
        if let alarm = self.alarms.getAlarm(ByUUIDStr: "alarm_set_at_\(time.timeIntervalSince1970)") {
            switch method {
                case .silent: self.alarms.remove("alarm_set_at_\(time.timeIntervalSince1970)")
                case .notification: alarm.mediaLabel = ""
                case .adhan: alarm.mediaLabel = "tickle.mp3"
            }
        }
        else {
            switch method {
                case .silent: return
                case .notification:
                    let alarm = Alarm(id: "alarm_set_at_\(time.timeIntervalSince1970)", date: time, enabled: true, snoozeEnabled: true, repeatWeekdays: [], mediaID: "bell", mediaLabel: "", label: name)
                    self.alarms.add(alarm)
                case .adhan:
                    let alarm = Alarm(id: "alarm_set_at_\(time.timeIntervalSince1970)", date: time, enabled: true, snoozeEnabled: true, repeatWeekdays: [], mediaID: "bell", mediaLabel:  "tickle.mp3", label: name)
                    self.alarms.add(alarm)
            }
        }
        self.tableView.reloadData()
    }
    
    @objc func handleChangeNotification(_ notification: Notification) {
        
        guard let userInfo = notification.userInfo else {
            return
        }
        
        // Handle changes to contents
        if let changeReason = userInfo[Alarm.changeReasonKey] as? String {
            let newValue = userInfo[Alarm.newValueKey]
            let oldValue = userInfo[Alarm.oldValueKey]
            switch (changeReason, newValue, oldValue) {
            case let (Alarm.removed, (uuid as String)?, (_ as Int)?):
                if alarms.count == 0 {
                    self.navigationItem.leftBarButtonItem = nil
                }
                scheduler.cancelNotification(ByUUIDStr: uuid)
            case let (Alarm.added, (index as Int)?, _):
                let alarm = alarms[index]
                scheduler.setNotification(date: alarm.date, ringtoneName: alarm.mediaLabel, repeatWeekdays: alarm.repeatWeekdays, snoozeEnabled: alarm.snoozeEnabled, onSnooze: false, uuid: alarm.id, label: alarm.label)
            case let (Alarm.updated, (index as Int)?, _):
                let alarm = alarms[index]
                let id = alarm.id
                if alarm.enabled {
                    scheduler.updateNotification(ByUUIDStr: id, date: alarm.date, ringtoneName: alarm.mediaLabel, repeatWeekdays: alarm.repeatWeekdays, snoonzeEnabled: alarm.snoozeEnabled, label: alarm.label)
                } else {
                    scheduler.cancelNotification(ByUUIDStr: id)
                }
            default: tableView.reloadData()
            }
        } else {
            tableView.reloadData()
        }
    }
}

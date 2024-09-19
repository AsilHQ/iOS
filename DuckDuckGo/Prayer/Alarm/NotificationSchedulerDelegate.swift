//
// Copyright 2023 Kahf Messenger, LLC
// SPDX-License-Identifier: AGPL-3.0-only
//



import Foundation
import UIKit

protocol NotificationSchedulerDelegate {
    func requestAuthorization()
    func registerNotificationCategories()
    func setNotification(date: Date, ringtoneName: String, repeatWeekdays: [Int], snoozeEnabled: Bool, onSnooze: Bool, uuid: String, label: String)
    func cancelNotification(ByUUIDStr uuid: String)
    func updateNotification(ByUUIDStr uuid: String, date: Date, ringtoneName: String, repeatWeekdays: [Int], snoonzeEnabled: Bool, label: String)
    func syncAlarmStateWithNotification()
}


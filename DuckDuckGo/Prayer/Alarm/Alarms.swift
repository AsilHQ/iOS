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

class Alarms: Codable {
    private var alarms: [Alarm]
    
    enum CodingKeys: CodingKey {
        case alarms
    }
    
    init() {
        self.alarms = [Alarm]()
    }
    
    required init(from decoder: Decoder) throws {
        let container: KeyedDecodingContainer<Alarms.CodingKeys> = try decoder.container(keyedBy: Alarms.CodingKeys.self)
        
        self.alarms = try container.decode([Alarm].self, forKey: Alarms.CodingKeys.alarms)
        
    }
    
    func getAlarm(ByUUIDStr uuidString: String) -> Alarm?{
        return alarms.first(where: {$0.id == uuidString})
    }
    
    func encode(to encoder: Encoder) throws {
        var container: KeyedEncodingContainer<Alarms.CodingKeys> = encoder.container(keyedBy: Alarms.CodingKeys.self)
        
        try container.encode(self.alarms, forKey: Alarms.CodingKeys.alarms)
    }
    
    
    func add(_ alarm: Alarm) {
        alarms.append(alarm)
        let newIndex = alarms.firstIndex { $0.id == alarm.id }!
        Store.shared.save(self, notifying: alarm, userInfo: [
            Alarm.changeReasonKey: Alarm.added,
            Alarm.newValueKey: newIndex
        ])
    }
    
    func remove(_ id: String) {
        guard let index = alarms.firstIndex(where: { $0.id == id }) else { return }
        remove(at: index)
    }
    
    func remove(at index: Int) {
        let alarm = alarms[index]
        let uuidStr = alarm.id
        alarms.remove(at: index)
        Store.shared.save(self, notifying: nil, userInfo: [
            Alarm.changeReasonKey: Alarm.removed,
            Alarm.oldValueKey: index,
            Alarm.newValueKey: uuidStr
        ])
    }
    
    func update(_ alarm: Alarm) {
        guard let index = alarms.firstIndex(where: { $0.id == alarm.id }) else { return }
        Store.shared.save(self, notifying: alarm, userInfo: [
            Alarm.changeReasonKey: Alarm.updated,
            Alarm.oldValueKey: index,
            Alarm.newValueKey: index
        ])
    }
    
    var count: Int {
        return alarms.count
    }
    
    var uuids: Set<String> {
        return Set(alarms.map { $0.id })
    }
    
    subscript(index: Int) -> Alarm {
        return alarms[index]
    }
    
}

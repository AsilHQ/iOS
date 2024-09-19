//
// Copyright 2023 Kahf Messenger, LLC
// SPDX-License-Identifier: AGPL-3.0-only
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

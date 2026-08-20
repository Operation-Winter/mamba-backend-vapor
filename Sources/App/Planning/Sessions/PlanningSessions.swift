//
//  PlanningSessions.swift
//  
//
//  Created by Armand Kamffer on 2020/10/01.
//

import Foundation

actor PlanningSessions {
    private var storage: [String : PlanningSession]
    private var reservedIDs: Set<String> = []
    
    var count: Int {
        storage.count
    }
    
    init(storage: [String : PlanningSession] = [:]) {
        self.storage = storage
    }
    
    func add(_ session: PlanningSession) {
        reservedIDs.remove(session.id)
        storage[session.id] = session
    }
    
    func remove(_ session: PlanningSession) {
        storage[session.id] = nil
    }

    func reserveNextID() -> String? {
        for value in 0...999999 {
            let id = String(format: "%06d", value)
            guard storage[id] == nil, !reservedIDs.contains(id) else { continue }
            reservedIDs.insert(id)
            return id
        }
        return nil
    }
    
    func find(id: String) -> PlanningSession? {
        storage[id]
    }
    
    func exists(id: String) -> Bool {
        storage.keys.contains(id)
    }
}

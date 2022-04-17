//
//  PlanningSessions.swift
//  
//
//  Created by Armand Kamffer on 2020/10/01.
//

import Foundation

actor PlanningSessions {
    private var storage: [String : PlanningSession]
    
    var count: Int {
        storage.count
    }
    
    init(storage: [String : PlanningSession] = [:]) {
        self.storage = storage
    }
    
    func add(_ session: PlanningSession) {
        storage[session.id.value] = session
    }
    
    func remove(_ session: PlanningSession) {
        storage[session.id.value] = nil
    }
    
    func find(id: String) -> PlanningSession? {
        storage[id]
    }
    
    func exists(id: String) -> Bool {
        storage.keys.contains(id)
    }
}

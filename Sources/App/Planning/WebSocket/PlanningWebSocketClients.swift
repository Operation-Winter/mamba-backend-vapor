//
//  PlanningWebSocketClients.swift
//  
//
//  Created by Armand Kamffer on 2020/10/01.
//

import Foundation

class PlanningWebSocketClients: WebSocketClients<PlanningWebSocketClient> {
    func find(sessionId: String, type: PlanningSystemType) -> [PlanningWebSocketClient] {
        storage.filter { $1.sessionId == sessionId && $1.type == type }.map { $1 }
    }
}

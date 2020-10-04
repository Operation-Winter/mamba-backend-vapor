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
    
    func close(sessionId: String, type: PlanningSystemType) {
        find(sessionId: sessionId, type: type).forEach {
            _ = $0.socket.close(code: .normalClosure)
            remove($0)
        }
    }
    
    func close(_ uuid: UUID) {
        guard let client = find(uuid) else { return }
        _ = client.socket.close(code: .normalClosure)
        remove(client)
    }
}

//
//  PlanningWebSocketClient.swift
//  
//
//  Created by Armand Kamffer on 2020/10/01.
//

import Vapor

class PlanningWebSocketClient: WebSocketClient {
    var id: UUID
    var socket: WebSocket
    var sessionId: String
    var type: PlanningSystemType
    
    init(id: UUID, socket: WebSocket, sessionId: String, type: PlanningSystemType) {
        self.id = id
        self.socket = socket
        self.sessionId = sessionId
        self.type = type
    }
}

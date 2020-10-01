//
//  PlanningSystem.swift
//  
//
//  Created by Armand Kamffer on 2020/10/01.
//

import Vapor

class PlanningSystem {
    private(set) var clients: WebSocketClients<PlanningWebSocketClient>
    private(set) var sessions: PlanningSessions
    
    init(eventLoop: EventLoop) {
        clients = WebSocketClients(eventLoop: eventLoop)
        sessions = PlanningSessions()
    }
    
    func connect(_ webSocket: WebSocket, type: PlanningSystemType) {
        webSocket.onBinary { [unowned self] webSocket, buffer in
            parseBufferMessage(webSocket: webSocket, buffer: buffer, type: type)
        }
    }
    
    func parseBufferMessage(webSocket: WebSocket, buffer: ByteBuffer, type: PlanningSystemType) {
        switch type {
        case .host:
            guard let command = buffer.decodeWebSocketMessage(PlanningCommands.HostServerReceive.self) else {
                //TODO: MAM-112: Invalid command
                return
            }
            execute(command: command, webSocket: webSocket)
        case .join:
            guard let command = buffer.decodeWebSocketMessage(PlanningCommands.JoinServerReceive.self) else {
                //TODO: MAM-112: Invalid command
                return
            }
            execute(command: command, webSocket: webSocket)
        }
    }
}

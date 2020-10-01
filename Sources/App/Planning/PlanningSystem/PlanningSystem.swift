//
//  PlanningSystem.swift
//  
//
//  Created by Armand Kamffer on 2020/10/01.
//

import Vapor

class PlanningSystem {
    private(set) var clients: PlanningWebSocketClients
    private(set) var sessions: PlanningSessions
    
    init(eventLoop: EventLoop) {
        clients = PlanningWebSocketClients(eventLoop: eventLoop)
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

extension PlanningSystem: PlanningSessionDelegate {
    func send(command: PlanningCommands.HostServerSend, clientUuid: UUID) {
        guard
            let client = clients.find(clientUuid),
            let data = try? JSONEncoder().encode(command)
        else {
            return
        }
        client.socket.send([UInt8](data))
    }
    
    func send(command: PlanningCommands.JoinServerSend, clientUuid: UUID) {
        guard
            let client = clients.find(clientUuid),
            let data = try? JSONEncoder().encode(command)
        else {
            return
        }
        client.socket.send([UInt8](data))
    }
    
    func send(command: PlanningCommands.HostServerSend, sessionId: String) {
        guard let data = try? JSONEncoder().encode(command) else { return }
        let socketClients = clients.find(sessionId: sessionId, type: .host)
        socketClients.forEach { socketClient in
            socketClient.socket.send([UInt8](data))
        }
    }
    
    func send(command: PlanningCommands.JoinServerSend, sessionId: String) {
        guard let data = try? JSONEncoder().encode(command) else { return }
        let socketClients = clients.find(sessionId: sessionId, type: .join)
        socketClients.forEach { socketClient in
            socketClient.socket.send([UInt8](data))
        }
    }
}

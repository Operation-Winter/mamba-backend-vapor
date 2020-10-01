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
                sendInvalidCommand(error: .doesntExist, type: .host, webSocket: webSocket)
                return
            }
            execute(command: command, webSocket: webSocket)
        case .join:
            guard let command = buffer.decodeWebSocketMessage(PlanningCommands.JoinServerReceive.self) else {
                sendInvalidCommand(error: .doesntExist, type: .join, webSocket: webSocket)
                return
            }
            execute(command: command, webSocket: webSocket)
        }
    }
    
    func sendInvalidCommand(error: PlanningInvalidCommandError, type: PlanningSystemType, webSocket: WebSocket) {
        let message = PlanningInvalidCommandMessage(code: error.code, description: error.description)
        var commandData: Data?
        
        switch type {
        case .host:
            let command = PlanningCommands.HostServerSend.invalidCommand(message)
            commandData = try? JSONEncoder().encode(command)
        case .join:
            let command = PlanningCommands.JoinServerSend.invalidCommand(message)
            commandData = try? JSONEncoder().encode(command)
        }
        
        guard let data = commandData else { return }
        webSocket.send([UInt8](data))
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

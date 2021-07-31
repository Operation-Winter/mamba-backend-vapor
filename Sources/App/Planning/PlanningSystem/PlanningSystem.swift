//
//  PlanningSystem.swift
//  
//
//  Created by Armand Kamffer on 2020/10/01.
//

import Vapor
import MambaNetworking
import OpenCombine

class PlanningSystem {
    private(set) var clients: PlanningWebSocketClients
    private(set) var sessions: PlanningSessions
    var subscriptions: [AnyCancellable] = []
    
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
            let command = PlanningCommands.HostServerSend.invalidCommand(message: message)
            commandData = try? JSONEncoder().encode(command)
        case .join:
            let command = PlanningCommands.JoinServerSend.invalidCommand(message: message)
            commandData = try? JSONEncoder().encode(command)
        }
        
        guard let data = commandData else { return }
        webSocket.send([UInt8](data))
    }
    
    func sendInvalidSessionCommand(error: PlanningInvalidSessionError, webSocket: WebSocket) {
        guard let data = try? JSONEncoder().encode(PlanningCommands.JoinServerSend.invalidSession) else { return }
        webSocket.send([UInt8](data))
    }
}

extension PlanningSystem: PlanningSessionDelegate {
    func send<T: Encodable>(command: T, clientUuid: UUID) {
        guard let client = clients.find(clientUuid),
              let data = try? JSONEncoder().encode(command)
        else { return }
        client.socket.send([UInt8](data))
    }
    
    func send(hostCommand command: PlanningCommands.HostServerSend, clientUuid: UUID) {
        send(command: command, clientUuid: clientUuid)
    }
    
    func send(joinCommand command: PlanningCommands.JoinServerSend, clientUuid: UUID) {
        send(command: command, clientUuid: clientUuid)
    }
    
    private func send<T: Encodable>(command: T, clients: [WebSocketClient]) {
        guard let data = try? JSONEncoder().encode(command) else { return }
        clients.forEach { socketClient in
            socketClient.socket.send([UInt8](data))
        }
    }
    
    func send(hostCommand command: PlanningCommands.HostServerSend, sessionId: String) {
        let socketClients = clients.find(sessionId: sessionId, type: .host)
        send(command: command, clients: socketClients)
    }
    
    func send(joinCommand command: PlanningCommands.JoinServerSend, sessionId: String) {
        let socketClients = clients.find(sessionId: sessionId, type: .join)
        send(command: command, clients: socketClients)
    }
    
    func send(stateMessage: PlanningSessionStateMessage, state: PlanningSessionState, sessionId: String) {
        switch state {
        case .none:
            send(hostCommand: .noneState(message: stateMessage), sessionId: sessionId)
            send(joinCommand: .noneState(message: stateMessage), sessionId: sessionId)
        case .voting:
            send(hostCommand: .votingState(message: stateMessage), sessionId: sessionId)
            send(joinCommand: .votingState(message: stateMessage), sessionId: sessionId)
        case .votingFinished:
            send(hostCommand: .finishedState(message: stateMessage), sessionId: sessionId)
            send(joinCommand: .finishedState(message: stateMessage), sessionId: sessionId)
        }
    }
    
    func send(stateMessage: PlanningSessionStateMessage, state: PlanningSessionState, clientUuid: UUID) {
        guard let client = clients.find(clientUuid) else { return }
        
        switch client.type {
        case .host:
            let command = makeHostServerSendCommand(state: state, message: stateMessage)
            send(command: command, clientUuid: clientUuid)
        case .join:
            let command = makeJoinServerSendCommand(state: state, message: stateMessage)
            send(command: command, clientUuid: clientUuid)
        }
    }
    
    private func makeHostServerSendCommand(state: PlanningSessionState, message: PlanningSessionStateMessage) -> PlanningCommands.HostServerSend {
        switch state {
        case .none:
            return PlanningCommands.HostServerSend.noneState(message: message)
        case .voting:
            return PlanningCommands.HostServerSend.votingState(message: message)
        case .votingFinished:
            return PlanningCommands.HostServerSend.finishedState(message: message)
        }
    }
    
    private func makeJoinServerSendCommand(state: PlanningSessionState, message: PlanningSessionStateMessage) -> PlanningCommands.JoinServerSend {
        switch state {
        case .none:
            return PlanningCommands.JoinServerSend.noneState(message: message)
        case .voting:
            return PlanningCommands.JoinServerSend.votingState(message: message)
        case .votingFinished:
            return PlanningCommands.JoinServerSend.finishedState(message: message)
        }
    }
    
    func sendInvalidCommand(error: PlanningInvalidCommandError, type: PlanningSystemType, clientUuid: UUID) {
        guard let client = clients.find(clientUuid) else { return }
        sendInvalidCommand(error: error, type: type, webSocket: client.socket)
    }
    
    func sendInvalidSessionCommand(error: PlanningInvalidSessionError, clientUuid: UUID) {
        guard let client = clients.find(clientUuid) else { return }
        sendInvalidSessionCommand(error: error, webSocket: client.socket)
    }
}

//
//  PlanningSystem.swift
//  
//
//  Created by Armand Kamffer on 2020/10/01.
//

import Vapor
import MambaNetworking

enum PlanningInputValidation {
    static func validSession(_ message: PlanningStartSessionMessage) -> Bool {
        validText(message.sessionName, maxLength: 100) &&
        !message.availableCards.isEmpty &&
        (message.password?.count ?? 0) <= 128
    }

    static func validParticipantName(_ name: String) -> Bool {
        validText(name, maxLength: 100)
    }

    static func validTicket(_ message: PlanningTicketMessage) -> Bool {
        validText(message.title, maxLength: 200) &&
        message.description.count <= 5_000 &&
        message.selectedTags.count <= 50 &&
        message.selectedTags.allSatisfy { validText($0, maxLength: 50) }
    }

    private static func validText(_ value: String, maxLength: Int) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && value.count <= maxLength
    }
}

class PlanningSystem {
    private(set) var clients: PlanningWebSocketClients
    private(set) var sessions: PlanningSessions
    private func encode<T: Encodable>(_ value: T) -> Data? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try? encoder.encode(value)
    }
    
    init(eventLoop: EventLoop) {
        clients = PlanningWebSocketClients(eventLoop: eventLoop)
        sessions = PlanningSessions()
    }
    
    func connect(_ webSocket: WebSocket, type: PlanningSystemType) {
        webSocket.eventLoop.execute { [weak self] in
            webSocket.onBinary { [weak self] webSocket, buffer in
                self?.parseBufferMessage(webSocket: webSocket, buffer: buffer, type: type)
            }
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
        case .spectator:
            guard let command = buffer.decodeWebSocketMessage(PlanningCommands.SpectatorServerReceive.self) else {
                sendInvalidCommand(error: .doesntExist, type: .spectator, webSocket: webSocket)
                return
            }
            execute(command: command, webSocket: webSocket)
        }
    }

    func authorizedClient(uuid: UUID,
                         type: PlanningSystemType,
                         webSocket: WebSocket) async -> PlanningWebSocketClient? {
        guard let client = await clients.authorized(uuid, type: type, socket: webSocket)
        else {
            sendInvalidCommand(error: .invalidUuid, type: type, webSocket: webSocket)
            return nil
        }
        return client
    }

    func reconnectingClient(uuid: UUID,
                           type: PlanningSystemType,
                           webSocket: WebSocket) async -> PlanningWebSocketClient? {
        guard let client = await clients.reconnect(uuid, type: type, socket: webSocket) else {
            sendInvalidCommand(error: .invalidUuid, type: type, webSocket: webSocket)
            return nil
        }
        return client
    }

    private func invalidCommandData(error: PlanningInvalidCommandError,
                                    type: PlanningSystemType) -> Data? {
        let message = PlanningInvalidCommandMessage(code: error.code, description: error.description)

        switch type {
        case .host:
            return encode(PlanningCommands.HostServerSend.invalidCommand(message: message))
        case .join:
            return encode(PlanningCommands.JoinServerSend.invalidCommand(message: message))
        case .spectator:
            return encode(PlanningCommands.SpectatorServerSend.invalidCommand(message: message))
        }
    }
    
    func sendInvalidCommand(error: PlanningInvalidCommandError, type: PlanningSystemType, webSocket: WebSocket) {
        guard let data = invalidCommandData(error: error, type: type) else { return }
        webSocket.send([UInt8](data))
    }
    
    func sendInvalidSessionCommand(error: PlanningInvalidSessionError, webSocket: WebSocket) {
        guard let data = encode(PlanningCommands.JoinServerSend.invalidSession) else { return }
        webSocket.send([UInt8](data))
    }
    
    func sendInvalidSessionCommandSpectator(error: PlanningInvalidSessionError, webSocket: WebSocket) {
        guard let data = encode(PlanningCommands.SpectatorServerSend.invalidSession) else { return }
        webSocket.send([UInt8](data))
    }
}

extension PlanningSystem: PlanningSessionDelegate {
    func send<T: Encodable>(command: T, clientUuid: UUID) async {
        guard let data = encode(command)
        else { return }
        await clients.send(data, to: clientUuid)
    }
    
    func send(hostCommand command: PlanningCommands.HostServerSend, clientUuid: UUID) async {
        await send(command: command, clientUuid: clientUuid)
    }
    
    func send(joinCommand command: PlanningCommands.JoinServerSend, clientUuid: UUID) async {
        await send(command: command, clientUuid: clientUuid)
    }
    
    func send(hostCommand command: PlanningCommands.HostServerSend, sessionId: String) async {
        guard let data = encode(command) else { return }
        await clients.send(data, sessionId: sessionId, type: .host)
    }
    
    func send(joinCommand command: PlanningCommands.JoinServerSend, sessionId: String) async {
        guard let data = encode(command) else { return }
        await clients.send(data, sessionId: sessionId, type: .join)
    }
    
    func send(spectatorCommand command: PlanningCommands.SpectatorServerSend, sessionId: String) async {
        guard let data = encode(command) else { return }
        await clients.send(data, sessionId: sessionId, type: .spectator)
    }
    
    func send(stateMessage: PlanningSessionStateMessage,
              state: PlanningSessionState,
              sessionId: String) async {
        switch state {
        case .none:
            await send(hostCommand: .noneState(message: stateMessage), sessionId: sessionId)
            await send(joinCommand: .noneState(message: stateMessage), sessionId: sessionId)
            await send(spectatorCommand: .noneState(message: stateMessage), sessionId: sessionId)
        case .voting:
            await send(hostCommand: .votingState(message: stateMessage), sessionId: sessionId)
            await send(joinCommand: .votingState(message: stateMessage), sessionId: sessionId)
            await send(spectatorCommand: .votingState(message: stateMessage), sessionId: sessionId)
        case .votingFinished:
            await send(hostCommand: .finishedState(message: stateMessage), sessionId: sessionId)
            await send(joinCommand: .finishedState(message: stateMessage), sessionId: sessionId)
            await send(spectatorCommand: .finishedState(message: stateMessage), sessionId: sessionId)
        case .coffeeBreakVoting:
            await send(hostCommand: .coffeeVoting(message: stateMessage), sessionId: sessionId)
            await send(joinCommand: .coffeeVoting(message: stateMessage), sessionId: sessionId)
            await send(spectatorCommand: .coffeeVoting(message: stateMessage), sessionId: sessionId)
        case .coffeeBreakVotingFinished:
            await send(hostCommand: .coffeeVotingFinished(message: stateMessage), sessionId: sessionId)
            await send(joinCommand: .coffeeVotingFinished(message: stateMessage), sessionId: sessionId)
            await send(spectatorCommand: .coffeeVotingFinished(message: stateMessage), sessionId: sessionId)
        }
    }
    
    func send(stateMessage: PlanningSessionStateMessage, state: PlanningSessionState, clientUuid: UUID) async {
        guard let client = await clients.find(clientUuid) else { return }
        
        switch client.type {
        case .host:
            let command = makeHostServerSendCommand(state: state, message: stateMessage)
            await send(command: command, clientUuid: clientUuid)
        case .join:
            let command = makeJoinServerSendCommand(state: state, message: stateMessage)
            await send(command: command, clientUuid: clientUuid)
        case .spectator:
            let command = makeSpectatorServerSendCommand(state: state, message: stateMessage)
            await send(command: command, clientUuid: clientUuid)
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
        case .coffeeBreakVoting:
            return PlanningCommands.HostServerSend.coffeeVoting(message: message)
        case .coffeeBreakVotingFinished:
            return PlanningCommands.HostServerSend.coffeeVotingFinished(message: message)
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
        case .coffeeBreakVoting:
            return PlanningCommands.JoinServerSend.coffeeVoting(message: message)
        case .coffeeBreakVotingFinished:
            return PlanningCommands.JoinServerSend.coffeeVotingFinished(message: message)
        }
    }
    
    private func makeSpectatorServerSendCommand(state: PlanningSessionState, message: PlanningSessionStateMessage) -> PlanningCommands.SpectatorServerSend {
        switch state {
        case .none:
            return PlanningCommands.SpectatorServerSend.noneState(message: message)
        case .voting:
            return PlanningCommands.SpectatorServerSend.votingState(message: message)
        case .votingFinished:
            return PlanningCommands.SpectatorServerSend.finishedState(message: message)
        case .coffeeBreakVoting:
            return PlanningCommands.SpectatorServerSend.coffeeVoting(message: message)
        case .coffeeBreakVotingFinished:
            return PlanningCommands.SpectatorServerSend.coffeeVotingFinished(message: message)
        }
    }
    
    func sendInvalidCommand(error: PlanningInvalidCommandError, type: PlanningSystemType, clientUuid: UUID) async {
        guard let data = invalidCommandData(error: error, type: type) else { return }
        await clients.send(data, to: clientUuid)
    }
    
    func sendInvalidSessionCommand(error: PlanningInvalidSessionError, clientUuid: UUID) async {
        guard let data = encode(PlanningCommands.JoinServerSend.invalidSession) else { return }
        await clients.send(data, to: clientUuid)
    }
    
    func sessionHasTimedOut(sessionId: String) async {
        guard let session = await sessions.find(id: sessionId) else { return }
        await send(hostCommand: .sessionIdleTimeout, sessionId: sessionId)
        await send(joinCommand: .sessionIdleTimeout, sessionId: sessionId)
        await send(spectatorCommand: .sessionIdleTimeout, sessionId: sessionId)
        await clients.close(sessionId: sessionId, type: .host)
        await clients.close(sessionId: sessionId, type: .join)
        await clients.close(sessionId: sessionId, type: .spectator)
        await sessions.remove(session)
    }
}

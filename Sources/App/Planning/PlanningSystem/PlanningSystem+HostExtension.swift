//
//  PlanningSystem+HostExtension.swift
//  
//
//  Created by Armand Kamffer on 2020/10/01.
//

import Foundation
import Vapor
import MambaNetworking

// MARK: - Host related command methods
extension PlanningSystem {
    func execute(command: PlanningCommands.HostServerReceive, webSocket: WebSocket) {
        switch command {
        case .startSession(let uuid, let message):
            startSession(message: message, webSocket: webSocket, uuid: uuid)
        case .addTicket(let uuid, let message):
            addTicket(message: message, webSocket: webSocket, uuid: uuid)
        case .skipVote(let uuid, let message):
            skipVote(message: message, webSocket: webSocket, uuid: uuid)
        case .removeParticipant(let uuid, let message):
            removeParticipant(message: message, webSocket: webSocket, uuid: uuid)
        case .endSession(let uuid):
            endSession(webSocket: webSocket, uuid: uuid)
        case .finishVoting(let uuid):
            finishVoting(webSocket: webSocket, uuid: uuid)
        case .revote(let uuid):
            revote(webSocket: webSocket, uuid: uuid)
        case .reconnect(let uuid):
            reconnectHost(webSocket: webSocket, uuid: uuid)
        case .editTicket(let uuid, let message):
            editTicket(message: message, webSocket: webSocket, uuid: uuid)
        case .addTimer(let uuid, let message):
            addTimer(message: message, webSocket: webSocket, uuid: uuid)
        case .cancelTimer(let uuid):
            cancelTimer(webSocket: webSocket, uuid: uuid)
        case .previousTickets(uuid: let uuid):
            previousTickets(webSocket: webSocket, uuid: uuid)
        }
    }

    // MARK: Start session command
    private func startSession(message: PlanningStartSessionMessage, webSocket: WebSocket, uuid: UUID) {
        guard let sessionId = generateSessionId() else {
            sendInvalidCommand(error: .noServerCapacity, type: .host, webSocket: webSocket)
            return
        }
        let client = PlanningWebSocketClient(id: uuid, socket: webSocket, sessionId: sessionId, type: .host, connected: true)
        
        let session = PlanningSession(id: sessionId,
                                      name: message.sessionName,
                                      availableCards: message.availableCards,
                                      autoCompleteVoting: message.autoCompleteVoting,
                                      delegate: self)
        
        clients.add(client)
        sessions.add(session)
        
        Task {
            await session.sendStateToAll()
        }
    }
    
    private func generateSessionId() -> String? {
        var sessionCount = 0
        var sessionId = String(format: "%06d", sessionCount)
        
        while sessions.exists(id: sessionId) && sessionCount <= 999999 {
            sessionCount += 1
            sessionId = String(format: "%06d", sessionCount)
        }
        
        return sessionId
    }
    
    // MARK: Add ticket command
    private func addTicket(message: PlanningTicketMessage, webSocket: WebSocket, uuid: UUID) {
        guard let client = clients.find(uuid),
              let session = sessions.find(id: client.sessionId)
        else {
            sendInvalidCommand(error: .invalidUuid, type: .host, webSocket: webSocket)
            return
        }
        client.socket = webSocket
        let ticket = PlanningTicket(title: message.title,
                                    description: message.description)
        
        Task {
            await session.add(ticket: ticket)
            await session.sendStateToAll()
        }
    }
    
    // MARK: Skip vote command
    private func skipVote(message: PlanningSkipVoteMessage, webSocket: WebSocket, uuid: UUID) {
        guard let client = clients.find(uuid),
              let session = sessions.find(id: client.sessionId)
        else {
            sendInvalidCommand(error: .invalidUuid, type: .host, webSocket: webSocket)
            return
        }
        client.socket = webSocket
        
        Task {
            await session.add(vote: nil, uuid: message.participantId)
            await session.sendStateToAll()
        }
    }
    
    // MARK: Revote command
    private func revote(webSocket: WebSocket, uuid: UUID) {
        guard let client = clients.find(uuid),
              let session = sessions.find(id: client.sessionId)
        else {
            sendInvalidCommand(error: .invalidUuid, type: .host, webSocket: webSocket)
            return
        }
        client.socket = webSocket
        
        Task {
            await session.resetVotes()
            await session.sendStateToAll()
        }
    }
    
    // MARK: End session command
    private func endSession(webSocket: WebSocket, uuid: UUID) {
        guard let client = clients.find(uuid),
              let session = sessions.find(id: client.sessionId)
        else {
            sendInvalidCommand(error: .invalidUuid, type: .host, webSocket: webSocket)
            return
        }
        client.socket = webSocket
        send(joinCommand: .endSession, sessionId: session.id.value)
        clients.close(sessionId: session.id.value, type: .host)
        clients.close(sessionId: session.id.value, type: .join)
        sessions.remove(session)
    }
    
    // MARK: Remove participant command
    func removeParticipant(message: PlanningRemoveParticipantMessage, webSocket: WebSocket, uuid: UUID) {
        guard let client = clients.find(uuid),
              let session = sessions.find(id: client.sessionId)
        else {
            sendInvalidCommand(error: .invalidUuid, type: .host, webSocket: webSocket)
            return
        }
        client.socket = webSocket
        send(joinCommand: .removeParticipant, clientUuid: message.participantId)
        
        Task {
            await session.remove(participantId: message.participantId)
            clients.close(message.participantId)
            await session.sendStateToAll()
        }
    }
    
    // MARK: Finish voting command
    func finishVoting(webSocket: WebSocket, uuid: UUID) {
        guard let client = clients.find(uuid),
              let session = sessions.find(id: client.sessionId)
        else {
            sendInvalidCommand(error: .invalidUuid, type: .host, webSocket: webSocket)
            return
        }
        client.socket = webSocket
        
        Task {
            await session.finishVotes()
            await session.sendStateToAll()
        }
    }
    
    // MARK: Edit ticket command
    private func editTicket(message: PlanningTicketMessage, webSocket: WebSocket, uuid: UUID) {
        guard let client = clients.find(uuid),
              let session = sessions.find(id: client.sessionId)
        else {
            sendInvalidCommand(error: .invalidUuid, type: .host, webSocket: webSocket)
            return
        }
        client.socket = webSocket
        
        Task {
            await session.updateTicket(title: message.title, description: message.description)
            await session.sendStateToAll()
        }
    }
    
    // MARK: Add timer command
    private func addTimer(message: PlanningAddTimerMessage, webSocket: WebSocket, uuid: UUID) {
        guard let client = clients.find(uuid),
              let session = sessions.find(id: client.sessionId)
        else {
            sendInvalidCommand(error: .invalidUuid, type: .host, webSocket: webSocket)
            return
        }
        client.socket = webSocket
        
        Task {
            await session.startTimer(with: message.time, uuid: uuid)
        }
    }
    
    // MARK: Cancel timer command
    private func cancelTimer(webSocket: WebSocket, uuid: UUID) {
        guard let client = clients.find(uuid),
              let session = sessions.find(id: client.sessionId)
        else {
            sendInvalidCommand(error: .invalidUuid, type: .host, webSocket: webSocket)
            return
        }
        client.socket = webSocket
        
        Task {
            await session.cancelTimer(uuid: uuid)
        }
    }
    
    // MARK: Previous tickets command
    private func previousTickets(webSocket: WebSocket, uuid: UUID) {
        guard let client = clients.find(uuid),
              let session = sessions.find(id: client.sessionId)
        else {
            sendInvalidCommand(error: .invalidUuid, type: .host, webSocket: webSocket)
            return
        }
        client.socket = webSocket
        
        Task {
            await session.sendPreviousTickets(uuid: uuid)
        }
    }
    
    // MARK: Reconnect command
    func reconnectHost(webSocket: WebSocket, uuid: UUID) {
        guard let client = clients.find(uuid),
              let session = sessions.find(id: client.sessionId) else {
            sendInvalidCommand(error: .invalidUuid, type: .host, webSocket: webSocket)
            return
        }
        client.socket = webSocket
        client.connected = true
        
        Task {
            await session.sendState(to: client.id)
        }
    }
}

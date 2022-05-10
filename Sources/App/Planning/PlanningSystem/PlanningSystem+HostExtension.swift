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
        case .previousTickets(let uuid):
            previousTickets(webSocket: webSocket, uuid: uuid)
        case .requestCoffeeBreak(let uuid):
            requestHostCoffeeBreak(webSocket: webSocket, uuid: uuid)
        case .startCoffeeBreakVote(let uuid):
            startCoffeeBreakVote(webSocket: webSocket, uuid: uuid)
        case .endCoffeeBreakVote(let uuid):
            endCoffeeBreakVote(webSocket: webSocket, uuid: uuid)
        }
    }

    // MARK: Start session command
    private func startSession(message: PlanningStartSessionMessage, webSocket: WebSocket, uuid: UUID) {
        Task {
            guard let sessionId = await generateSessionId() else {
                sendInvalidCommand(error: .noServerCapacity, type: .host, webSocket: webSocket)
                return
            }
            let client = PlanningWebSocketClient(id: uuid, socket: webSocket, sessionId: sessionId, type: .host, connected: true)
            
            let session = await PlanningSession(id: sessionId,
                                                name: message.sessionName,
                                                password: message.password,
                                                availableCards: message.availableCards,
                                                autoCompleteVoting: message.autoCompleteVoting,
                                                delegate: self,
                                                tags: message.tags)
            
            clients.add(client)
            
            await sessions.add(session)
            await session.sendStateToAll()
        }
    }
    
    private func generateSessionId() async -> String? {
        var sessionCount = 0
        var sessionId = String(format: "%06d", sessionCount)
        
        while await sessions.exists(id: sessionId) && sessionCount <= 999999 {
            sessionCount += 1
            sessionId = String(format: "%06d", sessionCount)
        }
        
        return sessionId
    }
    
    // MARK: Add ticket command
    private func addTicket(message: PlanningTicketMessage, webSocket: WebSocket, uuid: UUID) {
        Task {
            guard let client = clients.find(uuid),
                  let session = await sessions.find(id: client.sessionId)
            else {
                sendInvalidCommand(error: .invalidUuid, type: .host, webSocket: webSocket)
                return
            }
            client.socket = webSocket
            let ticket = PlanningTicket(title: message.title,
                                        description: message.description,
                                        selectedTags: message.selectedTags)
            
            await session.add(ticket: ticket)
            await session.sendStateToAll()
        }
    }
    
    // MARK: Skip vote command
    private func skipVote(message: PlanningSkipVoteMessage, webSocket: WebSocket, uuid: UUID) {
        Task {
            guard let client = clients.find(uuid),
                  let session = await sessions.find(id: client.sessionId)
            else {
                sendInvalidCommand(error: .invalidUuid, type: .host, webSocket: webSocket)
                return
            }
            client.socket = webSocket
            
            await session.add(vote: nil, tag: nil, uuid: message.participantId)
            await session.sendStateToAll()
        }
    }
    
    // MARK: Revote command
    private func revote(webSocket: WebSocket, uuid: UUID) {
        Task {
            guard let client = clients.find(uuid),
                  let session = await sessions.find(id: client.sessionId)
            else {
                sendInvalidCommand(error: .invalidUuid, type: .host, webSocket: webSocket)
                return
            }
            client.socket = webSocket
            
            await session.resetVotes()
            await session.sendStateToAll()
        }
    }
    
    // MARK: End session command
    private func endSession(webSocket: WebSocket, uuid: UUID) {
        Task {
            guard let client = clients.find(uuid),
                  let session = await sessions.find(id: client.sessionId)
            else {
                sendInvalidCommand(error: .invalidUuid, type: .host, webSocket: webSocket)
                return
            }
            client.socket = webSocket
            send(joinCommand: .endSession, sessionId: session.id.value)
            send(spectatorCommand: .endSession, sessionId: session.id.value)
            clients.close(sessionId: session.id.value, type: .host)
            clients.close(sessionId: session.id.value, type: .join)
            clients.close(sessionId: session.id.value, type: .spectator)
            await sessions.remove(session)
        }
    }
    
    // MARK: Remove participant command
    func removeParticipant(message: PlanningRemoveParticipantMessage, webSocket: WebSocket, uuid: UUID) {
        Task {
            guard let client = clients.find(uuid),
                  let session = await sessions.find(id: client.sessionId)
            else {
                sendInvalidCommand(error: .invalidUuid, type: .host, webSocket: webSocket)
                return
            }
            client.socket = webSocket
            send(joinCommand: .removeParticipant, clientUuid: message.participantId)
            
            await session.remove(participantId: message.participantId)
            clients.close(message.participantId)
            await session.sendStateToAll()
        }
    }
    
    // MARK: Finish voting command
    func finishVoting(webSocket: WebSocket, uuid: UUID) {
        Task {
            guard let client = clients.find(uuid),
                  let session = await sessions.find(id: client.sessionId)
            else {
                sendInvalidCommand(error: .invalidUuid, type: .host, webSocket: webSocket)
                return
            }
            client.socket = webSocket
            
            await session.finishVotes()
            await session.sendStateToAll()
        }
    }
    
    // MARK: Edit ticket command
    private func editTicket(message: PlanningTicketMessage, webSocket: WebSocket, uuid: UUID) {
        Task {
            guard let client = clients.find(uuid),
                  let session = await sessions.find(id: client.sessionId)
            else {
                sendInvalidCommand(error: .invalidUuid, type: .host, webSocket: webSocket)
                return
            }
            client.socket = webSocket
            
            await session.updateTicket(title: message.title, description: message.description, selectedTags: message.selectedTags)
            await session.sendStateToAll()
        }
    }
    
    // MARK: Add timer command
    private func addTimer(message: PlanningAddTimerMessage, webSocket: WebSocket, uuid: UUID) {
        Task {
            guard let client = clients.find(uuid),
                  let session = await sessions.find(id: client.sessionId)
            else {
                sendInvalidCommand(error: .invalidUuid, type: .host, webSocket: webSocket)
                return
            }
            client.socket = webSocket
        
            await session.startTimer(with: message.time, uuid: uuid)
        }
    }
    
    // MARK: Cancel timer command
    private func cancelTimer(webSocket: WebSocket, uuid: UUID) {
        Task {
            guard let client = clients.find(uuid),
                  let session = await sessions.find(id: client.sessionId)
            else {
                sendInvalidCommand(error: .invalidUuid, type: .host, webSocket: webSocket)
                return
            }
            client.socket = webSocket
        
            await session.cancelTimer(uuid: uuid)
        }
    }
    
    // MARK: Previous tickets command
    private func previousTickets(webSocket: WebSocket, uuid: UUID) {
        Task {
            guard let client = clients.find(uuid),
                  let session = await sessions.find(id: client.sessionId)
            else {
                sendInvalidCommand(error: .invalidUuid, type: .host, webSocket: webSocket)
                return
            }
            client.socket = webSocket
            
            await session.sendPreviousTickets(uuid: uuid)
        }
    }
    
    // MARK: Reconnect command
    func reconnectHost(webSocket: WebSocket, uuid: UUID) {
        Task {
            guard let client = clients.find(uuid),
                  let session = await sessions.find(id: client.sessionId) else {
                sendInvalidCommand(error: .invalidUuid, type: .host, webSocket: webSocket)
                return
            }
            client.socket = webSocket
            client.connected = true
            
            await session.sendState(to: client.id)
        }
    }
    
    // MARK: Request coffee break command
    func requestHostCoffeeBreak(webSocket: WebSocket, uuid: UUID) {
        Task {
            guard let client = clients.find(uuid),
                  let session = await sessions.find(id: client.sessionId)
            else {
                sendInvalidCommand(error: .invalidUuid, type: .host, webSocket: webSocket)
                return
            }
            client.socket = webSocket
            
            // TODO: Implement coffee break request logic
        }
    }
    
    // MARK: Start coffee break vote command
    func startCoffeeBreakVote(webSocket: WebSocket, uuid: UUID) {
        Task {
            guard let client = clients.find(uuid),
                  let session = await sessions.find(id: client.sessionId)
            else {
                sendInvalidCommand(error: .invalidUuid, type: .host, webSocket: webSocket)
                return
            }
            client.socket = webSocket
            
            // TODO: Implement start coffee break vote logic
        }
    }
    
    // MARK: Start coffee break vote command
    func endCoffeeBreakVote(webSocket: WebSocket, uuid: UUID) {
        Task {
            guard let client = clients.find(uuid),
                  let session = await sessions.find(id: client.sessionId)
            else {
                sendInvalidCommand(error: .invalidUuid, type: .host, webSocket: webSocket)
                return
            }
            client.socket = webSocket
            
            // TODO: Implement end coffee break vote logic
        }
    }
}

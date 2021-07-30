//
//  PlanningSystem+JoinExtension.swift
//  
//
//  Created by Armand Kamffer on 2020/10/01.
//

import Foundation
import Vapor
import MambaNetworking

// MARK: - Join related command methods
extension PlanningSystem {
    func execute(command: PlanningCommands.JoinServerReceive, webSocket: WebSocket) {
        switch command {
        case .joinSession(let uuid, let message):
            joinSession(message: message, webSocket: webSocket, uuid: uuid)
        case .vote(let uuid, let message):
            vote(message: message, webSocket: webSocket, uuid: uuid)
        case .leaveSession(let uuid):
            leaveSession(webSocket: webSocket, uuid: uuid)
        case .reconnect(let uuid):
            reconnectJoin(webSocket: webSocket, uuid: uuid)
        case .changeName(let uuid, let message):
            changeName(message: message, webSocket: webSocket, uuid: uuid)
        }
    }
    
    // MARK: Join session command
    func joinSession(message: PlanningJoinSessionMessage, webSocket: WebSocket, uuid: UUID) {
        guard let session = sessions.find(id: message.sessionCode) else {
            sendInvalidSessionCommand(error: .doesntExist, webSocket: webSocket)
            return
        }
        
        let client = PlanningWebSocketClient(id: uuid, socket: webSocket, sessionId: session.id, type: .join, connected: true)
        clients.add(client)
        
        let participant = PlanningParticipant(participantId: client.id,
                                              name: message.participantName,
                                              connected: true)
        
        client.$connected
            .dropFirst()
            .sink { connected in
                participant.connected = connected
                session.sendStateToAll()
            }
            .store(in: &subscriptions)
        
        session.add(participant: participant)
        session.sendStateToAll()
    }
    
    // MARK: Vote command
    func vote(message: PlanningVoteMessage, webSocket: WebSocket, uuid: UUID) {
        guard let client = clients.find(uuid),
              let session = sessions.find(id: client.sessionId)
        else {
            sendInvalidCommand(error: .invalidUuid, type: .join, webSocket: webSocket)
            return
        }
        client.socket = webSocket
        session.add(vote: message.selectedCard, uuid: uuid)
        session.sendStateToAll()
    }

    // MARK: Vote command
    func leaveSession(webSocket: WebSocket, uuid: UUID) {
        guard let client = clients.find(uuid),
              let session = sessions.find(id: client.sessionId)
        else {
            sendInvalidCommand(error: .invalidUuid, type: .join, webSocket: webSocket)
            return
        }
        client.socket = webSocket
        session.remove(participantId: uuid)
        clients.close(uuid)
        session.sendStateToAll()
    }
    
    // MARK: Change name command
    func changeName(message: PlanningChangeNameMessage, webSocket: WebSocket, uuid: UUID) {
        guard let client = clients.find(uuid),
              let session = sessions.find(id: client.sessionId)
        else {
            sendInvalidCommand(error: .invalidUuid, type: .join, webSocket: webSocket)
            return
        }
        client.socket = webSocket
        session.updateParticipant(participantId: uuid, name: message.name)
        session.sendStateToAll()
    }
    
    // MARK: Reconnect command
    func reconnectJoin(webSocket: WebSocket, uuid: UUID) {
        guard let client = clients.find(uuid) else {
            sendInvalidCommand(error: .invalidUuid, type: .join, webSocket: webSocket)
            return
        }
        client.socket = webSocket
        client.connected = true
    }
}

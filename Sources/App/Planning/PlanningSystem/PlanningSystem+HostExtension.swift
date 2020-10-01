//
//  PlanningSystem+HostExtension.swift
//  
//
//  Created by Armand Kamffer on 2020/10/01.
//

import Foundation
import Vapor

// MARK: - Host related command methods
extension PlanningSystem {
    func execute(command: PlanningCommands.HostServerReceive, webSocket: WebSocket) {
        switch command {
        case .startSession(let uuid, let message):
            execute(startSessionMessage: message, webSocket: webSocket, uuid: uuid)
        case .addTicket(let uuid, let message):
            execute(addTicketMessage: message, webSocket: webSocket, uuid: uuid)
        case .skipVote(let uuid, let message):
            // TODO: MAM-102
            break
        case .removeParticipant(let uuid, let message):
            // TODO: MAM-104
            break
        case .endSession(let uuid):
            // TODO: MAM-103
            break
        case .finishVoting(let uuid):
            // TODO: MAM-105
            break
        case .revote(let uuid):
            // TODO: MAM-106
            break
        }
    }

    // MARK: Start session command
    private func execute(startSessionMessage: PlanningStartSessionMessage, webSocket: WebSocket, uuid: UUID) {
        guard let sessionId = generateSessionId() else {
            sendInvalidCommand(error: .noServerCapacity, type: .host, webSocket: webSocket)
            return
        }
        let client = PlanningWebSocketClient(id: uuid, socket: webSocket, sessionId: sessionId, type: .host)
        let session = PlanningSession(id: sessionId,
                                      name: startSessionMessage.sessionName,
                                      availableCards: startSessionMessage.availableCards,
                                      delegate: self)
        
        clients.add(client)
        sessions.add(session)
        
        session.sendStateToAll()
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
    private func execute(addTicketMessage: PlanningAddTicketMessage, webSocket: WebSocket, uuid: UUID) {
        guard
            let client = clients.find(uuid),
            let session = sessions.find(id: client.sessionId)
        else {
            sendInvalidCommand(error: .invalidUuid, type: .host, webSocket: webSocket)
            return
        }
        client.socket = webSocket
        let ticket = PlanningTicket(title: addTicketMessage.title,
                                    description: addTicketMessage.description)
        session.add(ticket: ticket)
        session.sendStateToAll()
    }
}

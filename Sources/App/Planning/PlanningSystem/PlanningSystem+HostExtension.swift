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
        case .startSession(let message):
            execute(startSessionMessage: message, webSocket: webSocket)
        case .addTicket(_):
            // TODO: MAM-101
            break
        case .skipVote(_):
            // TODO: MAM-102
            break
        case .removeParticipant(_):
            // TODO: MAM-104
            break
        case .endSession:
            // TODO: MAM-103
            break
        case .finishVoting:
            // TODO: MAM-105
            break
        case .revote:
            // TODO: MAM-106
            break
        }
    }
    
    private func execute(startSessionMessage: PlanningStartSessionMessage, webSocket: WebSocket) {
        guard let sessionId = generateSessionId() else {
            //TODO: MAM-112: Invalid command, out of capacity
            return
        }
        let client = PlanningWebSocketClient(id: UUID(), socket: webSocket, sessionId: sessionId, type: .host)
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
}

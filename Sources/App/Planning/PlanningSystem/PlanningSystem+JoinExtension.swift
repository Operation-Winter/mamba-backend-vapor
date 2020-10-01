//
//  PlanningSystem+JoinExtension.swift
//  
//
//  Created by Armand Kamffer on 2020/10/01.
//

import Foundation
import Vapor

// MARK: - Join related command methods
extension PlanningSystem {
    func execute(command: PlanningCommands.JoinServerReceive, webSocket: WebSocket) {
        switch command {
        case .joinSession(let uuid, let message):
            execute(joinSessionMessage: message, webSocket: webSocket, uuid: uuid)
        case .vote(let uuid, let message):
            // TODO: MAM-114
            break
        case .leaveSession(let uuid):
            // TODO: MAM-115
            break
        }
    }
    
    func execute(joinSessionMessage: PlanningJoinSessionMessage, webSocket: WebSocket, uuid: UUID) {
        guard let session = sessions.find(id: joinSessionMessage.sessionCode) else {
            sendInvalidSessionCommand(error: .doesntExist, webSocket: webSocket)
            return
        }
        
        let client = PlanningWebSocketClient(id: uuid, socket: webSocket, sessionId: session.id, type: .join)
        clients.add(client)
        
        let participant = PlanningParticipant(id: client.id, name: joinSessionMessage.participantName)
        session.add(participant: participant)
        
        session.sendStateToAll()
    }
}

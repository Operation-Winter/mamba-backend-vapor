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
            execute(voteMessage: message, webSocket: webSocket, uuid: uuid)
        case .leaveSession(let uuid):
            // TODO: MAM-115
            break
        }
    }
    
    // MARK: Join session command
    func execute(joinSessionMessage message: PlanningJoinSessionMessage, webSocket: WebSocket, uuid: UUID) {
        guard let session = sessions.find(id: message.sessionCode) else {
            sendInvalidSessionCommand(error: .doesntExist, webSocket: webSocket)
            return
        }
        
        let client = PlanningWebSocketClient(id: uuid, socket: webSocket, sessionId: session.id, type: .join)
        clients.add(client)
        
        let participant = PlanningParticipant(id: client.id, name: message.participantName)
        session.add(participant: participant)
        session.sendStateToAll()
    }
    
    // MARK: Vote command
    func execute(voteMessage message: PlanningVoteMessage, webSocket: WebSocket, uuid: UUID) {
        guard
            let client = clients.find(uuid),
            let session = sessions.find(id: client.sessionId)
        else {
            sendInvalidCommand(error: .invalidUuid, type: .host, webSocket: webSocket)
            return
        }
        client.socket = webSocket
        session.add(vote: message.selectedCard, uuid: uuid)
        session.sendStateToAll()
    }
}

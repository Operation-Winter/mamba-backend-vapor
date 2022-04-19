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
        case .requestCoffeeBreak(let uuid):
            requestCoffeeBreak(webSocket: webSocket, uuid: uuid)
        case .coffeeBreakVote(let uuid, let message):
            coffeeBreakVote(message: message, webSocket: webSocket, uuid: uuid)
        }
    }
    
    // MARK: Join session command
    func joinSession(message: PlanningJoinSessionMessage, webSocket: WebSocket, uuid: UUID) {
        Task {
            guard let session = await sessions.find(id: message.sessionCode) else {
                sendInvalidSessionCommand(error: .doesntExist, webSocket: webSocket)
                return
            }
            
            let client = PlanningWebSocketClient(id: uuid, socket: webSocket, sessionId: session.id.value, type: .join, connected: true)
            clients.add(client)
            
            let participant = PlanningParticipant(participantId: client.id,
                                                  name: message.participantName,
                                                  connected: true)
            
            client.$connected
                .dropFirst()
                .sink { connected in
                    participant.connected = connected
                    Task {
                        await session.sendStateToAll()
                    }
                }
                .store(in: &subscriptions)
            
            await session.add(participant: participant)
            await session.sendStateToAll()
        }
    }
    
    // MARK: Vote command
    func vote(message: PlanningVoteMessage, webSocket: WebSocket, uuid: UUID) {
        Task {
            guard let client = clients.find(uuid),
                  let session = await sessions.find(id: client.sessionId)
            else {
                sendInvalidCommand(error: .invalidUuid, type: .join, webSocket: webSocket)
                return
            }
            client.socket = webSocket
             
            await session.add(vote: message.selectedCard, uuid: uuid)
            await session.sendStateToAll()
        }
    }

    // MARK: Vote command
    func leaveSession(webSocket: WebSocket, uuid: UUID) {
        Task {
            guard let client = clients.find(uuid),
                  let session = await sessions.find(id: client.sessionId)
            else {
                sendInvalidCommand(error: .invalidUuid, type: .join, webSocket: webSocket)
                return
            }
            client.socket = webSocket
            
            await session.remove(participantId: uuid)
            clients.close(uuid)
            await session.sendStateToAll()
        }
    }
    
    // MARK: Change name command
    func changeName(message: PlanningChangeNameMessage, webSocket: WebSocket, uuid: UUID) {
        Task {
            guard let client = clients.find(uuid),
                  let session = await sessions.find(id: client.sessionId)
            else {
                sendInvalidCommand(error: .invalidUuid, type: .join, webSocket: webSocket)
                return
            }
            client.socket = webSocket
            
            await session.updateParticipant(participantId: uuid, name: message.name)
            await session.sendStateToAll()
        }
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
    
    // MARK: Request coffee break command
    func requestCoffeeBreak(webSocket: WebSocket, uuid: UUID) {
        Task {
            guard let client = clients.find(uuid),
                  let session = await sessions.find(id: client.sessionId)
            else {
                sendInvalidCommand(error: .invalidUuid, type: .join, webSocket: webSocket)
                return
            }
            client.socket = webSocket
            
            // TODO: Implement coffee break request logic
        }
    }
    
    // MARK: Coffee break vote command
    func coffeeBreakVote(message: PlanningCoffeeBreakVoteMessage, webSocket: WebSocket, uuid: UUID) {
        Task {
            guard let client = clients.find(uuid),
                  let session = await sessions.find(id: client.sessionId)
            else {
                sendInvalidCommand(error: .invalidUuid, type: .join, webSocket: webSocket)
                return
            }
            client.socket = webSocket
            
            // TODO: Implement coffee break vote logic
        }
    }
}

//
//  PlanningSystem+JoinExtension.swift
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
        case .concedeVote(let uuid, let message):
            updateVote(message: message, webSocket: webSocket, uuid: uuid)
        }
    }

    // MARK: - Join session command
    func joinSession(message: PlanningJoinSessionMessage, webSocket: WebSocket, uuid: UUID) {
        Task {
            guard PlanningInputValidation.validParticipantName(message.participantName) else {
                sendInvalidCommand(error: .invalidParameters, type: .join, webSocket: webSocket)
                return
            }
            guard await clients.reserve(uuid) else {
                sendInvalidCommand(error: .invalidUuid, type: .join, webSocket: webSocket)
                return
            }
            guard let session = await sessions.find(id: message.sessionCode),
                  session.password == message.password else {
                await clients.release(uuid)
                sendInvalidSessionCommand(error: .doesntExist, webSocket: webSocket)
                return
            }

            let client = PlanningWebSocketClient(
                id: uuid,
                socket: webSocket,
                sessionId: session.id,
                type: .join,
                connected: true
            )
            let participant = PlanningParticipant(
                participantId: client.id,
                name: message.participantName,
                connected: true
            )

            await clients.add(client)
            await session.add(participant: participant)
            client.startConnectionMonitoring(session: session)
            await session.sendStateToAll()
        }
    }

    // MARK: - Vote command
    func vote(message: PlanningVoteMessage, webSocket: WebSocket, uuid: UUID) {
        Task {
            guard let client = await authorizedClient(uuid: uuid, type: .join, webSocket: webSocket),
                  let session = await sessions.find(id: client.sessionId) else { return }
            await session.add(vote: message.selectedCard, tag: message.tag, uuid: uuid)
            await session.sendStateToAll()
        }
    }

    // MARK: - Update vote command
    func updateVote(message: PlanningVoteMessage, webSocket: WebSocket, uuid: UUID) {
        Task {
            guard let client = await authorizedClient(uuid: uuid, type: .join, webSocket: webSocket),
                  let session = await sessions.find(id: client.sessionId) else { return }
            await session.update(vote: message.selectedCard, tag: message.tag, uuid: uuid)
            await session.sendStateToAll()
        }
    }

    // MARK: - Leave session command
    func leaveSession(webSocket: WebSocket, uuid: UUID) {
        Task {
            guard let client = await authorizedClient(uuid: uuid, type: .join, webSocket: webSocket),
                  let session = await sessions.find(id: client.sessionId) else { return }
            await session.remove(participantId: uuid)
            await clients.close(uuid)
            await session.sendStateToAll()
        }
    }

    // MARK: - Change name command
    func changeName(message: PlanningChangeNameMessage, webSocket: WebSocket, uuid: UUID) {
        Task {
            guard let client = await authorizedClient(uuid: uuid, type: .join, webSocket: webSocket),
                  let session = await sessions.find(id: client.sessionId) else { return }
            guard PlanningInputValidation.validParticipantName(message.name) else {
                sendInvalidCommand(error: .invalidParameters, type: .join, webSocket: webSocket)
                return
            }
            await session.updateParticipant(participantId: uuid, name: message.name)
            await session.sendStateToAll()
        }
    }

    // MARK: - Reconnect command
    func reconnectJoin(webSocket: WebSocket, uuid: UUID) {
        Task {
            guard let client = await reconnectingClient(uuid: uuid, type: .join, webSocket: webSocket),
                  let session = await sessions.find(id: client.sessionId) else { return }
            await session.sendState(to: uuid)
        }
    }

    // MARK: - Request coffee break command
    func requestCoffeeBreak(webSocket: WebSocket, uuid: UUID) {
        Task {
            guard let client = await authorizedClient(uuid: uuid, type: .join, webSocket: webSocket),
                  let session = await sessions.find(id: client.sessionId) else { return }
            await session.toggleCoffeeRequestVote(
                participantId: client.id,
                commandType: .join,
                commandUuid: uuid
            )
            await session.sendStateToAll()
        }
    }

    // MARK: - Coffee break vote command
    func coffeeBreakVote(message: PlanningCoffeeBreakVoteMessage, webSocket: WebSocket, uuid: UUID) {
        Task {
            guard let client = await authorizedClient(uuid: uuid, type: .join, webSocket: webSocket),
                  let session = await sessions.find(id: client.sessionId) else { return }
            await session.add(coffeBreakVote: message.vote, uuid: uuid)
            await session.sendStateToAll()
        }
    }
}

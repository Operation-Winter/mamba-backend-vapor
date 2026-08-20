//
//  PlanningSystem+HostExtension.swift
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
        case .coffeeBreakVote(uuid: let uuid, message: let message):
            hostCoffeeBreakVote(message: message, webSocket: webSocket, uuid: uuid)
        case .finishCoffeeBreakVote(uuid: let uuid):
            finishCoffeeBreakVote(webSocket: webSocket, uuid: uuid)
        }
    }

    // MARK: Start session command
    private func startSession(message: PlanningStartSessionMessage, webSocket: WebSocket, uuid: UUID) {
        Task {
            guard PlanningInputValidation.validSession(message) else {
                sendInvalidCommand(error: .invalidParameters, type: .host, webSocket: webSocket)
                return
            }
            guard await clients.reserve(uuid) else {
                sendInvalidCommand(error: .invalidUuid, type: .host, webSocket: webSocket)
                return
            }
            guard let sessionId = await sessions.reserveNextID() else {
                await clients.release(uuid)
                sendInvalidCommand(error: .noServerCapacity, type: .host, webSocket: webSocket)
                return
            }

            let client = PlanningWebSocketClient(
                id: uuid,
                socket: webSocket,
                sessionId: sessionId,
                type: .host,
                connected: true
            )
            let session = await PlanningSession(
                id: sessionId,
                hostId: uuid,
                name: message.sessionName,
                password: message.password,
                availableCards: message.availableCards,
                autoCompleteVoting: message.autoCompleteVoting,
                delegate: self
            )

            await clients.add(client)
            await sessions.add(session)
            await session.sendStateToAll()
        }
    }

    // MARK: Add ticket command
    private func addTicket(message: PlanningTicketMessage, webSocket: WebSocket, uuid: UUID) {
        Task {
            guard PlanningInputValidation.validTicket(message) else {
                sendInvalidCommand(error: .invalidParameters, type: .host, webSocket: webSocket)
                return
            }
            guard let client = await authorizedClient(uuid: uuid, type: .host, webSocket: webSocket),
                  let session = await sessions.find(id: client.sessionId) else { return }
            let ticket = PlanningTicket(
                title: message.title,
                description: message.description,
                selectedTags: message.selectedTags
            )
            await session.add(ticket: ticket, uuid: uuid)
            await session.sendStateToAll()
        }
    }

    // MARK: Skip vote command
    private func skipVote(message: PlanningSkipVoteMessage, webSocket: WebSocket, uuid: UUID) {
        Task {
            guard let client = await authorizedClient(uuid: uuid, type: .host, webSocket: webSocket),
                  let session = await sessions.find(id: client.sessionId) else { return }
            await session.add(
                vote: nil,
                tag: nil,
                uuid: message.participantId,
                commandType: .host,
                commandUuid: uuid
            )
            await session.sendStateToAll()
        }
    }

    // MARK: Revote command
    private func revote(webSocket: WebSocket, uuid: UUID) {
        Task {
            guard let client = await authorizedClient(uuid: uuid, type: .host, webSocket: webSocket),
                  let session = await sessions.find(id: client.sessionId) else { return }
            await session.resetVotes(uuid: uuid)
            await session.sendStateToAll()
        }
    }

    // MARK: End session command
    private func endSession(webSocket: WebSocket, uuid: UUID) {
        Task {
            guard let client = await authorizedClient(uuid: uuid, type: .host, webSocket: webSocket),
                  let session = await sessions.find(id: client.sessionId) else { return }
            await send(joinCommand: .endSession, sessionId: session.id)
            await send(spectatorCommand: .endSession, sessionId: session.id)
            await clients.close(sessionId: session.id, type: .host)
            await clients.close(sessionId: session.id, type: .join)
            await clients.close(sessionId: session.id, type: .spectator)
            await sessions.remove(session)
        }
    }

    // MARK: Remove participant command
    func removeParticipant(message: PlanningRemoveParticipantMessage, webSocket: WebSocket, uuid: UUID) {
        Task {
            guard let client = await authorizedClient(uuid: uuid, type: .host, webSocket: webSocket),
                  let session = await sessions.find(id: client.sessionId) else { return }
            await send(joinCommand: .removeParticipant, clientUuid: message.participantId)
            await session.remove(participantId: message.participantId)
            await clients.close(message.participantId)
            await session.sendStateToAll()
        }
    }

    // MARK: Finish voting command
    func finishVoting(webSocket: WebSocket, uuid: UUID) {
        Task {
            guard let client = await authorizedClient(uuid: uuid, type: .host, webSocket: webSocket),
                  let session = await sessions.find(id: client.sessionId) else { return }
            await session.finishVotes(uuid: uuid)
            await session.sendStateToAll()
        }
    }

    // MARK: Edit ticket command
    private func editTicket(message: PlanningTicketMessage, webSocket: WebSocket, uuid: UUID) {
        Task {
            guard let client = await authorizedClient(uuid: uuid, type: .host, webSocket: webSocket),
                  let session = await sessions.find(id: client.sessionId) else { return }
            guard PlanningInputValidation.validTicket(message) else {
                sendInvalidCommand(error: .invalidParameters, type: .host, webSocket: webSocket)
                return
            }
            await session.updateTicket(
                title: message.title,
                description: message.description,
                selectedTags: message.selectedTags,
                uuid: uuid
            )
            await session.sendStateToAll()
        }
    }

    // MARK: Add timer command
    private func addTimer(message: PlanningAddTimerMessage, webSocket: WebSocket, uuid: UUID) {
        Task {
            guard let client = await authorizedClient(uuid: uuid, type: .host, webSocket: webSocket),
                  let session = await sessions.find(id: client.sessionId) else { return }
            await session.startTimer(with: message.time, uuid: uuid)
        }
    }

    // MARK: Cancel timer command
    private func cancelTimer(webSocket: WebSocket, uuid: UUID) {
        Task {
            guard let client = await authorizedClient(uuid: uuid, type: .host, webSocket: webSocket),
                  let session = await sessions.find(id: client.sessionId) else { return }
            await session.cancelTimer(uuid: uuid)
        }
    }

    // MARK: Previous tickets command
    private func previousTickets(webSocket: WebSocket, uuid: UUID) {
        Task {
            guard let client = await authorizedClient(uuid: uuid, type: .host, webSocket: webSocket),
                  let session = await sessions.find(id: client.sessionId) else { return }
            await session.sendPreviousTickets(uuid: uuid)
        }
    }

    // MARK: Reconnect command
    func reconnectHost(webSocket: WebSocket, uuid: UUID) {
        Task {
            guard let client = await reconnectingClient(uuid: uuid, type: .host, webSocket: webSocket),
                  let session = await sessions.find(id: client.sessionId) else { return }
            await session.sendState(to: client.id)
        }
    }

    // MARK: Request coffee break command
    func requestHostCoffeeBreak(webSocket: WebSocket, uuid: UUID) {
        Task {
            guard let client = await authorizedClient(uuid: uuid, type: .host, webSocket: webSocket),
                  let session = await sessions.find(id: client.sessionId) else { return }
            await session.toggleCoffeeRequestVote(
                participantId: uuid,
                commandType: .host,
                commandUuid: uuid
            )
            await session.sendStateToAll()
        }
    }

    // MARK: Start coffee break vote command
    func startCoffeeBreakVote(webSocket: WebSocket, uuid: UUID) {
        Task {
            guard let client = await authorizedClient(uuid: uuid, type: .host, webSocket: webSocket),
                  let session = await sessions.find(id: client.sessionId) else { return }
            await session.startCoffeeVoting(uuid: uuid)
            await session.sendStateToAll()
        }
    }

    // MARK: Finish coffee break vote command
    func finishCoffeeBreakVote(webSocket: WebSocket, uuid: UUID) {
        Task {
            guard let client = await authorizedClient(uuid: uuid, type: .host, webSocket: webSocket),
                  let session = await sessions.find(id: client.sessionId) else { return }
            await session.finishCoffeeVoting(uuid: uuid)
            await session.sendStateToAll()
        }
    }

    // MARK: End coffee break vote command
    func endCoffeeBreakVote(webSocket: WebSocket, uuid: UUID) {
        Task {
            guard let client = await authorizedClient(uuid: uuid, type: .host, webSocket: webSocket),
                  let session = await sessions.find(id: client.sessionId) else { return }
            await session.endCoffeeVoting(uuid: uuid)
            await session.sendStateToAll()
        }
    }

    // MARK: Host coffee vote command
    func hostCoffeeBreakVote(message: PlanningCoffeeBreakVoteMessage, webSocket: WebSocket, uuid: UUID) {
        Task {
            guard let client = await authorizedClient(uuid: uuid, type: .host, webSocket: webSocket),
                  let session = await sessions.find(id: client.sessionId) else { return }
            await session.add(
                coffeBreakVote: message.vote,
                uuid: uuid,
                commandType: .host,
                commandUuid: uuid
            )
            await session.sendStateToAll()
        }
    }
}

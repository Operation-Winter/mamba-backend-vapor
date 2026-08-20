import Foundation
@preconcurrency import MambaNetworking
@testable import App
import NIOCore
import NIOPosix
import Vapor
import XCTest

private final class RecordingSessionDelegate: PlanningSessionDelegate {
    var invalidCommandTypes: [PlanningSystemType] = []
    var invalidCommandClientUUIDs: [UUID] = []
    var timeoutSessionIDs: [String] = []

    func send<T: Encodable>(command: T, clientUuid: UUID) {}

    func send(hostCommand command: PlanningCommands.HostServerSend,
              clientUuid: UUID) {}

    func send(joinCommand command: PlanningCommands.JoinServerSend,
              clientUuid: UUID) {}

    func send(hostCommand command: PlanningCommands.HostServerSend,
              sessionId: String) {}

    func send(joinCommand command: PlanningCommands.JoinServerSend,
              sessionId: String) {}

    func send(stateMessage: PlanningSessionStateMessage,
              state: PlanningSessionState,
              sessionId: String) {}

    func send(stateMessage: PlanningSessionStateMessage,
              state: PlanningSessionState,
              clientUuid: UUID) {}

    func sendInvalidCommand(error: PlanningInvalidCommandError,
                            type: PlanningSystemType,
                            clientUuid: UUID) {
        invalidCommandTypes.append(type)
        invalidCommandClientUUIDs.append(clientUuid)
    }

    func sendInvalidSessionCommand(error: PlanningInvalidSessionError,
                                   clientUuid: UUID) {}

    func sessionHasTimedOut(sessionId: String) {
        timeoutSessionIDs.append(sessionId)
    }
}

final class AppTests: XCTestCase {
    func testSessionStorage() async {
        let sessions = PlanningSessions()
        let session = await makeSession(id: "000001")

        await sessions.add(session)
        let countAfterAdd = await sessions.count
        let existsAfterAdd = await sessions.exists(id: "000001")
        XCTAssertEqual(countAfterAdd, 1)
        XCTAssertTrue(existsAfterAdd)

        await sessions.remove(session)
        let countAfterRemove = await sessions.count
        XCTAssertEqual(countAfterRemove, 0)
    }

    func testVotingAutomaticallyFinishesAfterEveryParticipantVotes() async {
        let firstParticipantID = UUID()
        let secondParticipantID = UUID()
        let participants = [
            PlanningParticipant(
                participantId: firstParticipantID,
                name: "First",
                connected: true
            ),
            PlanningParticipant(
                participantId: secondParticipantID,
                name: "Second",
                connected: true
            ),
        ]
        let ticket = PlanningTicket(
            title: "Ticket",
            description: "Description",
            selectedTags: []
        )
        let session = await makeSession(
            id: "000002",
            participants: participants,
            ticket: ticket,
            state: .voting,
            autoCompleteVoting: true
        )

        await session.add(
            vote: .one,
            tag: nil,
            uuid: firstParticipantID
        )
        await session.add(
            vote: .three,
            tag: nil,
            uuid: secondParticipantID
        )

        let state = await session.state
        let voteCount = await session.ticket?.ticketVotes.count
        if case .votingFinished = state {
            XCTAssertEqual(voteCount, 2)
        } else {
            XCTFail("Expected voting to finish after all participants voted")
        }
    }

    func testInvalidHostVoteUsesHostSenderAndUUID() async {
        let participantID = UUID()
        let hostID = UUID()
        let delegate = RecordingSessionDelegate()
        let session = await makeSession(
            id: "000003",
            participants: [
                PlanningParticipant(
                    participantId: participantID,
                    name: "Participant",
                    connected: true
                ),
            ],
            delegate: delegate
        )

        await session.add(
            vote: nil,
            tag: nil,
            uuid: participantID,
            commandType: .host,
            commandUuid: hostID
        )

        XCTAssertEqual(delegate.invalidCommandTypes.count, 1)
        if case .host = delegate.invalidCommandTypes[0] {
            XCTAssertEqual(delegate.invalidCommandClientUUIDs[0], hostID)
        } else {
            XCTFail("Expected invalid host command routing")
        }
    }

    func testOnlyOneTimerCanRunAndCancellationClearsTimer() async {
        let hostID = UUID()
        let ticket = PlanningTicket(
            title: "Ticket",
            description: "Description",
            selectedTags: []
        )
        let delegate = RecordingSessionDelegate()
        let session = await makeSession(
            id: "000004",
            ticket: ticket,
            state: .voting,
            delegate: delegate
        )

        await session.startTimer(with: 30, uuid: hostID)
        await session.startTimer(with: 30, uuid: hostID)
        await session.cancelTimer(uuid: hostID)
        await session.cancelTimer(uuid: hostID)

        XCTAssertEqual(delegate.invalidCommandTypes.count, 2)
    }

    func testTimerCompletionClearsTimerAndFinishesVoting() async throws {
        let hostID = UUID()
        let ticket = PlanningTicket(
            title: "Ticket",
            description: "Description",
            selectedTags: []
        )
        let delegate = RecordingSessionDelegate()
        let session = await makeSession(
            id: "000005",
            ticket: ticket,
            state: .voting,
            delegate: delegate
        )

        await session.startTimer(with: 0, uuid: hostID)
        try await Task.sleep(nanoseconds: 300_000_000)

        let state = await session.state
        if case .votingFinished = state {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected timer completion to finish voting")
        }

        await session.cancelTimer(uuid: hostID)
        XCTAssertEqual(delegate.invalidCommandTypes.count, 1)
    }

    func testTimedOutSessionIsRemoved() async throws {
        let app = try await Application.make(.testing)
        let planningSystem = PlanningSystem(eventLoop: app.eventLoopGroup.next())
        let session = await makeSession(id: "000006")
        await planningSystem.sessions.add(session)

        planningSystem.sessionHasTimedOut(sessionId: "000006")
        try await Task.sleep(nanoseconds: 200_000_000)

        let exists = await planningSystem.sessions.exists(id: "000006")
        try await app.asyncShutdown()
        XCTAssertFalse(exists)
    }

    func testWebSocketSessionSmokePath() async throws {
        let app = try await Application.make(.testing)
        app.http.server.configuration.port = 0
        try configure(app)
        app.environment.arguments = ["serve"]
        try await app.startup()

        let port = try XCTUnwrap(app.http.server.shared.localAddress?.port)
        let clientEventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        let eventLoop = clientEventLoopGroup.next()
        let hostState = eventLoop.makePromise(of: PlanningSessionStateMessage.self)
        let participantState = eventLoop.makePromise(of: PlanningSessionStateMessage.self)
        var hostSocket: WebSocket?
        var participantSocket: WebSocket?
        let encoder = JSONEncoder()

        let hostConnection: EventLoopFuture<Void> = WebSocket.connect(
            to: "ws://127.0.0.1:\(port)/api/planning/host",
            on: clientEventLoopGroup
        ) { webSocket in
            hostSocket = webSocket
            webSocket.onBinary { _, buffer in
                guard let command = buffer.decodeWebSocketMessage(
                    PlanningCommands.HostServerSend.self
                ) else { return }
                if case .noneState(let message) = command {
                    hostState.succeed(message)
                }
            }
            let message = PlanningStartSessionMessage(
                sessionName: "Smoke session",
                autoCompleteVoting: false,
                availableCards: [.one, .three],
                password: nil
            )
            let command = PlanningCommands.HostServerReceive.startSession(
                uuid: UUID(),
                message: message
            )
            if let data = try? encoder.encode(command) {
                webSocket.send([UInt8](data))
            }
        }
        try await hostConnection.get()
        let startedState = try await hostState.futureResult.get()
        let sessionCode = startedState.sessionCode

        let participantConnection: EventLoopFuture<Void> = WebSocket.connect(
            to: "ws://127.0.0.1:\(port)/api/planning/join",
            on: clientEventLoopGroup
        ) { webSocket in
            participantSocket = webSocket
            webSocket.onBinary { _, buffer in
                guard let command = buffer.decodeWebSocketMessage(
                    PlanningCommands.JoinServerSend.self
                ) else { return }
                if case .noneState(let message) = command {
                    participantState.succeed(message)
                }
            }
            let message = PlanningJoinSessionMessage(
                sessionCode: sessionCode,
                participantName: "Smoke participant",
                password: nil
            )
            let command = PlanningCommands.JoinServerReceive.joinSession(
                uuid: UUID(),
                message: message
            )
            if let data = try? encoder.encode(command) {
                webSocket.send([UInt8](data))
            }
        }
        try await participantConnection.get()
        let joinedState = try await participantState.futureResult.get()

        XCTAssertEqual(joinedState.sessionCode, startedState.sessionCode)
        XCTAssertEqual(joinedState.participants.count, 1)
        if let hostSocket {
            try await hostSocket.close()
        }
        if let participantSocket {
            try await participantSocket.close()
        }
        try await clientEventLoopGroup.shutdownGracefully()
        try await app.asyncShutdown()
    }

    private func makeSession(
        id: String,
        participants: [PlanningParticipant] = [],
        ticket: PlanningTicket? = nil,
        state: PlanningSessionState = .none,
        autoCompleteVoting: Bool = false,
        delegate: PlanningSessionDelegate? = nil
    ) async -> PlanningSession {
        await PlanningSession(
            id: id,
            name: "Test session",
            password: nil,
            availableCards: [.one, .three],
            autoCompleteVoting: autoCompleteVoting,
            participants: participants,
            ticket: ticket,
            state: state,
            delegate: delegate
        )
    }
}

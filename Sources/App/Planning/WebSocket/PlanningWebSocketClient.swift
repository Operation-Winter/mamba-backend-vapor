//
//  PlanningWebSocketClient.swift
//
//  Created by Armand Kamffer on 2020/10/01.
//

import Foundation
import Vapor

private actor PlanningConnectionState {
    private let continuation: AsyncStream<Bool>.Continuation
    private var connected: Bool
    private var socketToken: ObjectIdentifier

    init(continuation: AsyncStream<Bool>.Continuation,
         connected: Bool,
         socketToken: ObjectIdentifier) {
        self.continuation = continuation
        self.connected = connected
        self.socketToken = socketToken
    }

    func attach(to socketToken: ObjectIdentifier) {
        self.socketToken = socketToken
    }

    func reconnect(to socketToken: ObjectIdentifier) {
        self.socketToken = socketToken
        updateConnection(true)
    }

    func disconnected(socketToken: ObjectIdentifier) {
        guard self.socketToken == socketToken else { return }
        updateConnection(false)
    }

    func finish() {
        continuation.finish()
    }

    private func updateConnection(_ value: Bool) {
        guard connected != value else { return }
        connected = value
        continuation.yield(value)
    }
}

final class PlanningWebSocketClient: WebSocketClient {
    let id: UUID
    private var socket: WebSocket {
        didSet { setupSocket(socket) }
    }
    let sessionId: String
    let type: PlanningSystemType

    let connectionChanges: AsyncStream<Bool>
    private let connectionState: PlanningConnectionState
    private var connectionTask: Task<Void, Never>?

    init(id: UUID,
         socket: WebSocket,
         sessionId: String,
         type: PlanningSystemType,
         connected: Bool) {
        self.id = id
        self.socket = socket
        self.sessionId = sessionId
        self.type = type

        var continuation: AsyncStream<Bool>.Continuation!
        self.connectionChanges = AsyncStream { continuation = $0 }
        self.connectionState = PlanningConnectionState(
            continuation: continuation,
            connected: connected,
            socketToken: ObjectIdentifier(socket)
        )

        setupSocket(socket)
    }

    func accepts(_ socket: WebSocket) -> Bool {
        self.socket === socket
    }

    func send(_ data: Data) {
        socket.send([UInt8](data))
    }

    func reconnect(to socket: WebSocket) {
        self.socket = socket
        let state = connectionState
        Task { await state.reconnect(to: ObjectIdentifier(socket)) }
    }

    func startConnectionMonitoring(session: PlanningSession) {
        connectionTask?.cancel()
        connectionTask = Task { [weak self] in
            guard let self else { return }
            for await connected in self.connectionChanges {
                await session.updateParticipantConnection(
                    participantId: self.id,
                    connected: connected
                )
            }
        }
    }

    func shutdown() {
        connectionTask?.cancel()
        connectionTask = nil
        let state = connectionState
        Task { await state.finish() }
        _ = socket.close(code: .normalClosure)
    }

    private func setupSocket(_ socket: WebSocket) {
        let token = ObjectIdentifier(socket)
        let state = connectionState
        Task { await state.attach(to: token) }

        socket.pingInterval = .seconds(5)
        socket.onClose.whenComplete { _ in
            Task { await state.disconnected(socketToken: token) }
        }
    }
}

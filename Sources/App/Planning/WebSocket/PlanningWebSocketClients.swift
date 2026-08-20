//
//  PlanningWebSocketClients.swift
//
//  Created by Armand Kamffer on 2020/10/01.
//

import Foundation
import Vapor

actor PlanningWebSocketClients {
    let eventLoop: EventLoop
    private var storage: [UUID: PlanningWebSocketClient]
    private var reservedIDs: Set<UUID> = []

    init(eventLoop: EventLoop, storage: [UUID: PlanningWebSocketClient] = [:]) {
        self.eventLoop = eventLoop
        self.storage = storage
    }

    func add(_ client: PlanningWebSocketClient) {
        reservedIDs.remove(client.id)
        storage[client.id] = client
    }

    func remove(_ client: PlanningWebSocketClient) {
        reservedIDs.remove(client.id)
        storage[client.id] = nil
    }

    func reserve(_ uuid: UUID) -> Bool {
        guard storage[uuid] == nil, !reservedIDs.contains(uuid) else { return false }
        reservedIDs.insert(uuid)
        return true
    }

    func release(_ uuid: UUID) {
        reservedIDs.remove(uuid)
    }

    func find(_ uuid: UUID) -> PlanningWebSocketClient? {
        storage[uuid]
    }

    func authorized(_ uuid: UUID,
                    type: PlanningSystemType,
                    socket: WebSocket) -> PlanningWebSocketClient? {
        guard let client = storage[uuid],
              client.type == type,
              client.accepts(socket)
        else { return nil }
        return client
    }

    func reconnect(_ uuid: UUID,
                   type: PlanningSystemType,
                   socket: WebSocket) -> PlanningWebSocketClient? {
        guard let client = storage[uuid], client.type == type else { return nil }
        client.reconnect(to: socket)
        return client
    }

    func exists(_ uuid: UUID) -> Bool {
        storage[uuid] != nil || reservedIDs.contains(uuid)
    }

    func find(sessionId: String, type: PlanningSystemType) -> [PlanningWebSocketClient] {
        storage.values.filter { $0.sessionId == sessionId && $0.type == type }
    }

    func send(_ data: Data, to uuid: UUID) {
        storage[uuid]?.send(data)
    }

    func send(_ data: Data, sessionId: String, type: PlanningSystemType) {
        find(sessionId: sessionId, type: type).forEach { $0.send(data) }
    }

    func close(sessionId: String, type: PlanningSystemType) {
        let clients = find(sessionId: sessionId, type: type)
        clients.forEach { client in
            client.shutdown()
            storage[client.id] = nil
        }
    }

    func close(_ uuid: UUID) {
        reservedIDs.remove(uuid)
        guard let client = storage.removeValue(forKey: uuid) else { return }
        client.shutdown()
    }

    func shutdown() {
        let clients = Array(storage.values)
        storage.removeAll()
        reservedIDs.removeAll()
        clients.forEach { $0.shutdown() }
    }
}

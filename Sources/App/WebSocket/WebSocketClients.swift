//
//  WebSocketClients.swift
//  
//
//  Created by Armand Kamffer on 2020/10/01.
//

import Vapor

class WebSocketClients {
    var eventLoop: EventLoop
    var storage: [UUID: WebSocketClient]
    
    var active: [WebSocketClient] {
        storage.values.filter { !$0.socket.isClosed }
    }
    
    init(eventLoop: EventLoop, storage: [UUID : WebSocketClient] = [:]) {
        self.eventLoop = eventLoop
        self.storage = storage
    }
    
    func add(_ client: WebSocketClient) {
        storage[client.id] = client
    }
    
    func remove(_ client: WebSocketClient) {
        storage[client.id] = nil
    }
    
    func find(_ uuid: UUID) -> WebSocketClient? {
        storage[uuid]
    }
    
    deinit {
        let futures = storage.values.map { $0.socket.close() }
        try? self.eventLoop.flatten(futures).wait()
    }
}

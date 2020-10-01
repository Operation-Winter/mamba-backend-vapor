//
//  WebSocketClients.swift
//  
//
//  Created by Armand Kamffer on 2020/10/01.
//

import Vapor

class WebSocketClients<T: WebSocketClient> {
    var eventLoop: EventLoop
    var storage: [UUID: T]
    
    var active: [T] {
        storage.values.filter { !$0.socket.isClosed }
    }
    
    init(eventLoop: EventLoop, storage: [UUID : T] = [:]) {
        self.eventLoop = eventLoop
        self.storage = storage
    }
    
    func add(_ client: T) {
        storage[client.id] = client
    }
    
    func remove(_ client: T) {
        storage[client.id] = nil
    }
    
    func find(_ uuid: UUID) -> T? {
        storage[uuid]
    }
    
    func exists(_ uuid: UUID) -> Bool {
        storage.keys.contains(uuid)
    }
    
    deinit {
        let futures = storage.values.map { $0.socket.close() }
        try? self.eventLoop.flatten(futures).wait()
    }
}

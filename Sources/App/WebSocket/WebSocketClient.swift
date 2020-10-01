//
//  WebSocketClient.swift
//  
//
//  Created by Armand Kamffer on 2020/10/01.
//

import Vapor

class WebSocketClient {
    var id: UUID
    var socket: WebSocket
    
    init(id: UUID, socket: WebSocket) {
        self.id = id
        self.socket = socket
    }
}

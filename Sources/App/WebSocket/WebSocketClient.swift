//
//  WebSocketClient.swift
//  
//
//  Created by Armand Kamffer on 2020/10/01.
//

import Vapor

protocol WebSocketClient {
    var id: UUID { get }
    var socket: WebSocket { get }
}

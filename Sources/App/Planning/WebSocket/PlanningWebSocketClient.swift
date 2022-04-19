//
//  PlanningWebSocketClient.swift
//  
//
//  Created by Armand Kamffer on 2020/10/01.
//

import Vapor
import OpenCombine

class PlanningWebSocketClient: WebSocketClient {
    var id: UUID
    var socket: WebSocket {
        didSet {
            setupSocket(socket)
        }
    }
    var sessionId: String
    var type: PlanningSystemType
    @OpenCombine.Published public var connected: Bool
    private let pingInterval: Int64 = 5
    private let timeout: Int64 = 5
    private var timer: DispatchSourceTimer?
    private var timeLeft: Int64 = 0
    
    init(id: UUID, socket: WebSocket, sessionId: String, type: PlanningSystemType, connected: Bool) {
        self.id = id
        self.socket = socket
        self.sessionId = sessionId
        self.type = type
        self.connected = connected
        setupSocket(socket)
        setupTimer()
    }
    
    private func setupSocket(_ socket: WebSocket) {
        resetTimeLeft()
        socket.pingInterval = .seconds(pingInterval)
        socket.onPong { [weak self] _ in
            self?.resetTimeLeft()
        }
    }
    
    private func resetTimeLeft() {
        timeLeft = pingInterval + timeout
    }
    
    private func setupTimer() {
        timer = DispatchSource.makeTimerSource()
        timer?.schedule(deadline: .now(), repeating: .seconds(1))
  
        timer?.setEventHandler() { [weak self] in
            guard let self = self else { return }
            self.timeLeft = self.timeLeft > 0 ? self.timeLeft - 1 : 0

            if self.timeLeft == 0 && self.connected {
                self.connected = false
            }
        }
    
        timer?.activate()
    }
}

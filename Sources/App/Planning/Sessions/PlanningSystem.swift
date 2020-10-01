//
//  PlanningSystem.swift
//  
//
//  Created by Armand Kamffer on 2020/10/01.
//

import Vapor

class PlanningSystem {
    var clients: WebSocketClients
    
    init(eventLoop: EventLoop) {
        clients = WebSocketClients(eventLoop: eventLoop)
    }
    
    func connect(_ webSocket: WebSocket, type: PlanningSystemType) {
        webSocket.onBinary { [unowned self] webSocket, buffer in
            parseBufferMessage(webSocket: webSocket, buffer: buffer, type: type)
        }
    }
    
    func parseBufferMessage(webSocket: WebSocket, buffer: ByteBuffer, type: PlanningSystemType) {
        switch type {
        case .host:
            guard let command = buffer.decodeWebSocketMessage(PlanningCommands.HostServerReceive.self) else {
                //TODO: Invalid command
                return
            }
            execute(command: command)
        case .join:
            guard let command = buffer.decodeWebSocketMessage(PlanningCommands.JoinServerReceive.self) else {
                //TODO: Invalid command
                return
            }
            execute(command: command)
        }
    }
    
    func execute(command: PlanningCommands.HostServerReceive) {
        switch command {
        case .startSession(let message):
            break
        case .addTicket(let message):
            break
        case .skipVote(let message):
            break
        case .removeParticipant(let message):
            break
        case .endSession:
            break
        case .finishVoting:
            break
        case .revote:
            break
        }
    }
    
    func execute(command: PlanningCommands.JoinServerReceive) {
        switch command {
        case .joinSession(let message):
            break
        case .vote(let message):
            break
        case .leaveSession:
            break
        }
    }
    
    func send(command: PlanningCommands.HostServerSend) {
        
    }
    
    func send(command: PlanningCommands.JoinServerSend) {
        
    }
}

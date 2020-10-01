//
//  PlanningSystem+JoinExtension.swift
//  
//
//  Created by Armand Kamffer on 2020/10/01.
//

import Foundation
import Vapor

// MARK: - Join related command methods
extension PlanningSystem {
    func execute(command: PlanningCommands.JoinServerReceive, webSocket: WebSocket) {
        switch command {
        case .joinSession(_):
            // TODO: MAM-113
            break
        case .vote(_):
            // TODO: MAM-114
            break
        case .leaveSession:
            // TODO: MAM-115
            break
        }
    }
    
    func send(command: PlanningCommands.JoinServerSend) {
        
    }
}

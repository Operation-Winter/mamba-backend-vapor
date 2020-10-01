//
//  PlanningSessionDelegate.swift
//  
//
//  Created by Armand Kamffer on 2020/10/01.
//

import Foundation

protocol PlanningSessionDelegate: class {
    func send(command: PlanningCommands.HostServerSend, clientUuid: UUID)
    func send(command: PlanningCommands.JoinServerSend, clientUuid: UUID)
    func send(command: PlanningCommands.HostServerSend, sessionId: String)
    func send(command: PlanningCommands.JoinServerSend, sessionId: String)
    func sendInvalidCommand(error: PlanningInvalidCommandError, type: PlanningSystemType, clientUuid: UUID)
    func sendInvalidSessionCommand(error: PlanningInvalidSessionError, clientUuid: UUID)
}

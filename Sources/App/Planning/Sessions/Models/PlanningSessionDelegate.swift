//
//  PlanningSessionDelegate.swift
//  
//
//  Created by Armand Kamffer on 2020/10/01.
//

import Foundation
import MambaNetworking

protocol PlanningSessionDelegate: class {
    func send<T: Encodable>(command: T, clientUuid: UUID)
    func send(hostCommand command: PlanningCommands.HostServerSend, clientUuid: UUID)
    func send(joinCommand command: PlanningCommands.JoinServerSend, clientUuid: UUID)
    func send(hostCommand command: PlanningCommands.HostServerSend, sessionId: String)
    func send(joinCommand command: PlanningCommands.JoinServerSend, sessionId: String)
    func send(stateMessage: PlanningSessionStateMessage, state: PlanningSessionState, sessionId: String)
    func send(stateMessage: PlanningSessionStateMessage, state: PlanningSessionState, clientUuid: UUID)
    func sendInvalidCommand(error: PlanningInvalidCommandError, type: PlanningSystemType, clientUuid: UUID)
    func sendInvalidSessionCommand(error: PlanningInvalidSessionError, clientUuid: UUID)
}

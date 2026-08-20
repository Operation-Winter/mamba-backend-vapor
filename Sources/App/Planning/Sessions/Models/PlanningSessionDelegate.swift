//
//  PlanningSessionDelegate.swift
//  
//
//  Created by Armand Kamffer on 2020/10/01.
//

import Foundation
import MambaNetworking

protocol PlanningSessionDelegate: AnyObject {
    func send<T: Encodable>(command: T, clientUuid: UUID) async
    func send(hostCommand command: PlanningCommands.HostServerSend, clientUuid: UUID) async
    func send(joinCommand command: PlanningCommands.JoinServerSend, clientUuid: UUID) async
    func send(hostCommand command: PlanningCommands.HostServerSend, sessionId: String) async
    func send(joinCommand command: PlanningCommands.JoinServerSend, sessionId: String) async
    func send(stateMessage: PlanningSessionStateMessage, state: PlanningSessionState, sessionId: String) async
    func send(stateMessage: PlanningSessionStateMessage, state: PlanningSessionState, clientUuid: UUID) async
    func sendInvalidCommand(error: PlanningInvalidCommandError, type: PlanningSystemType, clientUuid: UUID) async
    func sendInvalidSessionCommand(error: PlanningInvalidSessionError, clientUuid: UUID) async
    func sessionHasTimedOut(sessionId: String) async
}

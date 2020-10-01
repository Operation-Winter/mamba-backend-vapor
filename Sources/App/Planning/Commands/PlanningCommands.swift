//
//  PlanningCommand.swift
//  mamba
//
//  Created by Armand Kamffer on 2020/07/13.
//  Copyright © 2020 Armand Kamffer. All rights reserved.
//

import Foundation

public enum PlanningCommands {
    public enum HostKey: String, CaseIterable {
        // MARK: - Planning Host Send
        case startSession = "START_SESSION"
        case addTicket = "ADD_TICKET"
        case skipVote = "SKIP_VOTE"
        case removeParticipant = "REMOVE_PARTICIPANT"
        case endSession = "END_SESSION"
        case finishVoting = "FINISH_VOTING"
        case revote = "REVOTE"
        
        // MARK: - Planning Host Receive
        case noneState = "NONE_STATE"
        case votingState = "VOTING_STATE"
        case finishedState = "FINISHED_STATE"
        case invalidCommand = "INVALID_COMMAND"
    }

    public enum HostServerReceive: Codable {
        case startSession(uuid: UUID, message: PlanningStartSessionMessage)
        case addTicket(uuid: UUID, message: PlanningAddTicketMessage)
        case skipVote(uuid: UUID, message: PlanningSkipVoteMessage)
        case removeParticipant(uuid: UUID, message: PlanningRemoveParticipantMessage)
        case endSession(uuid: UUID)
        case finishVoting(uuid: UUID)
        case revote(uuid: UUID)
    }
    
    public enum HostServerSend: Codable {
        case noneState(PlanningSessionStateMessage)
        case votingState(PlanningSessionStateMessage)
        case finishedState(PlanningSessionStateMessage)
        case invalidCommand(PlanningInvalidCommandMessage)
    }
    
    public enum JoinKey: String, CaseIterable {
        // MARK: - Planning Join Send
        case joinSession = "JOIN_SESSION"
        case vote = "VOTE"
        case leaveSession = "LEAVE_SESSION"
        
        // MARK: - Planning Host Receive
        case noneState = "NONE_STATE"
        case votingState = "VOTING_STATE"
        case finishedState = "FINISHED_STATE"
        case invalidCommand = "INVALID_COMMAND"
        case invalidSession = "INVALID_SESSION"
        case removeParticipant = "REMOVE_PARTICIPANT"
        case endSession = "END_SESSION"
    }
    
    public enum JoinServerReceive: Codable {
        case joinSession(uuid: UUID, message: PlanningJoinSessionMessage)
        case vote(uuid: UUID, message: PlanningVoteMessage)
        case leaveSession(uuid: UUID)
    }
    
    public enum JoinServerSend: Codable {
        case noneState(PlanningSessionStateMessage)
        case votingState(PlanningSessionStateMessage)
        case finishedState(PlanningSessionStateMessage)
        case invalidCommand(PlanningInvalidCommandMessage)
        case invalidSession
        case removeParticipant
        case endSession
    }
}

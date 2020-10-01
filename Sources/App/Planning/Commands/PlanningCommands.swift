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
        case startSession(PlanningStartSessionMessage)
        case addTicket(PlanningAddTicketMessage)
        case skipVote(PlanningSkipVoteMessage)
        case removeParticipant(PlanningRemoveParticipantMessage)
        case endSession
        case finishVoting
        case revote
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
        case joinSession(PlanningJoinSessionMessage)
        case vote(PlanningVoteMessage)
        case leaveSession
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

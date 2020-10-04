//
//  PlanningSession.swift
//  
//
//  Created by Armand Kamffer on 2020/10/01.
//

import Foundation

class PlanningSession {
    private(set) var id: String
    private(set) var name: String
    private(set) var availableCards: [PlanningCard]
    private(set) var participants: [PlanningParticipant]
    private(set) var ticket: PlanningTicket?
    private(set) var state: PlanningSessionState
    private(set) weak var delegate: PlanningSessionDelegate?
    
    private var stateMessage: PlanningSessionStateMessage {
        PlanningSessionStateMessage(sessionCode: id,
                                    sessionName: name,
                                    availableCards: availableCards,
                                    participants: participants,
                                    ticket: ticket)
    }
    
    init(id: String, name: String, availableCards: [PlanningCard], participants: [PlanningParticipant] = [], ticket: PlanningTicket? = nil, state: PlanningSessionState = .none, delegate: PlanningSessionDelegate? = nil) {
        self.id = id
        self.name = name
        self.availableCards = availableCards
        self.participants = participants
        self.ticket = ticket
        self.state = state
        self.delegate = delegate
    }
    
    func sendStateToAll() {
        switch state {
        case .none:
            delegate?.send(command: PlanningCommands.HostServerSend.noneState(stateMessage), sessionId: id)
            delegate?.send(command: PlanningCommands.JoinServerSend.noneState(stateMessage), sessionId: id)
        case .voting:
            delegate?.send(command: PlanningCommands.HostServerSend.votingState(stateMessage), sessionId: id)
            delegate?.send(command: PlanningCommands.JoinServerSend.votingState(stateMessage), sessionId: id)
        case .votingFinished:
            delegate?.send(command: PlanningCommands.HostServerSend.finishedState(stateMessage), sessionId: id)
            delegate?.send(command: PlanningCommands.JoinServerSend.finishedState(stateMessage), sessionId: id)
        }
    }
    
    func add(participant: PlanningParticipant) {
        participants.append(participant)
    }
    
    func add(ticket: PlanningTicket) {
        self.ticket = ticket
        state = .voting
    }
    
    func add(vote card: PlanningCard?, uuid: UUID) {
        guard
            state == .voting,
            let ticket = ticket,
            participants.contains(where: { $0.participantId == uuid })
        else {
            delegate?.sendInvalidCommand(error: .invalidParameters, type: .join, clientUuid: uuid)
            return
        }
        ticket.removeVotes(participantId: uuid)
        let vote = PlanningTicketVote(participantId: uuid, selectedCard: card)
        ticket.add(vote: vote)
        
        if ticket.ticketVotes.count == participants.count {
            state = .votingFinished
        }
    }
    
    func remove(participantId: UUID) {
        ticket?.removeVotes(participantId: participantId)
        participants.removeAll { $0.participantId == participantId }
    }
    
    func resetVotes() {
        ticket?.removeVotesAll()
        state = .voting
    }
}

//
//  PlanningSession.swift
//  
//
//  Created by Armand Kamffer on 2020/10/01.
//

import Foundation
import MambaNetworking

class PlanningSession {
    private(set) var id: String
    private(set) var name: String
    private(set) var availableCards: [PlanningCard]
    private(set) var participants: [PlanningParticipant]
    private(set) var ticket: PlanningTicket?
    private(set) var state: PlanningSessionState
    private(set) weak var delegate: PlanningSessionDelegate?
    private var timer: DispatchSourceTimer?
    
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
    
    func sendState(to uuid: UUID) {
        delegate?.send(stateMessage: stateMessage, state: state, clientUuid: uuid)
    }
    
    func sendStateToAll() {
        delegate?.send(stateMessage: stateMessage, state: state, sessionId: id)
    }
    
    func add(participant: PlanningParticipant) {
        participants.append(participant)
    }
    
    func add(ticket: PlanningTicket) {
        self.ticket = ticket
        state = .voting
    }
    
    func updateTicket(title: String, description: String) {
        ticket?.title = title
        ticket?.description = description
    }
    
    func updateParticipant(participantId: UUID, name: String) {
        participants
            .first { $0.participantId == participantId }?
            .name = name
    }
    
    func add(vote card: PlanningCard?, uuid: UUID) {
        guard state == .voting,
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
    
    func finishVotes() {
        participants.forEach { participant in
            if ticket?.ticketVotes.contains(where: { $0.participantId == participant.participantId }) == false {
                add(vote: nil, uuid: participant.participantId)
            }
        }
        state = .votingFinished
    }
    
    func startTimer(with timeInterval: TimeInterval, uuid: UUID) {
        guard state == .voting,
              ticket != nil
        else {
            delegate?.sendInvalidCommand(error: .invalidParameters, type: .host, clientUuid: uuid)
            return
        }
        
        timer = DispatchSource.makeTimerSource()
        var runCount = 0
        timer?.schedule(deadline: .now(), repeating: .seconds(1))
  
        timer?.setEventHandler() { [weak self] in
            guard let self = self else { return }
            runCount += 1
            self.sendStateToAll()
            if runCount >= Int(timeInterval) {
                self.timer?.suspend()
                self.finishVotes()
                self.sendStateToAll()
            }
        }
    
        timer?.activate()
    }
}

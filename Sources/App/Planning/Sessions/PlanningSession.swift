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
}

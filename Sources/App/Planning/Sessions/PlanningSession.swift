//
//  PlanningSession.swift
//  
//
//  Created by Armand Kamffer on 2020/10/01.
//

import Foundation

class PlanningSession {
    let id: String
    let name: String
    let availableCards: [PlanningCard]
    private(set) var participants: [PlanningParticipant]
    private(set) var ticket: PlanningTicket?
    private(set) var state: PlanningSessionState
    
    var stateMessage: PlanningSessionStateMessage {
        PlanningSessionStateMessage(sessionCode: id,
                                    sessionName: name,
                                    availableCards: availableCards,
                                    participants: participants,
                                    ticket: ticket)
    }
    
    init(id: String, name: String, availableCards: [PlanningCard], participants: [PlanningParticipant] = [], ticket: PlanningTicket? = nil, state: PlanningSessionState = .none) {
        self.id = id
        self.name = name
        self.availableCards = availableCards
        self.participants = participants
        self.ticket = ticket
        self.state = state
    }
}

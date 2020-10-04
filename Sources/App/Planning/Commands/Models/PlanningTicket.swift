//
//  PlanningTicket.swift
//  mamba
//
//  Created by Armand Kamffer on 2020/08/07.
//  Copyright © 2020 Armand Kamffer. All rights reserved.
//

import Foundation

public class PlanningTicket: Codable {
    public private(set) var title: String
    public private(set) var description: String
    public private(set) var ticketVotes: [PlanningTicketVote]
    
    public init(title: String, description: String, ticketVotes: [PlanningTicketVote] = []) {
        self.title = title
        self.description = description
        self.ticketVotes = ticketVotes
    }
    
    func removeVotes(participantId: UUID) {
        ticketVotes.removeAll { $0.participantId == participantId }
    }
    
    func removeVotesAll() {
        ticketVotes.removeAll()
    }
    
    func add(vote: PlanningTicketVote) {
        ticketVotes.append(vote)
    }
}

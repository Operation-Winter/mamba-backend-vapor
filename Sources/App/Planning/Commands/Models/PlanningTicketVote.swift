//
//  PlanningTicketVote.swift
//  mamba
//
//  Created by Armand Kamffer on 2020/08/13.
//  Copyright © 2020 Armand Kamffer. All rights reserved.
//

import Foundation

public class PlanningTicketVote: Codable {
    public private(set) var participantId: UUID
    public private(set) var selectedCard: PlanningCard?
    public var skipped: Bool {
        selectedCard == nil
    }
    
    init(participantId: UUID, selectedCard: PlanningCard?) {
        self.participantId = participantId
        self.selectedCard = selectedCard
    }
}

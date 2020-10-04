//
//  PlanningParticipant.swift
//  mamba
//
//  Created by Armand Kamffer on 2020/08/04.
//  Copyright © 2020 Armand Kamffer. All rights reserved.
//

import Foundation

public class PlanningParticipant: Codable, Identifiable {
    public private(set) var participantId: UUID
    public private(set) var name: String
    
    public init(participantId: UUID, name: String) {
        self.participantId = participantId
        self.name = name
    }
}

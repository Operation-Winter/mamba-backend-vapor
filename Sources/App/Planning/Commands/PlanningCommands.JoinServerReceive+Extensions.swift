//
//  PlanningCommand.JoinServerReceive+Extensions.swift
//  mamba
//
//  Created by Armand Kamffer on 2020/07/31.
//  Copyright © 2020 Armand Kamffer. All rights reserved.
//

import Foundation

public extension PlanningCommands.JoinServerReceive {
    private enum CodingKeys: String, CodingKey {
        case uuid
        case type
        case message
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        let uuid = try container.decode(UUID.self, forKey: .uuid)
        
        switch type {
        case PlanningCommands.JoinKey.joinSession.rawValue:
            let model = try container.decode(PlanningJoinSessionMessage.self, forKey: .message)
            self = .joinSession(uuid: uuid, message: model)
        case PlanningCommands.JoinKey.vote.rawValue:
            let model = try container.decode(PlanningVoteMessage.self, forKey: .message)
            self = .vote(uuid: uuid, message: model)
        case PlanningCommands.JoinKey.leaveSession.rawValue:
            self = .leaveSession(uuid: uuid)
        case PlanningCommands.JoinKey.reconnect.rawValue:
            self = .reconnect(uuid: uuid)
        default:
            throw DecodingError.keyNotFound(CodingKeys.message, DecodingError.Context(codingPath: [], debugDescription: "Invalid key: \(type)"))
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.rawValue, forKey: .type)
        
        switch self {
        case .joinSession(_, let message): try container.encode(message, forKey: .message)
        case .vote(_, let message): try container.encode(message, forKey: .message)
        default:
            break
        }
    }
    
    var rawValue: String {
        switch self {
        case .joinSession: return PlanningCommands.JoinKey.joinSession.rawValue
        case .vote: return PlanningCommands.JoinKey.vote.rawValue
        case .leaveSession: return PlanningCommands.JoinKey.leaveSession.rawValue
        case .reconnect: return PlanningCommands.JoinKey.reconnect.rawValue
        }
    }
}

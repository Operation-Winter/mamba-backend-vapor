//
//  PlanningInvalidCommandError.swift
//  
//
//  Created by Armand Kamffer on 2020/10/01.
//

import Foundation

enum PlanningInvalidCommandError {
    case noSessionCodeSpecified
    case doesntExist
    case noServerCapacity
    case invalidUuid
    case invalidParameters
    case invalidState
    
    var code: String {
        switch self {
        case .noSessionCodeSpecified: return "0000"
        case .doesntExist: return "0002"
        case .noServerCapacity: return "0003"
        case .invalidUuid: return "0004"
        case .invalidParameters: return "0005"
        case .invalidState: return "0006"
        }
    }
    
    var description: String {
        switch self {
        case .noSessionCodeSpecified: return "No session code has been specified."
        case .doesntExist: return "The command doesn't exist."
        case .noServerCapacity: return "The server has run out of capacity, could not create a new planning session."
        case .invalidUuid: return "Invalid identifier"
        case .invalidParameters: return "Invalid parameters"
        case .invalidState: return "The session is not in the correct state for this command to be executed."
        }
    }
}

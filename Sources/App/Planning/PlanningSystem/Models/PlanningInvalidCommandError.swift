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
    
    var code: String {
        switch self {
        case .noSessionCodeSpecified: return "0000"
        case .doesntExist: return "0002"
        case .noServerCapacity: return "0003"
        }
    }
    
    var description: String {
        switch self {
        case .noSessionCodeSpecified: return "No session code has been specified."
        case .doesntExist: return "The command doesn't exist."
        case .noServerCapacity: return "The server has run out of capacity, could not create a new planning session."
        }
    }
}

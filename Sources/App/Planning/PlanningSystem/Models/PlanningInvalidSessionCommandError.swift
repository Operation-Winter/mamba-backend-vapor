//
//  PlanningInvalidSessionCommandError.swift
//  
//
//  Created by Armand Kamffer on 2020/10/01.
//

import Foundation

enum PlanningInvalidSessionError {
    case doesntExist
    
    var code: String {
        switch self {
        case .doesntExist: return "0001"
        }
    }
    
    var description: String {
        switch self {
        case .doesntExist: return "The specified session code doesn't exist or is no longer available."
        }
    }
}

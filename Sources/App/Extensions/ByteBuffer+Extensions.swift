//
//  ByteBuffer+Extensions.swift
//  
//
//  Created by Armand Kamffer on 2020/10/01.
//

import Foundation
import Vapor

extension ByteBuffer {
    func decodeWebSocketMessage<T: Codable>(_ type: T.Type) -> T? {
        try? JSONDecoder().decode(T.self, from: self)
    }
}

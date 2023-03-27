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
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(T.self, from: self)
    }
}

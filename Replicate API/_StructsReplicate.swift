//
//  Untitled.swift
//  Test2
//
//  Created by Roger Ochoa on 10/3/24.
//

import Foundation

struct PredictionResponse: Codable, Identifiable {
    let id: String
    let model: String
    let version: String
    let input: [String: CodableValue]?
    let logs: String?
    let output: [String]?
    let data_removed: Bool
    let error: String?
    let status: String
    let created_at: String
    let started_at: String
    let completed_at: String
    let urls: URLS
    let metrics: Metrics
}

struct URLS: Codable {
    let cancel: String
    let get: String
}

struct Metrics: Codable {
    let predict_time: Double
    let total_time: Double?
}

// A wrapper for both string and number types
struct CodableValue: Codable {
    let value: Any
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intValue = try? container.decode(Int.self) {
            value = intValue
        } else if let doubleValue = try? container.decode(Double.self) {
            value = doubleValue
        } else if let stringValue = try? container.decode(String.self) {
            value = stringValue
        } else {
            value = ""
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let intValue = value as? Int {
            try container.encode(intValue)
        } else if let doubleValue = value as? Double {
            try container.encode(doubleValue)
        } else if let stringValue = value as? String {
            try container.encode(stringValue)
        }
    }
}

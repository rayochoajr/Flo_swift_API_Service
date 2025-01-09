//
//  _StructsChatGPT.swift
//  Lumeo
//
//  Created by Roger Ochoa on 10/24/24.
//

import Foundation




// Define the structure for the request payload
struct ChatGPTRequest: Codable {
    let model: String
    let messages: [Message]
    let temperature: Double
    let max_tokens: Int
    let top_p: Double
    let frequency_penalty: Double
    let presence_penalty: Double
    let response_format: ResponseFormat
    
    struct Message: Codable {
        let role: String
        let content: [Content]
        
        struct Content: Codable {
            let type: String
            let text: String
        }
    }
    
    struct ResponseFormat: Codable {
        let type: String
    }
}

// Define the structure for the response payload
struct ChatGPTResponse: Codable {
    let id: String
    let object: String
    let created: Int
    let model: String
    let choices: [Choice]
    let usage: Usage

    struct Choice: Codable {
        let index: Int
        let message: Message
        let logprobs: String?
        let finish_reason: String
        
        struct Message: Codable {
            let role: String
            let content: String
            let refusal: String?
        }
    }

    struct Usage: Codable {
        let prompt_tokens: Int
        let completion_tokens: Int
        let total_tokens: Int
        let prompt_tokens_details: PromptTokensDetails
        let completion_tokens_details: CompletionTokensDetails

        struct PromptTokensDetails: Codable {
            let cached_tokens: Int
        }

        struct CompletionTokensDetails: Codable {
            let reasoning_tokens: Int
        }
    }
}


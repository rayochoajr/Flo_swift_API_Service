//
//  APIService.swift
//  Lumeo
//
//  Created by Roger Ochoa on 10/24/24.
//

import Foundation

class ChatGPTService {
    private let apiUrl = Config.chatGPTEndpoint
    
    func generatePrompt(userContent: String, completion: @escaping (ChatGPTResponse?) -> Void) {
        let requestPayload = ChatGPTRequest(
            model: "gpt-4o-mini-2024-07-18",
            messages: [
                ChatGPTRequest.Message(role: "system", content: [
                ]),
                ChatGPTRequest.Message(role: "user", content: [
                    ChatGPTRequest.Message.Content(type: "text", text: userContent)
                ])
            ],
            temperature: 1,
            max_tokens: 2048,
            top_p: 1,
            frequency_penalty: 0,
            presence_penalty: 0,
            response_format: ChatGPTRequest.ResponseFormat(type: "text")
        )

        guard let url = URL(string: apiUrl) else { return }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            let apiKey = try Config.apiKey(Config.Keys.chatGPTApiKey)
            urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            
            let jsonData = try JSONEncoder().encode(requestPayload)
            urlRequest.httpBody = jsonData
            
            let task = URLSession.shared.dataTask(with: urlRequest) { data, response, error in
                if let error = error {
                    print("Error making request: \(error)")
                    completion(nil)
                    return
                }

                guard let data = data else {
                    print("No data received")
                    completion(nil)
                    return
                }

                do {
                    let chatResponse = try JSONDecoder().decode(ChatGPTResponse.self, from: data)
                    completion(chatResponse)
                } catch {
                    print("Error decoding response: \(error)")
                    completion(nil)
                }
            }
            task.resume()
        } catch {
            print("Error setting up request: \(error)")
            completion(nil)
        }
    }
}



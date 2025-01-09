import Foundation
import Combine

class ReplicateService: ObservableObject {
    @Published var payloads: [String] = []
    @Published var responses: [String] = []
    @Published var predictionResponses: [String: Prediction] = [:]
    @Published var currentProgress: Double = 0
    @Published var isProcessing: Bool = false
    
    private let urlString = "https://api.replicate.com/v1/predictions"
    private var cancellables = Set<AnyCancellable>()
    private let jsonEncoder = JSONEncoder()
    private let jsonDecoder = JSONDecoder()
    private let requestQueue: OperationQueue
    private let maxConcurrentRequests = 3
    private let timeoutInterval: TimeInterval = 30.0
    private let maxRetries = 3
    private let retryDelay: TimeInterval = 1.0
    
    init() {
        // Initialize request queue
        self.requestQueue = OperationQueue()
        self.requestQueue.maxConcurrentOperationCount = maxConcurrentRequests
        self.requestQueue.qualityOfService = .userInitiated
        
        setupJSONFormatting()
    }
    
    private func setupJSONFormatting() {
        jsonEncoder.keyEncodingStrategy = .convertToSnakeCase
        jsonDecoder.keyDecodingStrategy = .convertFromSnakeCase
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        jsonDecoder.dateDecodingStrategy = .formatted(dateFormatter)
    }
    
    // MARK: - Image Generation
    func generateImage(
        prompt: String,
        negativePrompt: String? = nil,
        completion: @escaping (Result<Prediction, Error>) -> Void
    ) {
        isProcessing = true
        
        let input = PredictionRequest.Input(
            prompt: prompt,
            negative_prompt: negativePrompt,
            hf_lora: "default",
            lora_scale: 1.0,
            num_outputs: 1,
            aspect_ratio: "1024×1024",
            output_format: "png",
            guidance_scale: 7.0,
            output_quality: 80,
            prompt_strength: 0.8,
            num_inference_steps: 28
        )
        
        let requestPayload = PredictionRequest(
            version: "a747ba68d7fccb91fa1bbb6f11e5eb58017d81f5fa5bfd5e6d8e45d03a914c1c",
            input: input
        )
        
        sendPredictionRequest(with: requestPayload) { [weak self] result in
            self?.isProcessing = false
            completion(result)
        }
    }
    
    // MARK: - Request Handling
    private func sendPredictionRequest(
        with requestPayload: PredictionRequest,
        retryCount: Int = 0,
        completion: @escaping (Result<Prediction, Error>) -> Void
    ) {
        guard let url = URL(string: urlString) else {
            completion(.failure(APIError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = timeoutInterval
        
        do {
            let apiKey = try Config.apiKey(Config.Keys.replicateApiKey)
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            
            let jsonData = try jsonEncoder.encode(requestPayload)
            request.httpBody = jsonData
            
            let payloadString = String(data: jsonData, encoding: .utf8) ?? ""
            payloads.append(payloadString)
            
            let operation = BlockOperation {
                URLSession.shared.dataTaskPublisher(for: request)
                    .tryMap { data, response -> Data in
                        guard let httpResponse = response as? HTTPURLResponse else {
                            throw APIError.invalidResponse
                        }
                        
                        switch httpResponse.statusCode {
                        case 200...299:
                            return data
                        case 401:
                            throw APIError.unauthorized
                        case 403:
                            throw APIError.forbidden
                        case 429:
                            throw APIError.rateLimitExceeded
                        default:
                            throw APIError.serverError(statusCode: httpResponse.statusCode)
                        }
                    }
                    .decode(type: Prediction.self, decoder: self.jsonDecoder)
                    .receive(on: DispatchQueue.main)
                    .sink(
                        receiveCompletion: { [weak self] result in
                            switch result {
                            case .finished:
                                break
                            case .failure(let error):
                                if retryCount < self?.maxRetries ?? 0 {
                                    // Exponential backoff
                                    let delay = self?.retryDelay ?? 1.0 * pow(2.0, Double(retryCount))
                                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                                        self?.sendPredictionRequest(
                                            with: requestPayload,
                                            retryCount: retryCount + 1,
                                            completion: completion
                                        )
                                    }
                                } else {
                                    self?.handleError(error, completion: completion)
                                }
                            }
                        },
                        receiveValue: { [weak self] prediction in
                            self?.handlePredictionResponse(prediction, completion: completion)
                        }
                    )
                    .store(in: &self.cancellables)
            }
            
            requestQueue.addOperation(operation)
            
        } catch {
            completion(.failure(error))
        }
    }
    
    // MARK: - Response Handling
    private func handlePredictionResponse(
        _ prediction: Prediction,
        completion: @escaping (Result<Prediction, Error>) -> Void
    ) {
        if let error = prediction.error {
            completion(.failure(APIError.predictionFailed(message: error)))
            return
        }
        
        predictionResponses[prediction.id] = prediction
        
        if prediction.status == "succeeded" {
            completion(.success(prediction))
        } else if prediction.status == "failed" {
            completion(.failure(APIError.predictionFailed(message: "Prediction failed")))
        } else {
            // Start polling for updates
            startPolling(predictionId: prediction.id, completion: completion)
        }
    }
    
    // MARK: - Error Handling
    private func handleError(
        _ error: Error,
        completion: @escaping (Result<Prediction, Error>) -> Void
    ) {
        let apiError: APIError
        
        switch error {
        case URLError.timedOut:
            apiError = .timeout
        case URLError.notConnectedToInternet:
            apiError = .noConnection
        case is DecodingError:
            apiError = .decodingError
        case let error as APIError:
            apiError = error
        default:
            apiError = .unknown(error)
        }
        
        completion(.failure(apiError))
    }
    
    // MARK: - Polling
    private func startPolling(
        predictionId: String,
        completion: @escaping (Result<Prediction, Error>) -> Void
    ) {
        guard let prediction = predictionResponses[predictionId],
              let pollURL = URL(string: prediction.urls.get) else {
            completion(.failure(APIError.invalidURL))
            return
        }
        
        var request = URLRequest(url: pollURL)
        
        do {
            let apiKey = try Config.apiKey(Config.Keys.replicateApiKey)
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            
            Timer.publish(every: 2.0, on: .main, in: .common)
                .autoconnect()
                .flatMap { _ in
                    URLSession.shared.dataTaskPublisher(for: request)
                        .map(\.data)
                        .decode(type: Prediction.self, decoder: self.jsonDecoder)
                        .catch { error -> AnyPublisher<Prediction, Never> in
                            completion(.failure(error))
                            return Empty().eraseToAnyPublisher()
                        }
                }
                .receive(on: DispatchQueue.main)
                .sink { [weak self] prediction in
                    self?.handlePollResponse(prediction, completion: completion)
                }
                .store(in: &cancellables)
            
        } catch {
            completion(.failure(error))
        }
    }
    
    private func handlePollResponse(
        _ prediction: Prediction,
        completion: @escaping (Result<Prediction, Error>) -> Void
    ) {
        predictionResponses[prediction.id] = prediction
        
        // Update progress if available
        if let progress = prediction.metrics?["predict_time"] as? Double {
            currentProgress = min(progress * 100, 100)
        }
        
        switch prediction.status {
        case "succeeded":
            cancellables.removeAll()
            completion(.success(prediction))
        case "failed":
            cancellables.removeAll()
            completion(.failure(APIError.predictionFailed(message: prediction.error ?? "Unknown error")))
        default:
            break // Continue polling
        }
    }
    
    // MARK: - Cancellation
    func cancelPrediction(
        _ prediction: Prediction,
        completion: @escaping (Error?) -> Void
    ) {
        guard let url = URL(string: prediction.urls.cancel) else {
            completion(APIError.invalidURL)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        do {
            let apiKey = try Config.apiKey(Config.Keys.replicateApiKey)
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            
            URLSession.shared.dataTask(with: request) { _, response, error in
                DispatchQueue.main.async {
                    if let error = error {
                        completion(error)
                    } else if let httpResponse = response as? HTTPURLResponse,
                              httpResponse.statusCode != 200 {
                        completion(APIError.serverError(statusCode: httpResponse.statusCode))
                    } else {
                        self.cancellables.removeAll()
                        completion(nil)
                    }
                }
            }.resume()
            
        } catch {
            completion(error)
        }
    }
}

// MARK: - API Errors
enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case unauthorized
    case forbidden
    case rateLimitExceeded
    case serverError(statusCode: Int)
    case timeout
    case noConnection
    case decodingError
    case predictionFailed(message: String)
    case unknown(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .unauthorized:
            return "Unauthorized. Please check your API key"
        case .forbidden:
            return "Access forbidden"
        case .rateLimitExceeded:
            return "Rate limit exceeded. Please try again later"
        case .serverError(let statusCode):
            return "Server error (Status: \(statusCode))"
        case .timeout:
            return "Request timed out"
        case .noConnection:
            return "No internet connection"
        case .decodingError:
            return "Error decoding response"
        case .predictionFailed(let message):
            return "Prediction failed: \(message)"
        case .unknown(let error):
            return "Unknown error: \(error.localizedDescription)"
        }
    }
}

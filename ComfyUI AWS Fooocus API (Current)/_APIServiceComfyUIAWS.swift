import Foundation
import Combine

class ComfyUIAWSService: ObservableObject {
    @Published var payloads: [String] = []
    @Published var responses: [String] = []
    @Published var predictionResponses: [String: ComfyUIPrediction] = [:]
    @Published var currentProgress: ComfyUIPrediction.Progress?
    @Published var isProcessing: Bool = false
    
    private let urlString: String
    private let region: String
    private var cancellables = Set<AnyCancellable>()
    private let jsonEncoder = JSONEncoder()
    private let jsonDecoder = JSONDecoder()
    private let requestQueue: OperationQueue
    private let maxConcurrentRequests = 3
    private let timeoutInterval: TimeInterval = 30.0
    private let maxRetries = 3
    private let retryDelay: TimeInterval = 1.0
    
    init(region: String = Config.AWS.region) {
        self.region = region
        self.urlString = Config.comfyUIEndpoint
        
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
        workflow: ComfyUIWorkflow? = nil,
        nodeId: String? = nil,
        customWorkflowData: [String: String]? = nil,
        executionMode: String = "sequential",
        priority: Int = 1,
        webhookUrl: String? = nil,
        completion: @escaping (Result<ComfyUIPrediction, Error>) -> Void
    ) {
        isProcessing = true
        
        let input = ComfyUIRequest.InputData(
            prompt: prompt,
            hf_lora: "default",
            lora_scale: 1.0,
            num_outputs: 1,
            aspect_ratio: "1024×1024",
            output_format: "png",
            guidance_scale: 7.0,
            output_quality: 80,
            prompt_strength: 0.8,
            num_inference_steps: 28,
            workflow: workflow,
            node_id: nodeId,
            custom_workflow_data: customWorkflowData,
            execution_mode: executionMode,
            priority: priority,
            webhook_url: webhookUrl
        )
        
        let requestPayload = ComfyUIRequest(
            version: Config.comfyUIModelVersion,
            input: input
        )
        
        sendPredictionRequest(with: requestPayload) { [weak self] result in
            self?.isProcessing = false
            completion(result)
        }
    }
    
    // MARK: - Request Handling
    private func sendPredictionRequest(
        with requestPayload: ComfyUIRequest,
        retryCount: Int = 0,
        completion: @escaping (Result<ComfyUIPrediction, Error>) -> Void
    ) {
        guard let url = URL(string: urlString) else {
            completion(.failure(AWSError.invalidRegion))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = timeoutInterval
        
        do {
            let apiKey = try Config.apiKey(Config.Keys.comfyUIApiKey)
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            request.setValue(region, forHTTPHeaderField: "x-aws-region")
            
            let jsonData = try jsonEncoder.encode(requestPayload)
            request.httpBody = jsonData
            
            let payloadString = String(data: jsonData, encoding: .utf8) ?? ""
            payloads.append(payloadString)
            
            let operation = BlockOperation {
                URLSession.shared.dataTaskPublisher(for: request)
                    .tryMap { data, response -> Data in
                        guard let httpResponse = response as? HTTPURLResponse else {
                            throw AWSError.internalServerError
                        }
                        
                        switch httpResponse.statusCode {
                        case 200...299:
                            return data
                        case 401:
                            throw AWSError.invalidCredentials
                        case 403:
                            throw AWSError.invalidAPIKey
                        case 429:
                            throw AWSError.rateLimitExceeded
                        default:
                            throw AWSError.internalServerError
                        }
                    }
                    .decode(type: ComfyUIPrediction.self, decoder: self.jsonDecoder)
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
        _ prediction: ComfyUIPrediction,
        completion: @escaping (Result<ComfyUIPrediction, Error>) -> Void
    ) {
        if let error = prediction.error {
            completion(.failure(NSError(domain: "ComfyUIAWS", code: -1, userInfo: [NSLocalizedDescriptionKey: error])))
            return
        }
        
        predictionResponses[prediction.id] = prediction
        currentProgress = prediction.progress
        
        if prediction.status == "succeeded" {
            completion(.success(prediction))
        } else if prediction.status == "failed" {
            completion(.failure(AWSError.internalServerError))
        } else {
            // Start polling for updates
            startPolling(predictionId: prediction.id, completion: completion)
        }
    }
    
    // MARK: - Error Handling
    private func handleError(
        _ error: Error,
        completion: @escaping (Result<ComfyUIPrediction, Error>) -> Void
    ) {
        let awsError: AWSError
        
        switch error {
        case URLError.timedOut:
            awsError = .requestTimeout
        case URLError.notConnectedToInternet:
            awsError = .serviceUnavailable
        case is DecodingError:
            awsError = .invalidWorkflow
        default:
            if (error as NSError).domain == "com.amazonaws" {
                switch (error as NSError).code {
                case 401:
                    awsError = .invalidCredentials
                case 403:
                    awsError = .invalidAPIKey
                case 429:
                    awsError = .rateLimitExceeded
                default:
                    awsError = .internalServerError
                }
            } else {
                awsError = .internalServerError
            }
        }
        
        completion(.failure(awsError))
    }
    
    // MARK: - Polling
    private func startPolling(
        predictionId: String,
        completion: @escaping (Result<ComfyUIPrediction, Error>) -> Void
    ) {
        guard let prediction = predictionResponses[predictionId],
              let pollURL = URL(string: prediction.urls.get) else {
            completion(.failure(AWSError.invalidWorkflow))
            return
        }
        
        var request = URLRequest(url: pollURL)
        
        do {
            let apiKey = try Config.apiKey(Config.Keys.comfyUIApiKey)
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            request.setValue(region, forHTTPHeaderField: "x-aws-region")
            
            Timer.publish(every: 2.0, on: .main, in: .common)
                .autoconnect()
                .flatMap { _ in
                    URLSession.shared.dataTaskPublisher(for: request)
                        .map(\.data)
                        .decode(type: ComfyUIPrediction.self, decoder: self.jsonDecoder)
                        .catch { error -> AnyPublisher<ComfyUIPrediction, Never> in
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
        _ prediction: ComfyUIPrediction,
        completion: @escaping (Result<ComfyUIPrediction, Error>) -> Void
    ) {
        predictionResponses[prediction.id] = prediction
        currentProgress = prediction.progress
        
        switch prediction.status {
        case "succeeded":
            cancellables.removeAll()
            completion(.success(prediction))
        case "failed":
            cancellables.removeAll()
            completion(.failure(AWSError.internalServerError))
        default:
            break // Continue polling
        }
    }
    
    // MARK: - Cancellation
    func cancelPrediction(
        _ prediction: ComfyUIPrediction,
        completion: @escaping (Error?) -> Void
    ) {
        guard let url = URL(string: prediction.urls.cancel) else {
            completion(AWSError.invalidWorkflow)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        do {
            let apiKey = try Config.apiKey(Config.Keys.comfyUIApiKey)
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            request.setValue(region, forHTTPHeaderField: "x-aws-region")
            
            URLSession.shared.dataTask(with: request) { _, response, error in
                DispatchQueue.main.async {
                    if let error = error {
                        completion(error)
                    } else if let httpResponse = response as? HTTPURLResponse,
                              httpResponse.statusCode != 200 {
                        completion(AWSError.internalServerError)
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
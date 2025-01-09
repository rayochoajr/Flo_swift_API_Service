import Foundation
import Combine

class FooocusService: ObservableObject {
    @Published var payloads: [String] = []
    @Published var responses: [String] = []
    @Published var predictionResponses: [String: FooocusPrediction] = [:]
    @Published var currentStatus: String = "idle"
    @Published var progress: Double = 0.0
    
    private let urlString = Config.fooocusEndpoint
    private var statusCheckTimer: Timer?
    
    init() {
        loadPayloads()
        loadResponses()
    }
    
    // MARK: - Generate Image (Compatibility with existing implementation)
    
    func sendPredictionRequest(with requestPayload: PredictionRequest, completion: @escaping (Prediction?) -> Void) {
        // Convert PredictionRequest to FooocusRequest
        let fooocusPayload = FooocusRequest(
            version: Config.fooocusModelVersion,
            input: .init(
                prompt: requestPayload.input.prompt,
                negative_prompt: nil,
                style_selections: ["Enhance", "HDR"],
                performance_selection: "Speed",
                aspect_ratios_selection: requestPayload.input.aspect_ratio,
                image_number: requestPayload.input.num_outputs,
                image_seed: nil,
                sharpness: 2.0,
                guidance_scale: requestPayload.input.guidance_scale,
                base_model_name: nil,
                refiner_model_name: nil,
                loras: nil,
                advanced_params: nil,
                hf_lora: requestPayload.input.hf_lora,
                lora_scale: requestPayload.input.lora_scale,
                num_outputs: requestPayload.input.num_outputs,
                aspect_ratio: requestPayload.input.aspect_ratio,
                output_format: requestPayload.input.output_format,
                output_quality: requestPayload.input.output_quality,
                prompt_strength: requestPayload.input.prompt_strength,
                num_inference_steps: requestPayload.input.num_inference_steps
            )
        )
        
        // Use the Fooocus implementation but convert the response
        generateImage(with: fooocusPayload) { fooocusPrediction in
            if let fooocusPrediction = fooocusPrediction {
                // Convert FooocusPrediction to Prediction
                let prediction = Prediction(
                    id: fooocusPrediction.id,
                    requestId: fooocusPrediction.requestId,
                    model: fooocusPrediction.model,
                    version: fooocusPrediction.version,
                    input: Prediction.Input(
                        aspectRatio: fooocusPrediction.input.aspectRatio ?? fooocusPrediction.input.aspectRatiosSelection ?? "1024×1024",
                        guidanceScale: fooocusPrediction.input.guidanceScale,
                        hfLora: fooocusPrediction.input.hfLora ?? "",
                        loraScale: fooocusPrediction.input.loraScale ?? 1.0,
                        numInferenceSteps: fooocusPrediction.input.numInferenceSteps ?? 28,
                        numOutputs: fooocusPrediction.input.numOutputs ?? 1,
                        outputFormat: fooocusPrediction.input.outputFormat ?? "png",
                        outputQuality: fooocusPrediction.input.outputQuality ?? 80,
                        prompt: fooocusPrediction.input.prompt,
                        promptStrength: fooocusPrediction.input.promptStrength ?? 0.8
                    ),
                    logs: fooocusPrediction.logs ?? "",
                    output: fooocusPrediction.output,
                    dataRemoved: fooocusPrediction.dataRemoved,
                    error: fooocusPrediction.error,
                    status: fooocusPrediction.status,
                    createdAt: fooocusPrediction.createdAt,
                    urls: Prediction.URLs(
                        cancel: fooocusPrediction.urls.cancel,
                        get: fooocusPrediction.urls.get
                    )
                )
                completion(prediction)
            } else {
                completion(nil)
            }
        }
    }
    
    // MARK: - Generate Image (Fooocus specific)
    
    private func generateImage(
        with requestPayload: FooocusRequest,
        completion: @escaping (FooocusPrediction?) -> Void
    ) {
        clearStalePayloads()
        
        guard let url = URL(string: urlString) else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            let apiKey = try Config.apiKey(Config.Keys.fooocusApiKey)
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            
            let jsonData = try JSONEncoder().encode(requestPayload)
            let payloadString = String(data: jsonData, encoding: .utf8) ?? "Invalid Payload"
            payloads.append(payloadString)
            savePayloads()
            
            request.httpBody = jsonData
            
            URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
                if let data = data {
                    DispatchQueue.main.async {
                        self?.handleResponseData(data, completion: completion)
                    }
                } else if let error = error {
                    print("Error making API call: \(error.localizedDescription)")
                    completion(nil)
                }
            }.resume()
        } catch {
            print("Error setting up request: \(error)")
            completion(nil)
        }
    }
    
    // MARK: - Demo Ready Function
    
    func generateImageWithRealTimeUpdates(
        prompt: String,
        completion: @escaping (Result<[String], Error>) -> Void,
        statusUpdate: @escaping (String) -> Void
    ) {
        // Reset state
        currentStatus = "starting"
        progress = 0.0
        statusUpdate("Starting image generation...")
        
        let requestPayload = FooocusRequest(
            version: Config.fooocusModelVersion,
            input: .init(
                prompt: prompt,
                negative_prompt: "blur, low quality, bad anatomy, bad hands, cropped, worst quality",
                style_selections: ["Enhance", "HDR"],
                performance_selection: "Speed",
                aspect_ratios_selection: "1024×1024",
                image_number: 1,
                image_seed: nil,
                sharpness: 2.0,
                guidance_scale: 7.0,
                base_model_name: nil,
                refiner_model_name: nil,
                loras: nil,
                advanced_params: nil,
                hf_lora: nil,
                lora_scale: nil,
                num_outputs: 1,
                aspect_ratio: "1024×1024",
                output_format: "png",
                output_quality: 80,
                prompt_strength: 0.8,
                num_inference_steps: 28
            )
        )
        
        generateImage(with: requestPayload) { [weak self] prediction in
            guard let self = self else { return }
            
            if let prediction = prediction {
                self.startPollingStatus(predictionId: prediction.id) { result in
                    switch result {
                    case .success(let urls):
                        self.currentStatus = "completed"
                        self.progress = 1.0
                        statusUpdate("Generation completed!")
                        completion(.success(urls))
                    case .failure(let error):
                        self.currentStatus = "error"
                        statusUpdate("Error: \(error.localizedDescription)")
                        completion(.failure(error))
                    }
                } statusHandler: { status in
                    self.currentStatus = status
                    statusUpdate(self.getHumanReadableStatus(status))
                    
                    switch status {
                    case "starting":
                        self.progress = 0.2
                    case "processing":
                        self.progress = 0.5
                    case "succeeded":
                        self.progress = 1.0
                    case "failed":
                        self.progress = 0.0
                    default:
                        break
                    }
                }
            } else {
                self.currentStatus = "error"
                statusUpdate("Failed to start generation")
                completion(.failure(NSError(domain: "FooocusService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to start generation"])))
            }
        }
    }
    
    private func getHumanReadableStatus(_ status: String) -> String {
        switch status {
        case "starting":
            return "Initializing image generation..."
        case "processing":
            return "Creating your image..."
        case "succeeded":
            return "Image generated successfully!"
        case "failed":
            return "Generation failed"
        default:
            return "Status: \(status)"
        }
    }
    
    private func startPollingStatus(
        predictionId: String,
        completion: @escaping (Result<[String], Error>) -> Void,
        statusHandler: @escaping (String) -> Void
    ) {
        // Cancel any existing timer
        statusCheckTimer?.invalidate()
        
        // Create a new timer that checks status every 2 seconds
        statusCheckTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] timer in
            self?.checkPredictionStatus(predictionId: predictionId) { prediction in
                guard let prediction = prediction else {
                    timer.invalidate()
                    completion(.failure(NSError(domain: "FooocusService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to check prediction status"])))
                    return
                }
                
                statusHandler(prediction.status)
                
                switch prediction.status {
                case "succeeded":
                    timer.invalidate()
                    if let output = prediction.output {
                        completion(.success(output))
                    } else {
                        completion(.failure(NSError(domain: "FooocusService", code: -1, userInfo: [NSLocalizedDescriptionKey: "No output URLs in response"])))
                    }
                case "failed":
                    timer.invalidate()
                    completion(.failure(NSError(domain: "FooocusService", code: -1, userInfo: [NSLocalizedDescriptionKey: prediction.error ?? "Unknown error"])))
                case "canceled":
                    timer.invalidate()
                    completion(.failure(NSError(domain: "FooocusService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Generation was canceled"])))
                default:
                    // Continue polling for other status values
                    break
                }
            }
        }
        
        // Start the timer
        statusCheckTimer?.fire()
    }
    
    // MARK: - Handle Response Data
    
    private func handleResponseData(_ data: Data, completion: @escaping (FooocusPrediction?) -> Void) {
        do {
            let responseString = String(data: data, encoding: .utf8) ?? "Invalid Data"
            print("Raw API Response: \(responseString)")
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let prediction = try decoder.decode(FooocusPrediction.self, from: data)
            
            predictionResponses[prediction.id] = prediction
            responses.append(responseString)
            saveResponses()
            
            completion(prediction)
        } catch {
            print("Error decoding response: \(error.localizedDescription)")
            completion(nil)
        }
    }
    
    // MARK: - Check Prediction Status
    
    func checkPredictionStatus(predictionId: String, completion: @escaping (FooocusPrediction?) -> Void) {
        guard let url = URL(string: "\(urlString)/\(predictionId)") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        do {
            let apiKey = try Config.apiKey(Config.Keys.fooocusApiKey)
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            
            URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    print("Error checking status: \(error.localizedDescription)")
                    completion(nil)
                    return
                }
                
                guard let data = data else {
                    print("No data returned from status check")
                    completion(nil)
                    return
                }
                
                do {
                    let prediction = try JSONDecoder().decode(FooocusPrediction.self, from: data)
                    DispatchQueue.main.async {
                        self.predictionResponses[prediction.id] = prediction
                        completion(prediction)
                    }
                } catch {
                    print("Error decoding status response: \(error.localizedDescription)")
                    completion(nil)
                }
            }.resume()
        } catch {
            print("Error setting up status request: \(error)")
            completion(nil)
        }
    }
    
    // MARK: - Storage
    
    private func savePayloads() {
        UserDefaults.standard.set(payloads, forKey: "fooocus_payloads")
    }
    
    private func loadPayloads() {
        payloads = UserDefaults.standard.stringArray(forKey: "fooocus_payloads") ?? []
    }
    
    private func saveResponses() {
        UserDefaults.standard.set(responses, forKey: "fooocus_responses")
    }
    
    private func loadResponses() {
        responses = UserDefaults.standard.stringArray(forKey: "fooocus_responses") ?? []
    }
    
    private func clearStalePayloads() {
        if !payloads.isEmpty {
            payloads.removeAll()
            savePayloads()
        }
    }
    
    func clearAllData() {
        payloads.removeAll()
        responses.removeAll()
        predictionResponses.removeAll()
        savePayloads()
        saveResponses()
    }
    
    deinit {
        statusCheckTimer?.invalidate()
    }
} 
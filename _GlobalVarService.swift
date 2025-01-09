import SwiftUI

class GlobalVariables: ObservableObject {
    static let shared = GlobalVariables()

    @Published var predictionID: String = ""

    // Prediction configuration parameters
    @Published var prompt: String = ""
    @Published var hf_lora: String = "alvdansen/frosting_lane_flux"
    @Published var lora_scale: Double = 1.0
    @Published var num_outputs: Int = 1
    @Published var aspect_ratio: String = "4:5"
    @Published var output_format: String = "png"
    @Published var guidance_scale: Double = 3.5
    @Published var output_quality: Int = 80
    @Published var prompt_strength: Double = 0.8
    @Published var num_inference_steps: Int = 28

    @Published var selectedOption = "LightBox" // Placeholder for UI option

    @Published var savedResponses: [Prediction] = []

    // Reference to API service
    @ObservedObject var apiService = APIServicePost()

    private init() {}

    // MARK: - Setters for various prediction parameters
    func setSelectedOption(_ newOption: String) {
        selectedOption = newOption
    }

    func setID(_ newID: String) {
        predictionID = newID
    }

    func setPrompt(_ newPrompt: String) {
        prompt = newPrompt
    }

    func setHfLora(_ newHfLora: String) {
        hf_lora = newHfLora
    }

    func setLoraScale(_ newScale: Double) {
        lora_scale = newScale
    }

    func setNumOutputs(_ newNum: Int) {
        num_outputs = newNum
    }

    func setAspectRatio(_ newRatio: String) {
        aspect_ratio = newRatio
    }

    func setOutputFormat(_ newFormat: String) {
        output_format = newFormat
    }

    func setGuidanceScale(_ newScale: Double) {
        guidance_scale = newScale
    }

    func setOutputQuality(_ newQuality: Int) {
        output_quality = newQuality
    }

    func setPromptStrength(_ newStrength: Double) {
        prompt_strength = newStrength
    }

    func setNumInferenceSteps(_ newSteps: Int) {
        num_inference_steps = newSteps
    }

    // MARK: - Send Prediction Request
    func sendPayload() {
        // Clear old data (but not everything) before sending a new request
        clearOldData()

        // Creating a PredictionRequest using the current configuration
        let requestPayload = PredictionRequest(
            version: "613a21a57e8545532d2f4016a7c3cfa3c7c63fded03001c2e69183d557a929db", // Example version
            input: .init(
                prompt: prompt,
                hf_lora: hf_lora,
                lora_scale: lora_scale,
                num_outputs: num_outputs,
                aspect_ratio: aspect_ratio,
                output_format: output_format,
                guidance_scale: guidance_scale,
                output_quality: output_quality,
                prompt_strength: prompt_strength,
                num_inference_steps: num_inference_steps
            )
        )

        // Send the payload and handle the result asynchronously
        apiService.sendPredictionRequest(with: requestPayload) { [weak self] prediction in
            guard let self = self, let prediction = prediction else { return }

            // Process the new prediction and update the UI
            self.processPredictionResponse(prediction)
        }
    }

    private func clearOldData() {
        // Clear outdated or irrelevant data before sending a new request
        clearOldResponses()
        apiService.clearStalePayloads() // Clear only stale payloads, not everything
        print("Cleared old data (responses, stale payloads) before sending new request.")
    }

    private func clearOldResponses() {
        // Remove old responses related to outdated requests
        savedResponses.removeAll { response in
            return true // Removing all old responses
        }
        print("Cleared old responses from savedResponses.")
    }

    // MARK: - Handle Prediction Response
    private func processPredictionResponse(_ prediction: Prediction) {
        DispatchQueue.main.async {
            // Assign a unique ID if no requestId is present
            if prediction.requestId == nil {
                let uniqueID = UUID().uuidString
                self.setID(uniqueID)
                print("Generated unique ID: \(uniqueID)")
            } else {
                self.setID(prediction.requestId ?? prediction.id)
            }

            // Check if the prediction already exists in savedResponses
            if !self.savedResponses.contains(where: { $0.id == prediction.id }) {
                self.savedResponses.append(prediction)
                self.apiService.clearStalePayloads() // Clear stale payloads after adding new prediction
                print("Prediction received and added to savedResponses with ID: \(prediction.id)")
            } else {
                print("Duplicate prediction with ID: \(prediction.id) skipped.")
            }

            // Notify the system that a new response was added
            self.apiService.responses.append(prediction.id)
        }
    }

    // MARK: - Load Saved Responses
    func loadSavedResponses() {
        // Reload the saved responses from the API service's predictionResponses dictionary
        let newResponses = Array(apiService.predictionResponses.values)

        // Prevent duplicates from being added
        self.savedResponses = newResponses.filter { newPrediction in
            !self.savedResponses.contains(where: { $0.id == newPrediction.id })
        }

        print("Loaded saved responses from predictionResponses.")
    }

    // MARK: - Get Response List
    func getResponseList() -> [String] {
        // Return the saved responses as strings
        return savedResponses.compactMap { response in
            if let jsonData = try? JSONEncoder().encode(response),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                return jsonString
            }
            return nil
        }
    }
}

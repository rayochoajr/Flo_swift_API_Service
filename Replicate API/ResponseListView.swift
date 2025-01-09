import SwiftUI
import Combine

struct PredictionListView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var apiService = APIServicePost() // Observing the API service
    @Binding var colorModeValue: Bool
    @State private var timer: AnyCancellable? // Timer for polling the API
    
    
    
    var body: some View {
        NavigationView {
            List {
                ForEach(apiService.responses, id: \.self) { response in
                    if let prediction = convertToPrediction(from: response) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Prediction ID:")
                                .font(.headline)
                            Text(prediction.id)
                                .font(.body)
                                .foregroundColor(.gray)
                            
                            if let output = prediction.output, !output.isEmpty {
                                Text("Outputs:")
                                    .font(.headline)
                                ForEach(output, id: \.self) { outputLink in
                                    Text(outputLink)
                                        .foregroundColor(.blue)
                                }
                            } else {
                                
                                if (prediction.status == "failed") {
                                    
                                    Text(
                                        "Request Failed - Error: \(String(describing: prediction.error))"
                                    )
                                        .font(.subheadline)
                                        .foregroundColor(.red)
                                    
                                }else if let highestPercentage = getHighestPercentage(from: prediction.logs) {
                                    Text("Progress: \(highestPercentage)")
                                        .font(.subheadline)
                                        .foregroundColor(.green)
                                } else {
                                    Text("Request Sent")
                                        .font(.subheadline)
                                        .foregroundColor(.red)
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
                .onDelete(perform: deleteResponse)
            }
            .navigationTitle("Predictions")
            .navigationBarItems(trailing: EditButton())
        }
        .onAppear {
            // Load saved responses when the view appears
            apiService.loadResponses()
            startCheckingForOutput()
        }
        .onDisappear {
            stopCheckingForOutput()
        }
    }
    
    // Function to extract the highest percentage from logs
    private func getHighestPercentage(from logs: String) -> String? {
        let regexPattern = "\\d{1,3}\\%"  // Regex pattern to match percentages
        let regex = try! NSRegularExpression(pattern: regexPattern)
        let nsString = logs as NSString
        let results = regex.matches(in: logs, range: NSRange(location: 0, length: nsString.length))
        
        // Extract percentages from matches
        let percentages = results.map { result -> Int in
            let match = nsString.substring(with: result.range)
            let percentage = Int(match.dropLast()) ?? 0  // Remove '%' and convert to Int
            return percentage
        }
        
        // Return the highest percentage as a string, or nil if no matches
        if let highest = percentages.max() {
            return "\(highest)%"
        }
        
        return nil
    }

    // Helper function to decode a Prediction from a JSON string
    private func convertToPrediction(from responseString: String) -> Prediction? {
        if let data = responseString.data(using: .utf8) {
            do {
                let decoder = JSONDecoder()
                return try decoder.decode(Prediction.self, from: data)
            } catch {
               /* print("Error decoding Prediction: \(error.localizedDescription)") */
            }
        }
        return nil
    }

    // Delete response from the list and local storage
    private func deleteResponse(at offsets: IndexSet) {
        offsets.forEach { index in
            let response = apiService.responses[index]
            if let prediction = convertToPrediction(from: response) {
                // Delete the prediction from storage
                apiService.deleteResponse(at: index)
                print("Deleted prediction with ID: \(prediction.id)")
            }
        }
    }
    
    // Start a 5-second timer to periodically check for output
    private func startCheckingForOutput() {
        timer = Timer.publish(every: 0.5, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                checkForOutputUpdates()
            }
    }

    // Stop the timer when the view disappears
    private func stopCheckingForOutput() {
        timer?.cancel()
    }

    // Check the API service for updated outputs
    private func checkForOutputUpdates() {
        // Loop through the responses and check if any prediction now has output
        for response in apiService.responses {
            if let prediction = convertToPrediction(from: response) {
                if prediction.output == nil || prediction.output!.isEmpty {
                    // No output yet, fetch the latest status
                    checkPredictionStatus(predictId: prediction.id)
                }
            }
        }
    }
    
    // Check the status of a specific prediction via a GET request
    private func checkPredictionStatus(predictId: String) {
        apiService.fetchPredictionStatus(predictId: predictId) { updatedPrediction in
            if let updatedPrediction = updatedPrediction {
                DispatchQueue.main.async {
                    if let index = self.apiService.responses.firstIndex(where: { response in
                        return self.convertToPrediction(from: response)?.id == updatedPrediction.id
                    }) {
                        // Update the response in the list with the latest data
                        let updatedResponse = try? JSONEncoder().encode(updatedPrediction)
                        if let updatedResponseString = updatedResponse.flatMap({ String(data: $0, encoding: .utf8) }) {
                            self.apiService.responses[index] = updatedResponseString
                            self.apiService.saveResponses() // Save the updated response to local storage
                        }
                    }
                }
            } else {
                print("Failed to fetch prediction status for ID: \(predictId)")
            }
        }
    }
}

// Preview Provider for SwiftUI Preview
struct PredictionListView_Previews: PreviewProvider {
    @State static var colorModeValue: Bool = false // Provide a state variable for preview
    
    static var previews: some View {
        PredictionListView(colorModeValue: $colorModeValue)
            .preferredColorScheme(colorModeValue ? .dark : .light) // Set color scheme based on the binding
    }
}

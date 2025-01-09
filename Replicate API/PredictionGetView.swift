//
//  Untitled.swift
//  Test2
//
//  Created by Roger Ochoa on 10/3/24.
//
/*
import SwiftUI

struct PredictionGetView: View {
    
    
@StateObject private var predictionService = PredictionService()
@State private var predictionID: String = "7tghf7csddrm20cjeadbqxvz2g"
@State private var predictionsList: [PredictionResponse] = []
    
    
    

var body: some View {
    VStack {
        TextField("Enter Prediction ID", text: $predictionID)
            .padding()
            .textFieldStyle(RoundedBorderTextFieldStyle())

        Button("Fetch Prediction") {
            predictionService.fetchPrediction(id: predictionID)
        }
        .padding()
        
        if let errorMessage = predictionService.errorMessage {
            Text(errorMessage)
                .foregroundColor(.red)
                .padding()
        }
        
        if let prediction = predictionService.prediction {
            List {
                Text("ID: \(prediction.id)")
                Text("Model: \(prediction.model)")
                Text("Version: \(prediction.version)")
                Text("Status: \(prediction.status)")
                Text("Created At: \(prediction.created_at)")
                Text("Started At: \(prediction.started_at)")
                Text("Completed At: \(prediction.completed_at)")
                Text("Predict Time: \(prediction.metrics.predict_time)")
                
                // Handle input display
                Section(header: Text("Input")) {
                    
                }
                
                if let output = prediction.output?.first {
                    Text("Output: \(output)")
                }
            }
            .onAppear {
                predictionsList.append(prediction)
                saveToLocal(predictions: predictionsList)
            }
        }
    }
    .padding()
}

func saveToLocal(predictions: [PredictionResponse]) {
    do {
        let data = try JSONEncoder().encode(predictions)
        UserDefaults.standard.set(data, forKey: "predictions")
    } catch {
        print("Failed to save data: \(error)")
    }
}
}



struct PredictionGetView_Previews: PreviewProvider {
    static var previews: some View {
        PredictionGetView()
    }
}
*/

//
//  PayloadListView.swift
//  Lumeo
//
//  Created by Roger Ochoa on 10/9/24.
//

import SwiftUI
import Combine

struct PayloadListView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var apiService = APIServicePost()
    @Binding var colorModeValue: Bool
    @State private var timer: AnyCancellable? // Timer for polling the API

    var body: some View {
        NavigationView {
            List {
                ForEach(apiService.payloads, id: \.self) { payload in
                    VStack(alignment: .leading) {
                        Text("Payload:")
                            .font(.headline)
                        Text(payload)
                            .font(.body)
                            .foregroundColor(.gray)
                    }
                }
                .onDelete(perform: deletePayload)
            }
            .navigationTitle("Payloads")
            .navigationBarItems(trailing: EditButton())
        }
        .onAppear {
            // Load saved payloads when the view appears
            apiService.loadPayloads()
        }
    }

    private func deletePayload(at offsets: IndexSet) {
        offsets.forEach { index in
            apiService.deletePayload(at: index)
        }
    }
}

// Preview Provider for SwiftUI Preview
struct PayloadListView_Previews: PreviewProvider {
    @State static var colorModeValue: Bool = false // Provide a state variable for preview
    
    static var previews: some View {
        PredictionListView(colorModeValue: $colorModeValue)
            .preferredColorScheme(colorModeValue ? .dark : .light) // Set color scheme based on the binding
            
    }
}

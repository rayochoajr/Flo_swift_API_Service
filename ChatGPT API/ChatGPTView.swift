import SwiftUI

struct ChatGPTView: View {
    @State private var userInput: String = ""
    @State private var responseContent: String = "Loading..."
    @State private var isLoading: Bool = true
    
    var body: some View {
        VStack {
            Text("ChatGPT API Response")
                .font(.largeTitle)
                .padding()
            
            TextField("Enter your prompt here...", text: $userInput)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()
            
            Button(action: {
                fetchChatGPTResponse()
            }) {
                Text("Generate Prompt")
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .padding()
            
            Text(isLoading ? "Loading..." : responseContent)
                .padding()
                .multilineTextAlignment(.leading)
            
            Spacer()
        }
        .padding()
    }
    
    private func fetchChatGPTResponse() {
        let chatService = ChatGPTService()
        chatService.generatePrompt(userContent: userInput) { response in
            DispatchQueue.main.async {
                if let response = response {
                    self.responseContent = response.choices.first?.message.content ?? "No content received."
                } else {
                    self.responseContent = "Failed to retrieve response."
                }
                self.isLoading = false
            }
        }
    }
}

// Preview for the ChatGPTView
struct ChatGPTView_Previews: PreviewProvider {
    static var previews: some View {
        ChatGPTView()
            .previewLayout(.sizeThatFits)
    }
}

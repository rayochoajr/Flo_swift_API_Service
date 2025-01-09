import Foundation

enum Config {
    enum Error: Swift.Error {
        case missingKey, invalidValue
    }

    // MARK: - Keys
    enum Keys {
        static let chatGPTApiKey = "CHATGPT_API_KEY"
        static let replicateApiKey = "REPLICATE_API_KEY"
        static let comfyUIApiKey = "COMFYUI_API_KEY"
        static let awsAccessKey = "AWS_ACCESS_KEY"
        static let awsSecretKey = "AWS_SECRET_KEY"
        static let awsSessionToken = "AWS_SESSION_TOKEN"
        static let awsRegion = "AWS_REGION"
    }
    
    // MARK: - API Keys
    static func apiKey(_ key: String) throws -> String {
        guard let value = ProcessInfo.processInfo.environment[key] ?? UserDefaults.standard.string(forKey: key) else {
            throw Error.missingKey
        }
        return value
    }
    
    // MARK: - Endpoints
    static let chatGPTEndpoint = "https://api.openai.com/v1/chat/completions"
    static let replicateEndpoint = "https://api.replicate.com/v1/predictions"
    static let comfyUIEndpoint = "https://api.aws.amazon.com/v1/comfyui/predictions"
    
    // MARK: - Model Versions
    static let comfyUIModelVersion = "foggy/comfyui:latest"
    static let fooocusModelVersion = "foggy/fooocus:a747ba68d7fccb91fa1bbb6f11e5eb58017d81f5fa5bfd5e6d8e45d03a914c1c"
    
    // MARK: - AWS Configuration
    enum AWS {
        static let region = ProcessInfo.processInfo.environment[Keys.awsRegion] ?? "us-east-1"
        static let apiGatewayStage = "prod"
        static let s3Bucket = "comfyui-outputs"
        static let cloudFrontDomain = "https://d1234567890.cloudfront.net"
        static let stsEndpoint = "https://sts.amazonaws.com"
        static let credentialExpiration: TimeInterval = 3600 // 1 hour
        
        static var apiGatewayEndpoint: String {
            return "https://api.aws.amazon.com/\(apiGatewayStage)"
        }
        
        static var s3Endpoint: String {
            return "https://\(s3Bucket).s3.\(region).amazonaws.com"
        }
        
        struct Credentials {
            let accessKey: String
            let secretKey: String
            let sessionToken: String?
            let expiration: Date?
        }
    }
    
    // MARK: - ComfyUI Configuration
    enum ComfyUI {
        static let defaultWorkflow = """
        {
            "nodes": {
                "1": {
                    "id": "1",
                    "type": "CLIPTextEncode",
                    "inputs": {
                        "text": "",
                        "clip": "clip"
                    }
                },
                "2": {
                    "id": "2",
                    "type": "KSampler",
                    "inputs": {
                        "seed": 0,
                        "steps": 28,
                        "cfg": 7,
                        "sampler_name": "euler_ancestral",
                        "scheduler": "normal",
                        "denoise": 1,
                        "model": "model",
                        "positive": "pos",
                        "negative": "neg",
                        "latent_image": "latent"
                    }
                },
                "3": {
                    "id": "3",
                    "type": "VAEDecode",
                    "inputs": {
                        "samples": "samples",
                        "vae": "vae"
                    }
                }
            },
            "edges": [
                {
                    "source_node": "1",
                    "source_output": "CONDITIONING",
                    "target_node": "2",
                    "target_input": "positive"
                },
                {
                    "source_node": "2",
                    "source_output": "LATENT",
                    "target_node": "3",
                    "target_input": "samples"
                }
            ]
        }
        """
        
        static let defaultNodeId = "3"  // VAEDecode node
        
        enum ImageSize {
            static let square1K = "1024×1024"
            static let portrait = "832×1216"
            static let landscape = "1216×832"
        }
        
        enum OutputFormat {
            static let png = "png"
            static let jpeg = "jpeg"
            static let webp = "webp"
        }
        
        enum ExecutionMode {
            static let sequential = "sequential"
            static let parallel = "parallel"
        }
    }
    
    // MARK: - Setup
    static func setup() {
        // Load API keys from environment variables into UserDefaults
        if let chatGPTKey = ProcessInfo.processInfo.environment[Keys.chatGPTApiKey] {
            UserDefaults.standard.set(chatGPTKey, forKey: Keys.chatGPTApiKey)
        }
        
        if let replicateKey = ProcessInfo.processInfo.environment[Keys.replicateApiKey] {
            UserDefaults.standard.set(replicateKey, forKey: Keys.replicateApiKey)
        }
        
        if let comfyUIKey = ProcessInfo.processInfo.environment[Keys.comfyUIApiKey] {
            UserDefaults.standard.set(comfyUIKey, forKey: Keys.comfyUIApiKey)
        }
        
        if let awsAccessKey = ProcessInfo.processInfo.environment[Keys.awsAccessKey] {
            UserDefaults.standard.set(awsAccessKey, forKey: Keys.awsAccessKey)
        }
        
        if let awsSecretKey = ProcessInfo.processInfo.environment[Keys.awsSecretKey] {
            UserDefaults.standard.set(awsSecretKey, forKey: Keys.awsSecretKey)
        }
        
        if let awsSessionToken = ProcessInfo.processInfo.environment[Keys.awsSessionToken] {
            UserDefaults.standard.set(awsSessionToken, forKey: Keys.awsSessionToken)
        }
        
        if let awsRegion = ProcessInfo.processInfo.environment[Keys.awsRegion] {
            UserDefaults.standard.set(awsRegion, forKey: Keys.awsRegion)
        }
    }
    
    // MARK: - AWS Helpers
    static func getAWSCredentials() throws -> AWS.Credentials {
        let accessKey = try apiKey(Keys.awsAccessKey)
        let secretKey = try apiKey(Keys.awsSecretKey)
        let sessionToken = try? apiKey(Keys.awsSessionToken)
        
        return AWS.Credentials(
            accessKey: accessKey,
            secretKey: secretKey,
            sessionToken: sessionToken,
            expiration: nil
        )
    }
    
    static func getDefaultWorkflow() throws -> ComfyUIWorkflow {
        guard let workflowData = defaultWorkflow.data(using: .utf8),
              let workflow = try? JSONDecoder().decode(ComfyUIWorkflow.self, from: workflowData) else {
            throw Error.invalidValue
        }
        return workflow
    }
} 
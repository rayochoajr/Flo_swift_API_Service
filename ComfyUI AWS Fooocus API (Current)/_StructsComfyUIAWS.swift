import Foundation

// MARK: - JSON Value Handling
enum JSONValue: Codable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case array([JSONValue])
    case object([String: JSONValue])
    case null
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let number = try? container.decode(Double.self) {
            self = .number(number)
        } else if let bool = try? container.decode(Bool.self) {
            self = .bool(bool)
        } else if let array = try? container.decode([JSONValue].self) {
            self = .array(array)
        } else if let object = try? container.decode([String: JSONValue].self) {
            self = .object(object)
        } else if container.decodeNil() {
            self = .null
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid JSON value")
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value):
            try container.encode(value)
        case .number(let value):
            try container.encode(value)
        case .bool(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .object(let value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }
}

// MARK: - AWS Errors
enum AWSError: Error {
    case invalidCredentials
    case serviceUnavailable
    case rateLimitExceeded
    case invalidRegion
    case invalidWorkflow
    case invalidNodeId
    case invalidAPIKey
    case requestTimeout
    case internalServerError
    
    var localizedDescription: String {
        switch self {
        case .invalidCredentials:
            return "Invalid AWS credentials. Please check your access key and secret key."
        case .serviceUnavailable:
            return "AWS service is currently unavailable. Please try again later."
        case .rateLimitExceeded:
            return "API rate limit exceeded. Please wait before making more requests."
        case .invalidRegion:
            return "Invalid AWS region specified."
        case .invalidWorkflow:
            return "Invalid ComfyUI workflow configuration."
        case .invalidNodeId:
            return "Invalid node ID in workflow."
        case .invalidAPIKey:
            return "Invalid API key. Please check your AWS API Gateway key."
        case .requestTimeout:
            return "Request timed out. Please try again."
        case .internalServerError:
            return "Internal server error. Please try again later."
        }
    }
}

// MARK: - ComfyUI Workflow
struct ComfyUIWorkflow: Codable {
    let nodes: [String: Node]
    let edges: [Edge]
    
    struct Node: Codable {
        let id: String
        let type: String
        let inputs: [String: JSONValue]
        let outputs: [String: JSONValue]
        
        enum CodingKeys: String, CodingKey {
            case id, type, inputs, outputs
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(id, forKey: .id)
            try container.encode(type, forKey: .type)
            try container.encode(inputs, forKey: .inputs)
            try container.encode(outputs, forKey: .outputs)
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(String.self, forKey: .id)
            type = try container.decode(String.self, forKey: .type)
            inputs = try container.decode([String: JSONValue].self, forKey: .inputs)
            outputs = try container.decode([String: JSONValue].self, forKey: .outputs)
        }
    }
    
    struct Edge: Codable {
        let sourceNode: String
        let sourceOutput: String
        let targetNode: String
        let targetInput: String
        
        enum CodingKeys: String, CodingKey {
            case sourceNode = "source_node"
            case sourceOutput = "source_output"
            case targetNode = "target_node"
            case targetInput = "target_input"
        }
    }
}

// MARK: - PredictionRequest
struct ComfyUIRequest: Codable {
    let version: String
    let input: InputData

    struct InputData: Codable {
        // Standard fields
        let prompt: String
        let hf_lora: String
        let lora_scale: Double
        let num_outputs: Int
        let aspect_ratio: String
        let output_format: String
        let guidance_scale: Double
        let output_quality: Int
        let prompt_strength: Double
        let num_inference_steps: Int
        
        // ComfyUI specific fields
        let workflow: ComfyUIWorkflow?
        let node_id: String?
        let custom_workflow_data: [String: String]?
        let execution_mode: String?  // "sequential" or "parallel"
        let priority: Int?
        let webhook_url: String?
        
        enum CodingKeys: String, CodingKey {
            case prompt, hf_lora, lora_scale, num_outputs
            case aspect_ratio, output_format, guidance_scale
            case output_quality, prompt_strength, num_inference_steps
            case workflow, node_id
            case custom_workflow_data = "workflow_data"
            case execution_mode, priority, webhook_url
        }
    }
}

// MARK: - Prediction
struct ComfyUIPrediction: Codable, Identifiable {
    let id: String                  // Unique identifier for the prediction
    let requestId: String?          // requestId to link with request
    let model: String
    let version: String
    let input: Input
    let logs: String
    let output: [String]?           // Optional array to store multiple outputs
    let dataRemoved: Bool
    let error: String?              // Optional error message
    let status: String
    let createdAt: String           // ISO8601 formatted date
    let urls: URLs
    let progress: Progress?         // ComfyUI specific progress tracking
    let nodeExecutions: [NodeExecution]? // ComfyUI specific node execution tracking

    struct Input: Codable {
        let aspectRatio: String
        let guidanceScale: Double
        let hfLora: String
        let loraScale: Double
        let numInferenceSteps: Int
        let numOutputs: Int
        let outputFormat: String
        let outputQuality: Int
        let prompt: String
        let promptStrength: Double
        let workflow: ComfyUIWorkflow?
        let nodeId: String?

        enum CodingKeys: String, CodingKey {
            case aspectRatio = "aspect_ratio"
            case guidanceScale = "guidance_scale"
            case hfLora = "hf_lora"
            case loraScale = "lora_scale"
            case numInferenceSteps = "num_inference_steps"
            case numOutputs = "num_outputs"
            case outputFormat = "output_format"
            case outputQuality = "output_quality"
            case prompt
            case promptStrength = "prompt_strength"
            case workflow
            case nodeId = "node_id"
        }
    }

    struct URLs: Codable {
        let get: String
        let cancel: String
        let webhook: String?
    }
    
    struct Progress: Codable {
        let percentage: Double
        let currentNode: String?
        let estimatedTimeRemaining: Double?
        
        enum CodingKeys: String, CodingKey {
            case percentage
            case currentNode = "current_node"
            case estimatedTimeRemaining = "estimated_time_remaining"
        }
    }
    
    struct NodeExecution: Codable {
        let nodeId: String
        let status: String
        let startTime: String
        let endTime: String?
        let error: String?
        
        enum CodingKeys: String, CodingKey {
            case nodeId = "node_id"
            case status
            case startTime = "start_time"
            case endTime = "end_time"
            case error
        }
    }

    enum CodingKeys: String, CodingKey {
        case id, model, version, input, logs, output
        case requestId = "request_id"
        case dataRemoved = "data_removed"
        case error, status
        case createdAt = "created_at"
        case urls
        case progress
        case nodeExecutions = "node_executions"
    }
}

// MARK: - Extensions
extension Dictionary {
    var jsonString: String {
        if let data = try? JSONSerialization.data(withJSONObject: self),
           let string = String(data: data, encoding: .utf8) {
            return string
        }
        return "{}"
    }
}

extension String {
    var jsonDictionary: [String: Any] {
        if let data = self.data(using: .utf8),
           let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            return dict
        }
        return [:]
    }
} 
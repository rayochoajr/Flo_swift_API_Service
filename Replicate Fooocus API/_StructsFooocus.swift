import Foundation

// MARK: - FooocusRequest
struct FooocusRequest: Codable {
    let version: String
    let input: InputData
    
    struct InputData: Codable {
        let prompt: String
        let negative_prompt: String?
        let style_selections: [String]?
        let performance_selection: String?
        let aspect_ratios_selection: String?
        let image_number: Int?
        let image_seed: Int?
        let sharpness: Double?
        let guidance_scale: Double?
        let base_model_name: String?
        let refiner_model_name: String?
        let loras: [[String: String]]?
        let advanced_params: AdvancedParams?
        
        // Match existing Replicate structure for compatibility
        let hf_lora: String?
        let lora_scale: Double?
        let num_outputs: Int?
        let aspect_ratio: String?
        let output_format: String?
        let output_quality: Int?
        let prompt_strength: Double?
        let num_inference_steps: Int?
        
        struct AdvancedParams: Codable {
            let adaptive_cfg: Double?
            let adm_guidance: Double?
            let cfg_scale: Double?
            let controlnet_model: String?
            let controlnet_preprocess: Bool?
            let controlnet_strength: Double?
            let disable_preview: Bool?
            let freeu_b1: Double?
            let freeu_b2: Double?
            let freeu_s1: Double?
            let freeu_s2: Double?
            let initial_latent: String?
            let keep_input_names: Bool?
            let lcm_accelerate: Bool?
            let outpaint_selections: [String]?
            let overwrite_step: Int?
            let overwrite_switch: Int?
            let positive_prompt_strength: Double?
            let refiner_switch: Double?
            let sampler: String?
            let scheduler: String?
            let steps: Int?
        }
    }
}

// MARK: - FooocusPrediction
struct FooocusPrediction: Codable, Identifiable {
    let id: String
    let requestId: String?
    let model: String
    let version: String
    let input: Input
    let logs: String?
    let output: [String]?
    let error: String?
    let status: String
    let createdAt: String
    let startedAt: String?
    let completedAt: String?
    let urls: URLs
    let metrics: Metrics?
    let dataRemoved: Bool
    
    struct Input: Codable {
        let prompt: String
        let negativePrompt: String?
        let styleSelections: [String]?
        let performanceSelection: String?
        let aspectRatiosSelection: String?
        let imageNumber: Int?
        let imageSeed: Int?
        let sharpness: Double?
        let guidanceScale: Double?
        let baseModelName: String?
        let refinerModelName: String?
        let loras: [[String: String]]?
        let advancedParams: AdvancedParams?
        
        // Match existing Replicate structure for compatibility
        let aspectRatio: String?
        let hfLora: String?
        let loraScale: Double?
        let numOutputs: Int?
        let outputFormat: String?
        let outputQuality: Int?
        let promptStrength: Double?
        let numInferenceSteps: Int?
        
        struct AdvancedParams: Codable {
            let adaptiveCfg: Double?
            let admGuidance: Double?
            let cfgScale: Double?
            let controlnetModel: String?
            let controlnetPreprocess: Bool?
            let controlnetStrength: Double?
            let disablePreview: Bool?
            let freeuB1: Double?
            let freeuB2: Double?
            let freeuS1: Double?
            let freeuS2: Double?
            let initialLatent: String?
            let keepInputNames: Bool?
            let lcmAccelerate: Bool?
            let outpaintSelections: [String]?
            let overwriteStep: Int?
            let overwriteSwitch: Int?
            let positivePromptStrength: Double?
            let refinerSwitch: Double?
            let sampler: String?
            let scheduler: String?
            let steps: Int?
        }
        
        enum CodingKeys: String, CodingKey {
            case prompt
            case negativePrompt = "negative_prompt"
            case styleSelections = "style_selections"
            case performanceSelection = "performance_selection"
            case aspectRatiosSelection = "aspect_ratios_selection"
            case imageNumber = "image_number"
            case imageSeed = "image_seed"
            case sharpness
            case guidanceScale = "guidance_scale"
            case baseModelName = "base_model_name"
            case refinerModelName = "refiner_model_name"
            case loras
            case advancedParams = "advanced_params"
            // Compatibility keys
            case aspectRatio = "aspect_ratio"
            case hfLora = "hf_lora"
            case loraScale = "lora_scale"
            case numOutputs = "num_outputs"
            case outputFormat = "output_format"
            case outputQuality = "output_quality"
            case promptStrength = "prompt_strength"
            case numInferenceSteps = "num_inference_steps"
        }
    }
    
    struct URLs: Codable {
        let get: String
        let cancel: String
    }
    
    struct Metrics: Codable {
        let predictTime: Double?
        let totalTime: Double?
        
        enum CodingKeys: String, CodingKey {
            case predictTime = "predict_time"
            case totalTime = "total_time"
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case id, model, version, input, logs, output, error, status
        case requestId = "request_id"
        case createdAt = "created_at"
        case startedAt = "started_at"
        case completedAt = "completed_at"
        case urls, metrics
        case dataRemoved = "data_removed"
    }
} 
# Replicate API Service

## Architecture Overview
Swift implementation of Replicate's prediction API with reactive programming paradigms.

### Core Components
- **ReplicateService**: Thread-safe ObservableObject implementation
- **Request Pipeline**: Operation queue with retry support
- **Response Handling**: Combine-based reactive streams
- **State Management**: Published property wrappers

## Technical Specifications

### Performance Metrics
- Max Concurrent Requests: 3
- Request Timeout: 30s
- Max Retries: 3
- Retry Backoff: Exponential (base: 1.0s)
- Memory Footprint: O(n) where n = active predictions

### Data Flow
```
Input → Queue → Request → Poll → Output
↑                   ↓
└───────[Retry]─────┘
```

### Request Parameters
| Parameter | Type | Default | Range |
|-----------|------|---------|--------|
| prompt | String | Required | 1-500 chars |
| negative_prompt | String? | nil | Optional |
| num_outputs | Int | 1 | 1-4 |
| aspect_ratio | String | "1024×1024" | Fixed |
| guidance_scale | Double | 7.0 | 1.0-20.0 |
| num_inference_steps | Int | 28 | 1-100 |

## Error Handling Matrix
| Error Type | HTTP Code | Retry? | Backoff |
|------------|-----------|--------|---------|
| InvalidURL | - | No | - |
| Unauthorized | 401 | No | - |
| Forbidden | 403 | No | - |
| RateLimit | 429 | Yes | Exp |
| ServerError | 5xx | Yes | Exp |
| Timeout | - | Yes | Linear |
| NetworkError | - | Yes | Exp |
| DecodingError | - | No | - |

## Implementation Details

### Data Models
```swift
// Prediction Response
struct PredictionResponse: Codable, Identifiable {
    let id: String
    let model: String
    let version: String
    let input: [String: CodableValue]?
    let logs: String?
    let output: [String]?
    let data_removed: Bool
    let error: String?
    let status: String
    let created_at: String
    let started_at: String
    let completed_at: String
    let urls: URLS
    let metrics: Metrics
}

// URL Structure
struct URLS: Codable {
    let cancel: String
    let get: String
}

// Metrics Structure
struct Metrics: Codable {
    let predict_time: Double
    let total_time: Double?
}

// Mixed-Type JSON Handler
struct CodableValue: Codable {
    let value: Any  // Handles Int, Double, String
}
```

### Status Polling
- Interval: 2 seconds
- Auto-cancellation on completion
- Progress tracking via metrics
- Status transitions: starting → processing → succeeded/failed

### Status Flow
```
Check Status → Parse Response → Update Progress → Handle Completion
     ↑              ↓               ↓                ↓
     └──────[2s]────┴───[Metrics]───┴───[Cleanup]───┘
```

### Reactive Pipeline
```swift
URLSession.dataTaskPublisher
    → tryMap(validateResponse)
    → decode(Prediction.self)
    → receive(on: DispatchQueue.main)
    → sink(handleResponse)
```

### Memory Management
- Automatic cancellable cleanup
- Weak self references in closures
- Explicit cancellation support

### Thread Safety
- Main thread: UI updates
- Background thread: Network operations
- Operation queue: Request management

## Usage Example

```swift
let service = ReplicateService()

service.generateImage(
    prompt: "cyberpunk city",
    negativePrompt: "blurry, low quality"
) { result in
    switch result {
    case .success(let prediction):
        // Handle generated image
    case .failure(let error):
        // Handle error
    }
}
```

## API Version Compatibility
- Model Version: a747ba68d7
- API Version: v1
- Swift Version: 5.5+
- iOS Version: 13.0+

## Performance Optimization

### Request Optimization
- JSON encoder/decoder reuse
- Operation queue management
- Automatic retry handling

### Memory Optimization
- Response caching
- Automatic cleanup
- Weak references

## Monitoring & Debugging

### Observable States
- `isProcessing`: Active request status
- `currentProgress`: Generation progress
- `predictionResponses`: Response cache
- `payloads`: Request history

### Debug Points
- Network requests
- Queue operations
- State transitions
- Error propagation

## Error Recovery Strategy

### Retry Logic
1. Network errors: 3 attempts
2. Rate limits: Exponential backoff
3. Server errors: Exponential backoff
4. Timeout: Linear backoff

## Integration Notes

### Dependencies
- Foundation
- Combine
- URLSession
- OperationQueue

### Thread Model
- Main thread: UI updates
- Background: Network operations
- Operation queue: Request management

## Limitations & Constraints

### Resource Limits
- Max prompt length: 500 chars
- Max image size: 1024×1024
- Max batch size: 4 images
- Max timeout: 30 seconds
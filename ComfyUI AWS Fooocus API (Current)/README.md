# ComfyUI AWS Fooocus API Service

## Architecture Overview
Enterprise-grade Swift implementation of ComfyUI's prediction API with AWS integration and workflow management.

### Core Components
- **ComfyUIAWSService**: Thread-safe ObservableObject with AWS integration
- **Workflow Engine**: DAG-based node execution system
- **Request Pipeline**: AWS-optimized operation queue with STS support
- **Response Handling**: Reactive streams with CloudWatch integration
- **State Management**: Published property wrappers with DynamoDB sync

## Technical Specifications

### Performance Metrics
- Max Concurrent Requests: 3
- Request Timeout: 30s
- Max Retries: 3
- Retry Backoff: Exponential (base: 1.0s)
- Memory Footprint: O(n + w) where n = active predictions, w = workflow nodes

### Data Flow
```
Input → Queue → AWS Gateway → Lambda → ComfyUI → S3
  ↑          ↓        ↓         ↓        ↓
  └──[Retry]─┴─[CloudWatch]─[DynamoDB]─[SNS]→
```

### Workflow Parameters
| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| nodes | [String: Node] | Required | DAG nodes |
| edges | [Edge] | Required | Node connections |
| node_id | String | "3" | Output node |
| execution_mode | String | "sequential" | "sequential"/"parallel" |
| priority | Int | 1 | 1-10 |

### Node Types
| Type | Input | Output | Description |
|------|--------|--------|-------------|
| CLIPTextEncode | text, clip | CONDITIONING | Text encoding |
| KSampler | seed, steps, cfg, etc. | LATENT | Image sampling |
| VAEDecode | samples, vae | IMAGE | Image decoding |

## Error Handling Matrix
| Error Type | AWS Code | Retry? | Backoff |
|------------|----------|--------|---------|
| InvalidCredentials | 401 | No | - |
| InvalidAPIKey | 403 | No | - |
| RateLimit | 429 | Yes | Exp |
| InvalidRegion | - | No | - |
| InvalidWorkflow | 400 | No | - |
| ServiceUnavailable | 503 | Yes | Exp |

## Implementation Details

### AWS Integration Pipeline
```swift
AWSCredentials → STS → Gateway → Lambda
    → ComfyUI → S3 → CloudFront → Client
```

### Memory Management
- Automatic cancellable cleanup
- AWS resource cleanup
- S3 object lifecycle
- DynamoDB TTL

### Thread Safety
- Main thread: UI updates
- Background thread: AWS operations
- Custom queue: Workflow processing
- Serial queue: State mutations

## Usage Example

```swift
let service = ComfyUIAWSService()

service.generateImage(
    prompt: "cyberpunk city",
    workflow: Config.ComfyUI.defaultWorkflow,
    nodeId: "3",
    executionMode: "sequential"
) { result in
    switch result {
    case .success(let prediction):
        // Handle generated image
    case .failure(let error):
        // Handle AWS error
    }
}
```

## AWS Service Integration

### Required Services
- API Gateway
- Lambda
- S3
- CloudFront
- DynamoDB
- CloudWatch
- SNS
- STS

### IAM Permissions
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "execute-api:Invoke",
                "s3:PutObject",
                "dynamodb:PutItem",
                "sns:Publish"
            ],
            "Resource": "*"
        }
    ]
}
```

## Performance Optimization

### AWS Optimization
- CloudFront caching
- S3 transfer acceleration
- DynamoDB DAX
- Lambda provisioned concurrency

### Memory Optimization
- Response caching
- Workflow caching
- Resource pooling
- Weak references

## Monitoring & Debugging

### CloudWatch Metrics
- Request latency
- Error rates
- Node execution time
- Resource utilization

### Observable States
- `isProcessing`: Active request status
- `currentProgress`: Generation progress
- `nodeExecutions`: Node status
- `predictionResponses`: Response cache

## Security Considerations

### AWS Security
- IAM roles
- KMS encryption
- VPC endpoints
- WAF integration

### Request Validation
- Input sanitization
- Workflow validation
- Node validation
- Token validation

## Error Recovery Strategy

### Retry Logic
1. Network errors: 3 attempts
2. Rate limits: Exponential backoff
3. AWS errors: Service-specific
4. Workflow errors: Node-specific

### State Recovery
1. DynamoDB persistence
2. S3 state backup
3. Node state recovery
4. Progress restoration

## Integration Notes

### Dependencies
- Foundation
- Combine
- AWSCore
- AWSS3
- AWSLambda
- AWSDynamoDB

### Thread Model
- Main thread: UI updates
- Background: AWS operations
- Custom queue: Workflow processing
- Lambda: Node execution

## Limitations & Constraints

### AWS Limits
- Lambda timeout: 15 minutes
- S3 object size: 5GB
- API Gateway timeout: 30s
- DynamoDB item size: 400KB

### Resource Limits
- Max workflow nodes: 100
- Max concurrent executions: 3
- Max image size: 1024×1024
- Max batch size: 4 images 
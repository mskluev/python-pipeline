# Claim Check Pattern

This is the critical "handshake" that makes the entire decoupled, event-driven architecture work. It's how the Ingestion Pipeline (Producer) safely passes the "baton" to the Data Processing Pipeline (Consumer) without either system needing to know anything about the other's implementation details. The payload must be strictly serialized JSON. It must contain unique identifiers, tracing capability, and a robust "history of pointers" as data moves through transformations.

## Schema

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://datafabric.internal/schema/claim-check-payload.json",
  "title": "Continuous Data Fabric Claim Check Payload",
  "description": "The standardized 'Metadata Ticket' payload that moves between components (SQS/SNS) in a choreographed AI/ML pipeline. Raw data is excluded per standard 256KB limits.",
  "type": "object",
  "additionalProperties": true,
  "required": [
    "recordId",
    "schemaVersion",
    "pipelineId",
    "traceId",
    "executionContext",
    "claims"
  ],
  "properties": {
    "recordId": {
      "description": "REQUIRED. Unique UUID (v4) for this specific data record as it traverses the fabric. Maps directly to 'RECORD ID' in the audit dashboard (image_3.png).",
      "type": "string",
      "format": "uuid"
    },
    "schemaVersion": {
      "description": "REQUIRED. Version of this specific JSON schema (e.g., '1.0.0'). Essential for evolutionary compatibility.",
      "type": "string",
      "pattern": "^\\d+\\.\\d+\\.\\d+$"
    },
    "pipelineId": {
      "description": "REQUIRED. UUID identifying the business user's logical pipeline configuration.",
      "type": "string",
      "format": "uuid"
    },
    "traceId": {
      "description": "REQUIRED. A unique UUID/Trace ID generated at ingestion that persists through all steps. Used by X-Ray for global distributed tracing. Maps to 'UNIQUE TRACE ID' in image_3.png.",
      "type": "string"
    },
    "correlationId": {
      "description": "OPTIONAL. Links related requests or asynchronous events (e.g., the specific ID of the SageMaker async job call).",
      "type": "string"
    },
    "timestampInGmt": {
      "description": "OPTIONAL. ISO 8601 timestamp in GMT when the event was emitted.",
      "type": "string",
      "format": "date-time"
    },
    "executionContext": {
      "description": "REQUIRED. Context about the current/completed step of execution.",
      "type": "object",
      "required": [
        "stepId",
        "actionName",
        "status"
      ],
      "properties": {
        "stepId": {
          "description": "UUID of the specific visual node (e.g., 'OCR Text Extract') within the user's pipeline definition. Maps to 'STEP' in image_3.png.",
          "type": "string"
        },
        "actionName": {
          "description": "The user-facing label or underlying skill ID executed. Maps to 'ACTION' in image_3.png (e.g., 'Normalize Format').",
          "type": "string"
        },
        "status": {
          "description": "The outcome of the *completed* step. Normally 'Success'. If the message is in a DLQ, this is likely 'Error'. Maps to 'STATUS' in image_3.png.",
          "type": "string",
          "enum": [
            "Success",
            "Error",
            "Retrying",
            "Awaiting_Callback"
          ]
        },
        "originComponent": {
          "description": "OPTIONAL. The specific Lambda Function ARN or Fargate Task ARN that emitted this message.",
          "type": "string"
        }
      }
    },
    "metadata": {
      "description": "OPTIONAL. Generic key-value map for low-cardinality flags, customer IDs, or session context used for branching. (Total payload must remain <256KB).",
      "type": "object",
      "additionalProperties": {
        "type": "string"
      }
    },
    "claims": {
      "description": "REQUIRED. A cumulative array of claim checks (pointers). Pointers are added to this list sequentially as the data is transformed. The last item is generally the 'active' pointer.",
      "type": "array",
      "minItems": 1,
      "items": {
        "type": "object",
        "required": [
          "claimId",
          "contentType",
          "storageUri",
          "label"
        ],
        "properties": {
          "claimId": {
            "description": "Unique UUID for this specific content state.",
            "type": "string",
            "format": "uuid"
          },
          "label": {
            "description": "Human-readable semantic identifier for this data state (e.g., 'raw_stream', 'normalized_jpeg', 'ocr_text_json').",
            "type": "string"
          },
          "contentType": {
            "description": "The mime-type or specific data format (e.g., 'image/png', 'application/json'). Essential for generic skills to know how to process input.",
            "type": "string"
          },
          "storageUri": {
            "description": "The actual claim check pointer, usually an AWS S3 path (e.g., 's3://my-bucket/path/to/object.jpeg').",
            "type": "string",
            "format": "uri"
          },
          "timestamp": {
            "description": "ISO 8601 timestamp when this pointer was written to storage.",
            "type": "string",
            "format": "date-time"
          },
          "sizeInBytes": {
            "description": "Size of the actual data object referenced by the storageUri.",
            "type": "integer"
          }
        }
      }
    },
    "errorContext": {
      "description": "OPTIONAL. This block is added ONLY when the status in executionContext is 'Error' or when moving to a Dead Letter Queue. Essential for diagnosing image_3.png failures.",
      "type": "object",
      "required": [
        "code",
        "message"
          ],
      "properties": {
        "code": {
          "description": "Machine-readable error code (e.g., 'DLQ_LAMBDA_TIMEOUT', 'OCR_PARSING_ERROR').",
          "type": "string"
        },
        "message": {
          "description": "Human-readable detailed error message.",
          "type": "string"
        },
        "timestamp": {
          "description": "ISO 8601 timestamp when the error occurred.",
          "type": "string",
          "format": "date-time"
        }
      }
    }
  }
}
```

## Example Trace

Let's trace the movement of a single document through the fabric to visualize this pattern.

### 1. Ingestion Pipeline (Produce)

**Trigger:** A PDF arrives in the S3 "Incoming" bucket.

**Action:**
1. Lambda **Ingest_Trigger** validates the file.
2. It generates a `traceId`.
3. It uploads the raw PDF to S3 **Transient Storage**.
4. It publishes a message to the **Ingestion_Queue**.

**Payload (Ingestion_Queue):**
```json
{
  "recordId": "6f7b3b9f-5c3d-4a1e-9f0b-8e7d6c5b4a3d",
  "schemaVersion": "1.0.0",
  "pipelineId": "98a1f2d3-5c3d-4a1e-9f0b-8e7d6c5b4a3d", 
  "traceId": "a1b2c3d4-5c3d-4a1e-9f0b-8e7d6c5b4a3d", 
  "executionContext": {
    "stepId": "001",
    "actionName": "Original Upload",
    "status": "Success"
  },
  "claims": [
    {
      "claimId": "84a2e2c4-3f5d-4e1e-9f0b-8e7d6c5b4a3d",
      "label": "raw_pdf_input",
      "contentType": "application/pdf",
      "storageUri": "s3://pipeline-transient/input/doc_01.pdf", 
      "timestamp": "2024-01-15T10:00:00Z"
    }
  ]
}
```

### 2. Processing Pipeline (Consume)

**Trigger:** Lambda **SQS_Processor** receives the message.

**Action:**
1. It downloads the PDF from `s3://pipeline-transient/input/doc_01.pdf`.
2. It calls **AWS Textract** (OCR).
3. It receives raw JSON and cleans it up into structured JSON.
4. It uploads the Structured JSON to S3 **Transient Storage**.
5. It publishes a *new* message to the **Processing_Results_Queue**.

**Payload (Processing_Results_Queue):**
```json
{
  "recordId": "6f7b3b9f-5c3d-4a1e-9f0b-8e7d6c5b4a3d",
  "schemaVersion": "1.0.0",
  "pipelineId": "98a1f2d3-5c3d-4a1e-9f0b-8e7d6c5b4a3d",
  "traceId": "a1b2c3d4-5c3d-4a1e-9f0b-8e7d6c5b4a3d",
  "executionContext": {
    "stepId": "002",
    "actionName": "OCR Text Extract",
    "status": "Success"
  },
  "metadata": { 
    "source_type": "A4",
    "language": "en"
  },
  "claims": [
    {
      "claimId": "84a2e2c4-3f5d-4e1e-9f0b-8e7d6c5b4a3d",
      "label": "raw_pdf_input",
      "contentType": "application/pdf",
      "storageUri": "s3://pipeline-transient/input/doc_01.pdf",
      "timestamp": "2024-01-15T10:00:00Z"
    },
    {
      "claimId": "f0b9d2e1-4d5c-4a1e-9f0b-8e7d6c5b4a3d",
      "label": "ocr_structured_json",
      "contentType": "application/json",
      "storageUri": "s3://pipeline-transient/output/001/structured_ocr.json", 
      "timestamp": "2024-01-15T10:00:05Z"
    } 
  ]
}
```

### 3. Enrichment Pipeline (Consume)

**Trigger:** Lambda **SQS_Processor** receives the second message.

**Action:**
1. It downloads `structured_ocr.json`.
2. It makes an API call to a proprietary service to validate invoice numbers.
3. It updates the JSON with the validation result.
4. It uploads the enriched file to **Transient Storage**.
5. It publishes to **Enrichment_Results_Queue**.

**Payload (Enrichment_Results_Queue):**
```json
{
  "recordId": "6f7b3b9f-5c3d-4a1e-9f0b-8e7d6c5b4a3d",
  "schemaVersion": "1.0.0",
  "pipelineId": "98a1f2d3-5c3d-4a1e-9f0b-8e7d6c5b4a3d",
  "traceId": "a1b2c3d4-5c3d-4a1e-9f0b-8e7d6c5b4a3d",
  "executionContext": {
    "stepId": "003",
    "actionName": "Validate Invoice",
    "status": "Success"
  },
  "claims": [
    {
      "claimId": "84a2e2c4-3f5d-4e1e-9f0b-8e7d6c5b4a3d",
      "label": "raw_pdf_input",
      "contentType": "application/pdf",
      "storageUri": "s3://pipeline-transient/input/doc_01.pdf",
      "timestamp": "2024-01-15T10:00:00Z"
    },
    {
      "claimId": "f0b9d2e1-4d5c-4a1e-9f0b-8e7d6c5b4a3d",
      "label": "ocr_structured_json",
      "contentType": "application/json",
      "storageUri": "s3://pipeline-transient/output/001/structured_ocr.json",
      "timestamp": "2024-01-15T10:00:05Z"
    },
    {
      "claimId": "c9d8e7f6-5d4c-4a1e-9f0b-8e7d6c5b4a3d",
      "label": "ocr_with_validation",
      "contentType": "application/json",
      "storageUri": "s3://pipeline-transient/output/001/enriched_ocr.json",
      "timestamp": "2024-01-15T10:00:10Z"
    } 
  ]
}
```

### 4. Archival Pipeline (Final)

**Trigger:** Lambda **SQS_Processor** receives the final message.

**Action:**
1. It downloads `enriched_ocr.json`.
2. It copies the file to **Long-term Storage**.
3. It updates **DynamoDB** to mark the job as complete and updates the `status` column.
4. It triggers a notification.

**Payload (Enrichment_Results_Queue):**
```json
{
  "recordId": "6f7b3b9f-5c3d-4a1e-9f0b-8e7d6c5b4a3d",
  "schemaVersion": "1.0.0",
  "pipelineId": "98a1f2d3-5c3d-4a1e-9f0b-8e7d6c5b4a3d",
  "traceId": "a1b2c3d4-5c3d-4a1e-9f0b-8e7d6c5b4a3d",
  "executionContext": {
    "stepId": "004",
    "actionName": "Archive and Notify",
    "status": "Success"
  },
  "claims": [
    {
      "claimId": "84a2e2c4-3f5d-4e1e-9f0b-8e7d6c5b4a3d",
      "label": "raw_pdf_input",
      "contentType": "application/pdf",
      "storageUri": "s3://pipeline-transient/input/doc_01.pdf",
      "timestamp": "2024-01-15T10:00:00Z"
    },
    {
      "claimId": "f0b9d2e1-4d5c-4a1e-9f0b-8e7d6c5b4a3d",
      "label": "ocr_structured_json",
      "contentType": "application/json",
      "storageUri": "s3://pipeline-transient/output/001/structured_ocr.json",
      "timestamp": "2024-01-15T10:00:05Z"
    },
    {
      "claimId": "c9d8e7f6-5d4c-4a1e-9f0b-8e7d6c5b4a3d",
      "label": "ocr_with_validation",
      "contentType": "application/json",
      "storageUri": "s3://pipeline-transient/output/001/enriched_ocr.json",
      "timestamp": "2024-01-15T10:00:10Z"
    } 
  ]
}
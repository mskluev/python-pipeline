# Python Processing Pipeline Specification

## 1. Project Overview
This document outlines the architecture, directory structure, and deployment strategy for a production-grade serverless data processing pipeline. The pipeline leverages an event-driven architecture using AWS SNS, SQS, and Lambda to ingest, validate, process, and store data into an AWS Data Lakehouse.

## 2. Core Architecture
* **Event Flow:** SNS (Topic / Fan-out) -> SQS (Dead-Letter Queue configured) -> AWS Lambda (Data Processor) -> Data Lakehouse (S3 / Glue).
* **Infrastructure as Code (IaC):** Terraform / OpenTofu.
* **CI/CD Pipeline:** GitLab CI/CD for build, packaging, and infrastructure deployment.
* **Language:** Python 3.12.

## 3. Standardization & Core Libraries
To enforce production-grade observability and reduce boilerplate, the pipeline standardizes on two primary AWS-maintained libraries:

### 3.1 AWS Lambda Powertools for Python
Handles all Lambda execution environment standardization:
* **Structured Logging:** JSON-formatted logs with injected Lambda context (cold starts, request IDs).
* **Metrics:** Asynchronous custom business metrics using CloudWatch Embedded Metric Format (EMF).
* **Tracing:** Distributed tracing using AWS X-Ray (`@tracer.capture_lambda_handler`).
* **SQS Batch Processing:** Automated handling of partial batch failures. Successful messages are deleted, and only failed messages are returned to the queue.
* **Validation & Deserialization:** Deep integration with **Pydantic** for strict typing and payload validation before business logic execution.

### 3.2 AWS SDK for pandas (awswrangler)
Handles all Data Lakehouse interactions:
* **Standardized I/O:** Reading and writing heavily partitioned Parquet files directly to S3.
* **Glue Integration:** Automatic schema registration and partition updates within the AWS Glue Data Catalog.

*Important Note on Dependencies:* Both Powertools and AWS SDK for pandas **must be attached as AWS Lambda Layers** rather than packaged in the application deployment zip to maintain fast build times and small artifact sizes.

## 4. Monorepo Directory Structure
The repository strictly separates infrastructure, shared internal libraries, and deployable service code.

Code output
success

```text
.
├── infrastructure/               # Terraform / OpenTofu root
│   ├── environments/             # Environment states (dev, prod)
│   │   ├── dev/
│   │   │   ├── main.tf           
│   │   │   └── dev.tfvars
│   │   └── prod/
│   └── modules/                  # Reusable IaC patterns
│       ├── lakehouse_base/       
│       └── sns_sqs_lambda/       # Standardized fan-out module (DLQs, X-Ray, etc.)
│
├── libraries/                    # Shared internal Python code
│   └── infer_core/              
│       ├── pyproject.toml        
│       └── src/
│           └── infer_core/
│               ├── __init__.py
│               └── models.py     # Shared Pydantic models and schemas
│
└── services/                     # Deployable Lambda functions
    └── data_processor/           
        ├── src/
        │   └── handler.py        # Contains @logger, @metrics, and BatchProcessor logic
        ├── requirements.txt      # Includes local references (e.g., -e ../../libraries/infer_core)
        └── tests/
```

## 5. Build and Deployment Strategy
Deployment is decoupled from the build process to optimize the Terraform execution and correctly resolve local Python library paths.

### 5.1 GitLab CI/CD Build Phase
1. Initialize a Python container (e.g., python:3.12-slim).
2. Navigate to the specific service directory (e.g., services/data_processor).
3. Run pip install -r requirements.txt --target ./package to bundle dependencies, including local shared packages (libraries/infer_core).
4. Copy src/* into ./package.
5. Create a .zip archive tagged with the Git commit SHA (e.g., data_processor-<commit_sha>.zip).
6. Upload the .zip artifact to an established S3 artifact bucket.

### 5.2 Infrastructure Deployment Phase
1. CI/CD triggers the Terraform / OpenTofu deployment.
2. Pass the Git commit SHA as a variable (e.g., terraform apply -var="commit_sha=<sha>").
3. The Terraform aws_lambda_function resource references the S3 bucket and the specific S3 key mapping to the newly uploaded artifact.
4. Terraform updates the Lambda function code seamlessly without handling the local python build process.

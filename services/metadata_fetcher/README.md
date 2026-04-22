# Metadata Fetcher Service

The `metadata_fetcher` is an AWS Lambda service that acts as an SQS consumer to orchestrate the retrieval of document metadata from an external HTTP API and pass the results down the pipeline via SNS.

## Features

- **SQS Batch Processing**: Utilizes `aws_lambda_powertools` to handle batch processing and partial failures gracefully.
- **mTLS Authentication**: Connects to the external metadata API using mutual TLS (mTLS). Certificates are securely loaded from AWS Secrets Manager on cold start and cached in ephemeral storage (`/tmp/`).
- **ClaimCheck Pattern**: Produces standard `ClaimCheck` JSON payloads for each processed document, enabling decoupled downstream processing in the data fabric.

## Architecture

1. **Trigger**: An SQS queue triggers the Lambda with a `WorkflowRequest` payload.
2. **Batching**: The service splits the requested `documentIds` into smaller batches.
3. **External Call**: For each batch, it makes a `POST` request to the external Metadata API.
4. **Publishing**: It constructs a valid `ClaimCheck` object for each document and publishes it to an SNS topic.

## Environment Variables

The Lambda function requires the following environment variables:

| Variable | Description | Default |
|----------|-------------|---------|
| `BATCH_SIZE` | Number of document IDs to process in a single external API request. | `10` |
| `METADATA_API_URL` | The HTTPS endpoint of the external metadata service. | (Required) |
| `SNS_TOPIC_ARN` | The ARN of the SNS topic to publish the `ClaimCheck` payloads to. | (Required) |
| `PIPELINE_ID` | A static UUID representing this logical pipeline configuration. | `00000000...` |
| `SECRET_CA_KEY` | The AWS Secrets Manager Secret ID containing the CA certificate. | (Required) |
| `SECRET_CERT_KEY` | The AWS Secrets Manager Secret ID containing the Client certificate. | (Required) |
| `SECRET_KEY_KEY` | The AWS Secrets Manager Secret ID containing the Private Key. | (Required) |

## Required AWS Permissions

Ensure the Lambda execution role has the following IAM permissions:
- `secretsmanager:GetSecretValue` for the specified secret ARNs.
- `sns:Publish` for the `SNS_TOPIC_ARN`.
- Standard AWS Lambda basic execution roles (CloudWatch logs) and SQS read/delete permissions.

## Local Development

To run or test this locally, you must install the local shared library `infer_core`:

```bash
pip install -r requirements.txt
```

*Note: The `infer_core` dependency requires Python 3.12+.*

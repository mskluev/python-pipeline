import json
import os
from datetime import datetime, timezone
from uuid import UUID

import boto3
import requests
from aws_lambda_powertools import Logger, Metrics, Tracer
from aws_lambda_powertools.utilities.batch import BatchProcessor, EventType, process_partial_response
from aws_lambda_powertools.utilities.data_classes.sqs_event import SQSRecord

from infer_core.models import (
    Claim,
    ClaimCheck,
    ExecutionContext,
    ExecutionStatus,
    WorkflowRequest,
)

logger = Logger()
tracer = Tracer()
metrics = Metrics()
processor = BatchProcessor(event_type=EventType.SQS)

sns_client = boto3.client("sns")
secrets_client = boto3.client("secretsmanager")

# Environment variables
BATCH_SIZE = int(os.environ.get("BATCH_SIZE", "10"))
METADATA_API_URL = os.environ.get("METADATA_API_URL")
SNS_TOPIC_ARN = os.environ.get("SNS_TOPIC_ARN")
PIPELINE_ID = os.environ.get("PIPELINE_ID", "00000000-0000-0000-0000-000000000000")

SECRET_CA_KEY = os.environ.get("SECRET_CA_KEY")
SECRET_CERT_KEY = os.environ.get("SECRET_CERT_KEY")
SECRET_KEY_KEY = os.environ.get("SECRET_KEY_KEY")

# Ephemeral storage for certs
CA_PATH = "/tmp/ca.crt"
CERT_PATH = "/tmp/client.crt"
KEY_PATH = "/tmp/client.key"


def _fetch_secret_to_file(secret_id: str, file_path: str):
    if not secret_id:
        logger.warning(f"No secret ID provided for {file_path}")
        return
    if os.path.exists(file_path):
        return
    
    logger.info(f"Fetching secret {secret_id}")
    response = secrets_client.get_secret_value(SecretId=secret_id)
    secret_string = response.get("SecretString")
    
    with open(file_path, "w") as f:
        f.write(secret_string)


def _ensure_certs_loaded():
    _fetch_secret_to_file(SECRET_CA_KEY, CA_PATH)
    _fetch_secret_to_file(SECRET_CERT_KEY, CERT_PATH)
    _fetch_secret_to_file(SECRET_KEY_KEY, KEY_PATH)


def record_handler(record: SQSRecord):
    _ensure_certs_loaded()
    
    payload: str = record.body
    if not payload:
        logger.warning("Empty payload received.")
        return

    # Parse request
    workflow_request = WorkflowRequest.model_validate_json(payload)
    document_ids = workflow_request.documentIds
    workflow_id_str = str(workflow_request.workflowId)
    
    logger.info(f"Processing WorkflowRequest {workflow_id_str} with {len(document_ids)} documents.")
    
    for i in range(0, len(document_ids), BATCH_SIZE):
        batch = document_ids[i:i + BATCH_SIZE]
        
        # Call external metadata API
        response = requests.post(
            METADATA_API_URL,
            json={"documentIds": batch},
            cert=(CERT_PATH, KEY_PATH),
            verify=CA_PATH,
            timeout=30
        )
        response.raise_for_status()
        
        # We successfully fetched metadata for the batch.
        # Now create and publish a ClaimCheck for each document in the batch.
        for doc_id in batch:
            doc_uuid = UUID(doc_id)
            
            # The spec specifies claims must have minItems: 1
            # We add a dummy/initial claim here to represent the fetched metadata state.
            initial_claim = Claim(
                claimId=doc_uuid,
                label="metadata_fetched",
                contentType="application/json",
                storageUri=f"metadata://{doc_id}",
                timestamp=datetime.now(timezone.utc)
            )
            
            claim_check = ClaimCheck(
                recordId=doc_uuid,
                schemaVersion="1.0.0",
                pipelineId=UUID(PIPELINE_ID),
                traceId=workflow_id_str,
                executionContext=ExecutionContext(
                    stepId="metadata_fetch",
                    actionName="Fetch Metadata",
                    status=ExecutionStatus.SUCCESS
                ),
                claims=[initial_claim]
            )
            
            sns_client.publish(
                TopicArn=SNS_TOPIC_ARN,
                Message=claim_check.model_dump_json(by_alias=True)
            )

@logger.inject_lambda_context
@tracer.capture_lambda_handler
@metrics.log_metrics(capture_cold_start_metric=True)
def lambda_handler(event, context):
    return process_partial_response(
        event=event,
        record_handler=record_handler,
        processor=processor,
        context=context,
    )

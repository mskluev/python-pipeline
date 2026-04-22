from datetime import datetime
from enum import Enum
from typing import Dict, List, Optional
from uuid import UUID

from pydantic import BaseModel, Field

# ClaimCheck Payload Models

class ExecutionStatus(str, Enum):
    SUCCESS = "Success"
    ERROR = "Error"
    RETRYING = "Retrying"
    AWAITING_CALLBACK = "Awaiting_Callback"


class ExecutionContext(BaseModel):
    stepId: str = Field(description="UUID of the specific visual node within the user's pipeline definition.")
    actionName: str = Field(description="The user-facing label or underlying skill ID executed.")
    status: ExecutionStatus = Field(description="The outcome of the completed step.")
    originComponent: Optional[str] = Field(default=None, description="The specific Lambda Function ARN or Fargate Task ARN that emitted this message.")


class Claim(BaseModel):
    claimId: UUID = Field(description="Unique UUID for this specific content state.")
    label: str = Field(description="Human-readable semantic identifier for this data state.")
    contentType: str = Field(description="The mime-type or specific data format.")
    storageUri: str = Field(description="The actual claim check pointer, usually an AWS S3 path.")
    timestamp: Optional[datetime] = Field(default=None, description="ISO 8601 timestamp when this pointer was written to storage.")
    sizeInBytes: Optional[int] = Field(default=None, description="Size of the actual data object referenced by the storageUri.")


class ErrorContext(BaseModel):
    code: str = Field(description="Machine-readable error code.")
    message: str = Field(description="Human-readable detailed error message.")
    timestamp: Optional[datetime] = Field(default=None, description="ISO 8601 timestamp when the error occurred.")


class ClaimCheck(BaseModel):
    recordId: UUID = Field(description="Unique UUID (v4) for this specific data record as it traverses the fabric.")
    schemaVersion: str = Field(pattern=r"^\d+\.\d+\.\d+$", description="Version of this specific JSON schema.")
    pipelineId: UUID = Field(description="UUID identifying the business user's logical pipeline configuration.")
    traceId: str = Field(description="A unique UUID/Trace ID generated at ingestion that persists through all steps.")
    correlationId: Optional[str] = Field(default=None, description="Links related requests or asynchronous events.")
    timestampInGmt: Optional[datetime] = Field(default=None, description="ISO 8601 timestamp in GMT when the event was emitted.")
    executionContext: ExecutionContext = Field(description="Context about the current/completed step of execution.")
    metadata: Optional[Dict[str, str]] = Field(default=None, description="Generic key-value map for low-cardinality flags, customer IDs, or session context used for branching.")
    claims: List[Claim] = Field(min_length=1, description="A cumulative array of claim checks (pointers).")
    errorContext: Optional[ErrorContext] = Field(default=None, description="This block is added ONLY when the status in executionContext is 'Error' or when moving to a Dead Letter Queue.")

# Request Models

class WorkflowRequest(BaseModel):
    workflowId: UUID = Field(description="Unique UUID for this specific request.")
    documentIds: List[str] = Field(description="List of document IDs to be processed.")
    
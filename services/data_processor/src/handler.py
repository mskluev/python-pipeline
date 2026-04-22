import json
from aws_lambda_powertools import Logger, Metrics, Tracer
from aws_lambda_powertools.utilities.batch import BatchProcessor, EventType, process_partial_response
from aws_lambda_powertools.utilities.data_classes.sqs_event import SQSRecord

logger = Logger()
tracer = Tracer()
metrics = Metrics()
processor = BatchProcessor(event_type=EventType.SQS)

def record_handler(record: SQSRecord):
    payload: str = record.body
    if payload:
        item = json.loads(payload)
        logger.info("Processed item", item=item)
        # Add business logic here

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

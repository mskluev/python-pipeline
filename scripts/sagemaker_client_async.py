import json
import time
import boto3
from botocore.exceptions import ClientError
from urllib.parse import urlparse

# --- Configuration ---
ENDPOINT_NAME = "mskluev-sagemaker-endpoint"
S3_BUCKET = "mskluev-test-146906276259"
S3_PREFIX = "sagemaker-async-output"

# Initialize boto3 clients
s3_client = boto3.client("s3")
sagemaker_runtime = boto3.client("sagemaker-runtime")

def upload_payload_to_s3(payload_dict, bucket, prefix):
    """Uploads the JSON payload to S3 and returns the S3 URI."""
    object_key = f"{prefix}/input/payload_{int(time.time())}.json"
    payload_bytes = json.dumps(payload_dict).encode("utf-8")
    
    print(f"Uploading input payload to s3://{bucket}/{object_key}...")
    s3_client.put_object(
        Bucket=bucket,
        Key=object_key,
        Body=payload_bytes,
        ContentType="application/json"
    )
    return f"s3://{bucket}/{object_key}"

def wait_for_async_output(output_s3_uri, timeout_seconds=300):
    """Polls the S3 output location until the file exists or timeout is reached."""
    parsed_url = urlparse(output_s3_uri)
    bucket = parsed_url.netloc
    key = parsed_url.path.lstrip("/")
    
    start_time = time.time()
    print(f"Polling for output at {output_s3_uri}...")
    
    while True:
        if time.time() - start_time > timeout_seconds:
            raise TimeoutError("Inference timed out while waiting for output in S3.")
            
        try:
            # Attempt to grab the object
            response = s3_client.get_object(Bucket=bucket, Key=key)
            result_data = response["Body"].read().decode("utf-8")
            return result_data
        except ClientError as e:
            if e.response["Error"]["Code"] == "NoSuchKey":
                # File isn't there yet, wait and try again
                time.sleep(2)
            else:
                # Some other permissions or network error occurred
                raise e

def main():
    # 1. Define actual application payload
    app_payload = {
        "sentences": [
            "This is the first sentence to be translated.",
            "Testing the SageMaker asynchronous invocation process."
        ],
        "sourceLanguage": "cmn",
        "targetLanguage": "eng"
    }

    # 2. Wrap the application payload in the Triton V2 HTTP Protocol
    # We serialize our app payload to a string, and pass it into the 'data' array.
    triton_payload = {
        "inputs": [
            {
                "name": "JSON_INPUT",
                "shape": [1, 1],
                "datatype": "BYTES",
                "data": [json.dumps(app_payload)]
            }
        ],
        "outputs": [
            {
                "name": "JSON_OUTPUT"
            }
        ]
    }

    # 3. Upload the *Triton-formatted* payload to S3
    input_s3_uri = upload_payload_to_s3(triton_payload, S3_BUCKET, S3_PREFIX)

    # 4. Invoke the Asynchronous Endpoint
    print(f"Invoking async endpoint: {ENDPOINT_NAME}")
    response = sagemaker_runtime.invoke_endpoint_async(
        EndpointName=ENDPOINT_NAME,
        InputLocation=input_s3_uri,
        ContentType="application/json"
    )
    
    output_s3_uri = response["OutputLocation"]
    print(f"Inference accepted. Output will be generated at: {output_s3_uri}")

    # 5. Wait for and parse the result
    try:
        raw_result = wait_for_async_output(output_s3_uri)
        
        # Parse the Triton V2 Envelope
        triton_response = json.loads(raw_result)
        
        # Extract the actual string from the Triton outputs array
        # outputs -> first output -> data array -> first element
        actual_output_str = triton_response["outputs"][0]["data"][0]
        
        # Parse our application's JSON from that string
        parsed_result = json.loads(actual_output_str)
        
        print("\n--- Inference Complete ---")
        print(json.dumps(parsed_result, indent=2))
        
    except TimeoutError as e:
        print(f"\nError: {e}")
    except KeyError as e:
        print(f"\nError parsing Triton response envelope: Missing key {e}")
        print(f"Raw response: {raw_result}")
    except Exception as e:
        print(f"\nAn unexpected error occurred: {e}")

if __name__ == "__main__":
    main()

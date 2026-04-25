# 1. SageMaker Role
# Usually we'd make a role first, but eVo-isms make that a pain.
# So we'll use a pre-existing one and include the ARN as a variable in `variables.tf`
# see `var.sagemaker_iam_role`


# 2. SageMaker Model
# This resource links your S3 model artifacts to the Triton Docker container.
resource "aws_sagemaker_model" "triton_model" {
  name               = "mskluev-sagemaker-model"
  execution_role_arn = var.sagemaker_iam_role

  primary_container {
    image          = var.triton_image_uri
    model_data_url = var.model_s3_path
  }

  # eVo requirements
  vpc_config {
    security_group_ids = var.security_group_ids
    subnets            = var.subnet_ids
  }
  enable_network_isolation = true

}

# 3. SageMaker Endpoint Configuration
# This defines the compute resources (instance type, count) for the endpoint.
resource "aws_sagemaker_endpoint_configuration" "triton_ep_config" {
  name = "mskluev-sagemaker-model-config"

  production_variants {
    variant_name           = "AllTraffic"
    model_name             = aws_sagemaker_model.triton_model.name
    initial_instance_count = 1
    instance_type          = var.sm_instance_type
    initial_variant_weight = 1.0
  }

  async_inference_config {
    output_config {
      s3_output_path = "s3://${var.working_bucket}/sagemaker-async-output/"
    }
    client_config {
      max_concurrent_invocations_per_instance = 4
    }
  }
}

# 4. SageMaker Endpoint
# This provisions the endpoint and makes it invokable.
resource "aws_sagemaker_endpoint" "triton_endpoint" {
  name                 = "mskluev-sagemaker-endpoint"
  endpoint_config_name = aws_sagemaker_endpoint_configuration.triton_ep_config.name
}

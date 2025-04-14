
locals {
  env = terraform.workspace

  lambda_roles = {
    uat = {
      process  = "arn:aws:iam::640280335206:role/project_lambda_dev_role"
      transfer = "arn:aws:iam::640280335206:role/project_lambda_dev_role"
    }
    prod = {
      process  = "arn:aws:iam::640280335206:role/project_lambda_dev_role"
      transfer = "arn:aws:iam::640280335206:role/project_lambda_dev_role"
    }
  }
  s3_buckets = {
    uat  = "uat-bucket-for-all"
    prod = "prod-bucket-for-all"
  }

  step_function_roles = {
    uat  = "arn:aws:iam::640280335206:role/ncd-step-function-role"
    prod = "arn:aws:iam::640280335206:role/ncd-step-function-role"
  }

  glue_roles = {
    uat  = "arn:aws:iam::640280335206:role/big-data-glue-role"
    prod = "arn:aws:iam::640280335206:role/ncodedata-all-access-glue-job-role"
  }

  glue_script_files = {
    uat  = "artifacts/uat/rds_transfer.py"
    prod = "artifacts/prod/prod_rds_transfer.py"
  }

  glue_script_keys = {
    uat  = "glue_scripts/rds_transfer.py"
    prod = "glue_scripts/prod_rds_transfer.py"
  }

  glue_configs = {
    uat = {
      name               = "rds_transfer"
      script_location    = "s3://uat-bucket-for-all/glue_scripts/rds_transfer.py"
      glue_version       = "5.0"
      max_capacity       = 2
      number_of_workers  = null
      worker_type        = null
      tags = {
        Environment = "uat"
        Component   = "migration"
      }
    }
    prod = {
      name               = "prod_rds_transfer"
      script_location    = "s3://prod-bucket-for-all/glue_scripts/prod_rds_transfer.py"
      glue_version       = "5.0"
      max_capacity       = null
      number_of_workers  = 2
      worker_type        = "G.1X"
      tags = {
        Environment = "prod"
        Component   = "migration"
      }
    }
  }

  lambda_file_name = {
    uat = {
      process  = "uat_lambda_function_process.zip"
      transfer = "uat_lambda_function_transfer.zip"
    }
    prod = {
      process  = "prod_lambda_function_process.zip"
      transfer = "prod_lambda_function_transfer.zip"
    }
  }

  lambda_files = {
    uat = {
      process  = "artifacts/uat/uat_lambda_function_process.zip"
      transfer = "artifacts/uat/uat_lambda_function_transfer.zip"
    }
    prod = {
      process  = "artifacts/prod/prod_lambda_function_process.zip"
      transfer = "artifacts/prod/prod_lambda_function_transfer.zip"
    }
  }

  lambda_s3_keys = {
    uat = {
      process  = "uat_lambda_function_process.zip"
      transfer = "uat_lambda_function_transfer.zip"
    }
    prod = {
      process  = "prod_lambda_function_process.zip"
      transfer = "prod_lambda_function_transfer.zip"
    }
  }

}

resource "aws_s3_object" "glue_script" {
  bucket = local.s3_buckets[local.env]         # e.g., "prod-glue-scripts-bucket"
  key    = local.glue_script_keys[local.env]   # e.g., "glue_scripts/prod_transfer.py"
  source = local.glue_script_files[local.env]  # e.g., "scripts/prod_transfer.py"
  etag   = filemd5(local.glue_script_files[local.env])
}

# Upload Lambda zips to S3
resource "aws_s3_object" "lambda_process_zip" {
  bucket = local.s3_buckets[local.env]
  key    = local.lambda_s3_keys[local.env]["process"]
  source = local.lambda_files[local.env]["process"]
  etag   = filemd5(local.lambda_files[local.env]["process"])
}

resource "aws_s3_object" "lambda_transfer_zip" {
  bucket = local.s3_buckets[local.env]
  key    = local.lambda_s3_keys[local.env]["transfer"]
  source = local.lambda_files[local.env]["transfer"]
  etag   = filemd5(local.lambda_files[local.env]["transfer"])
}

# Lambda - Process
module "lambda_process" {
  source        = "./modules/lambda"
  function_name = local.env == "prod" ? "prod_lambda_function_process" : "uat_lambda_function_process"
  role_arn      = local.lambda_roles[local.env]["process"]
  handler       = "index.handler"
  runtime       = "python3.13"
  s3_bucket     = local.s3_buckets[local.env]
  s3_key        = local.lambda_s3_keys[local.env]["process"]
  source_code_hash  = aws_s3_object.lambda_process_zip.etag
  tags = {
    Environment = local.env
  }
}

# Lambda - Transfer
module "lambda_transfer" {
  source        = "./modules/lambda"
  function_name = local.env == "prod" ? "prod_lambda_function_transfer" : "uat_lambda_function_transfer"
  role_arn      = local.lambda_roles[local.env]["transfer"]
  handler       = "index.handler"
  runtime       = "python3.13"
  s3_bucket     = local.s3_buckets[local.env]
  s3_key            = local.lambda_s3_keys[local.env]["transfer"]
  source_code_hash  = aws_s3_object.lambda_transfer_zip.etag
  tags = {
    Environment = local.env
  }
}

# Step Function
module "step_function" {
  source     = "./modules/step_function"
  name       = local.env == "prod" ? "prod_data_migration_step" : "uat_data_migration_step"
  role_arn   = local.step_function_roles[local.env]
  definition = file("step_function_definition.json")
  tags = {
    Environment = local.env
    Component   = "migration"
  }
}

# Glue Job
module "glue_job" {
  source             = "./modules/glue_job"
  name               = local.glue_configs[local.env].name
  role_arn           = local.glue_roles[local.env]
  command_name       = "glueetl"
  script_location    = local.glue_configs[local.env].script_location
  python_version     = "3"
  glue_version       = local.glue_configs[local.env].glue_version
  max_capacity       = local.glue_configs[local.env].max_capacity
  number_of_workers  = local.glue_configs[local.env].number_of_workers
  worker_type        = local.glue_configs[local.env].worker_type
  # default_arguments  = local.glue_configs[local.env].job_parameters
  default_arguments = local.env == "uat" ? {
    "--env"         = "uat"
    "--debug"       = "true"
    "--region"      = "us-east-2"
    "--enable-metrics" = "true"
    "--additional-python-modules"  = "paramiko"
    "--enable-continuous-cloudwatch-log" = "true"
  } : {
    "--env"         = "prod"
    "--debug"       = "false"
    "--region"      = "us-east-2"
    "--enable-metrics" = "true"
    "--additional-python-modules"  = "paramiko"
    "--enable-continuous-cloudwatch-log" = "true"
  }

  tags = {
    Environment = local.env
    Job         = "rds_transfer"
  }
}

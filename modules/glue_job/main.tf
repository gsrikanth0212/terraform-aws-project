resource "aws_glue_job" "this" {
  name     = var.name
  role_arn = var.role_arn

  command {
    name            = var.command_name
    script_location = var.script_location
    python_version  = var.python_version
  }

  glue_version = var.glue_version
  tags         = var.tags

  # Only include max_capacity when number_of_workers is null
  max_capacity      = var.number_of_workers == null ? var.max_capacity : null

  # Only include number_of_workers/worker_type when max_capacity is null
  number_of_workers = var.max_capacity == null ? var.number_of_workers : null
  worker_type       = var.max_capacity == null ? var.worker_type : null

  # Only include default_arguments if it has any values
  default_arguments = length(var.default_arguments) > 0 ? var.default_arguments : null
  
}

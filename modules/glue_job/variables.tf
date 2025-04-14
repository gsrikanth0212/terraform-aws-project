# variables.tf inside glue_job module
variable "name" {}
variable "role_arn" {}
variable "command_name" {}
variable "script_location" {}
variable "python_version" {}
variable "glue_version" {}
variable "tags" { type = map(string) }
variable "default_arguments" {
  type        = map(string)
  description = "Default arguments for the Glue job"
  default     = {}
}
variable "max_capacity" {
  type    = number
  default = null
}

variable "number_of_workers" {
  type    = number
  default = null
}

variable "worker_type" {
  type    = string
  default = null
}


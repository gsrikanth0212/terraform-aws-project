variable "function_name" {
  type = string
}

variable "role_arn" {
  type = string
}

variable "handler" {
  type = string
}

variable "runtime" {
  type = string
}

variable "s3_bucket" {
  type = string
}

variable "s3_key" {
  type = string
}

variable "source_code_hash" {
  type = string
}

variable "tags" {
  type = map(string)
}

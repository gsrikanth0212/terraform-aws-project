# variables.tf inside step_function module
variable "name" {}
variable "role_arn" {}
variable "definition" {}
variable "tags" { type = map(string) }

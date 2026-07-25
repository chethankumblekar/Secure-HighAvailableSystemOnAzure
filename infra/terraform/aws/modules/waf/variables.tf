variable "project_name" { type = string }
variable "environment" { type = string }
variable "tags" { type = map(string) }

variable "rate_limit" {
  description = "Max requests per 5-minute window per source IP before WAF blocks it"
  type        = number
  default     = 2000
}

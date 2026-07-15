variable "resource_group_id" { type = string }

variable "required_tag_name" {
  description = "Tag key that must be present on all resources in the resource group"
  type        = string
  default     = "owner"
}

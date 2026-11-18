variable "account_id" {
  description = "Expected AWS sandbox account. Terraform refuses other accounts."
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}$", var.account_id))
    error_message = "Use the 12-digit AWS sandbox account ID."
  }
}

variable "region" {
  description = "Region of the sandbox and ECR repository."
  type        = string
  default     = "eu-west-2"
}

variable "name" {
  description = "Unique lab prefix and existing ECR repository name."
  type        = string

  validation {
    condition     = can(regex("^rw-lab-[a-z0-9][a-z0-9-]{0,17}$", var.name))
    error_message = "Use a name such as rw-lab-example-01."
  }
}

variable "image_digest" {
  description = "Digest of the pushed Linux AMD64 image, including sha256:."
  type        = string

  validation {
    condition     = can(regex("^sha256:[a-f0-9]{64}$", var.image_digest))
    error_message = "Use an immutable ECR image digest, rather than an image tag."
  }
}

variable "release" {
  description = "v1 is the healthy baseline; v2 is the intentional failure."
  type        = string
  default     = "v1"

  validation {
    condition     = contains(["v1", "v2"], var.release)
    error_message = "Release must be v1 or v2."
  }
}

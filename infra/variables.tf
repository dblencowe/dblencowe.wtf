variable "aws_region" {
  description = "Region for the site bucket. The CloudFront certificate is always created in us-east-1."
  type        = string
  default     = "eu-west-1"
}

variable "project" {
  description = "Name used for resources and the Project tag. Must match the backend key prefix in versions.tf, which the runner role's state access is scoped to."
  type        = string
  default     = "dblencowe-wtf"
}

variable "github_repository" {
  description = "This repository as owner/repo. Must match its entry in dblencowe-github-aws-infra's allowlist.tf, or the entry role can't switch into the runner role."
  type        = string
  default     = "dblencowe/dblencowe-wtf"
}

variable "entry_role_arn" {
  description = "This repo's OIDC entry role, from the infra repo's entry_role_arns output. Supplied as TF_VAR_entry_role_arn (in CI, from the AWS_ENTRY_ROLE_ARN Actions variable)."
  type        = string
}

variable "state_bucket_name" {
  description = "Bucket holding this stack's Terraform state, so the runner role can be granted access. Supplied as TF_VAR_state_bucket_name (in CI, from the TF_STATE_BUCKET Actions variable)."
  type        = string
}

variable "primary_domain" {
  description = "Canonical domain for the site. Needs a public Route 53 hosted zone in this account."
  type        = string
}

variable "redirect_domains" {
  description = "Domains that permanently redirect to primary_domain. Each needs a public Route 53 hosted zone in this account."
  type        = list(string)
  default     = []
}

# Each entry carries:
#   verification - Proton's domain verification TXT value (protonmail-verification=...)
#   dkim         - Proton's DKIM CNAME records as host => target
#   dmarc_policy - DMARC TXT value, published once dkim is filled in
variable "mail_domains" {
  description = "Domains whose email is hosted by Proton Mail, keyed by domain name. Each needs a public Route 53 hosted zone in this account."
  type = map(object({
    verification = string
    dkim         = optional(map(string), {})
    dmarc_policy = optional(string, "v=DMARC1; p=quarantine")
  }))
  default = {}
}

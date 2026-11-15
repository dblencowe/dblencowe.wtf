terraform {
  required_version = ">= 1.11.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # Remote state in S3 with native locking (use_lockfile). This is a partial
  # configuration; the bucket and region are supplied at init time:
  #
  #   CI:    from the TF_STATE_BUCKET and AWS_REGION Actions variables
  #   local: terraform init -backend-config=backend.hcl  (see backend.hcl.example)
  #
  # The key prefix must equal var.project: the runner role can only read and
  # write state under "<project>/" (see github_runner.tf).
  backend "s3" {
    key          = "dblencowe-wtf/terraform.tfstate"
    encrypt      = true
    use_lockfile = true
  }
}

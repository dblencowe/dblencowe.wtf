# GitHub Actions runner role for this repo.
#
# Trust model (see dblencowe-github-aws-infra/README.md):
#   GitHub OIDC -> this repo's entry role (allow-listed in the infra repo)
#     -> ABAC: only roles tagged Role=github-runner-iam AND Repo=<this repo>
#       -> this runner role, which holds the deploy permissions.
#
# Equivalent to the infra repo's github-runner-role module. It's defined here
# rather than sourced from it because that repo is private, and CI's
# GITHUB_TOKEN can't clone it during terraform init.

data "aws_iam_policy_document" "github_runner_trust" {
  statement {
    sid     = "SwitchFromEntryRole"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = [var.entry_role_arn]
    }
  }
}

resource "aws_iam_role" "github_runner" {
  name                 = "${var.project}-github-runner"
  path                 = "/github-runner/"
  assume_role_policy   = data.aws_iam_policy_document.github_runner_trust.json
  max_session_duration = 3600

  tags = {
    Project = var.project
    Repo    = var.github_repository
    Role    = "github-runner-iam"
  }
}

# Scoped to this stack. IAM access is deliberately read-only: the pipeline
# can't widen its own permissions, so changes to this policy are applied
# locally with admin credentials (see README.md).
data "aws_iam_policy_document" "github_runner" {
  statement {
    sid       = "TerraformStateBucket"
    actions   = ["s3:ListBucket", "s3:GetBucketVersioning"]
    resources = ["arn:${local.partition}:s3:::${var.state_bucket_name}"]
  }

  # This stack's state and lock file only, not other projects' state.
  statement {
    sid       = "TerraformStateObjects"
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = ["arn:${local.partition}:s3:::${var.state_bucket_name}/${var.project}/*"]
  }

  statement {
    sid     = "SiteBucket"
    actions = ["s3:*"]
    resources = [
      "arn:${local.partition}:s3:::${local.site_bucket_name}",
      "arn:${local.partition}:s3:::${local.site_bucket_name}/*",
    ]
  }

  statement {
    sid       = "Route53Lookups"
    actions   = ["route53:ListHostedZones", "route53:ListHostedZonesByName", "route53:GetChange"]
    resources = ["*"]
  }

  statement {
    sid = "Route53Records"
    actions = [
      "route53:GetHostedZone",
      "route53:ListResourceRecordSets",
      "route53:ChangeResourceRecordSets",
      "route53:ListTagsForResource",
    ]
    resources = distinct(concat([for zone in data.aws_route53_zone.site : zone.arn], [for zone in data.aws_route53_zone.mail : zone.arn]))
  }

  # CloudFront certificates live in us-east-1.
  statement {
    sid       = "Certificates"
    actions   = ["acm:*"]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "aws:RequestedRegion"
      values   = ["us-east-1"]
    }
  }

  statement {
    sid       = "CloudFront"
    actions   = ["cloudfront:*"]
    resources = ["*"]
  }

  statement {
    sid = "ReadOwnRole"
    actions = [
      "iam:GetRole",
      "iam:GetRolePolicy",
      "iam:ListRolePolicies",
      "iam:ListAttachedRolePolicies",
      "iam:ListRoleTags",
    ]
    resources = [aws_iam_role.github_runner.arn]
  }
}

resource "aws_iam_role_policy" "github_runner" {
  name   = "permissions"
  role   = aws_iam_role.github_runner.id
  policy = data.aws_iam_policy_document.github_runner.json
}

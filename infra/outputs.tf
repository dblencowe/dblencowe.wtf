output "site_url" {
  description = "Canonical URL of the site."
  value       = "https://${var.primary_domain}"
}

output "site_bucket" {
  description = "Bucket the built site is published to."
  value       = aws_s3_bucket.site.bucket
}

output "cloudfront_distribution_id" {
  description = "Distribution to invalidate after publishing."
  value       = aws_cloudfront_distribution.site.id
}

output "runner_role_arn" {
  description = "Set as the AWS_RUNNER_ROLE_ARN Actions variable."
  value       = aws_iam_role.github_runner.arn
}

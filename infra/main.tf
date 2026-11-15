data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  partition  = data.aws_partition.current.partition

  tags = {
    ManagedBy = "terraform"
    Project   = var.project
  }

  site_domains = concat([var.primary_domain], var.redirect_domains)

  # Every hostname the site answers on: each domain plus its www. subdomain.
  site_hostnames = flatten([for domain in local.site_domains : [domain, "www.${domain}"]])

  # Hostname => the domain whose hosted zone holds its records.
  hostname_domains = merge([for domain in local.site_domains : { (domain) = domain, "www.${domain}" = domain }]...)

  site_bucket_name = "${var.project}-site-${local.account_id}"
}

# The domains are already delegated to these Route 53 zones, so they're looked
# up rather than created.
data "aws_route53_zone" "site" {
  for_each = toset(local.site_domains)

  name         = each.value
  private_zone = false
}

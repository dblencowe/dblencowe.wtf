resource "aws_acm_certificate" "site" {
  provider = aws.us_east_1

  domain_name               = var.primary_domain
  subject_alternative_names = [for hostname in local.site_hostnames : hostname if hostname != var.primary_domain]
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "certificate_validation" {
  for_each = {
    for option in aws_acm_certificate.site.domain_validation_options : option.domain_name => option
  }

  zone_id = data.aws_route53_zone.site[local.hostname_domains[each.key]].zone_id
  name    = each.value.resource_record_name
  type    = each.value.resource_record_type
  records = [each.value.resource_record_value]
  ttl     = 300

  # ACM uses the same validation record for a hostname across certificates in
  # an account, so the existing dblencowe.wtf certificate's records are reused.
  allow_overwrite = true
}

resource "aws_acm_certificate_validation" "site" {
  provider = aws.us_east_1

  certificate_arn         = aws_acm_certificate.site.arn
  validation_record_fqdns = [for record in aws_route53_record.certificate_validation : record.fqdn]

  timeouts {
    create = "30m"
  }
}

# Proton Mail for every domain in var.mail_domains. The account-specific values
# (verification token, DKIM targets) come from Proton's domain settings via
# terraform.tfvars.

locals {
  # One entry per DKIM record, keyed by its full hostname, so every mail
  # domain's records come out of a single for_each.
  mail_dkim_records = {
    for record in flatten([
      for domain, mail in var.mail_domains : [
        for host, target in mail.dkim : {
          fqdn   = "${host}.${domain}"
          domain = domain
          target = target
        }
      ]
    ]) : record.fqdn => record
  }

  # Proton's setup adds DMARC after DKIM, so a domain gets its DMARC record
  # only once its DKIM targets are configured.
  mail_dmarc_domains = {
    for domain, mail in var.mail_domains : domain => mail if length(mail.dkim) > 0
  }
}

data "aws_route53_zone" "mail" {
  for_each = var.mail_domains

  name         = each.key
  private_zone = false
}

resource "aws_route53_record" "mail_mx" {
  for_each = var.mail_domains

  zone_id = data.aws_route53_zone.mail[each.key].zone_id
  name    = each.key
  type    = "MX"
  ttl     = 3600
  records = ["10 mail.protonmail.ch.", "20 mailsec.protonmail.ch."]
}

# Route 53 holds every TXT value for a name in one record set, so Proton's
# verification token and SPF share it. allow_overwrite adopts the verification
# records that were added by hand, which is also why every domain's own token
# has to stay in terraform.tfvars: without it, the apply would drop the token
# and Proton would stop treating the domain as verified.
resource "aws_route53_record" "mail_txt" {
  for_each = var.mail_domains

  zone_id = data.aws_route53_zone.mail[each.key].zone_id
  name    = each.key
  type    = "TXT"
  ttl     = 3600
  records = [
    each.value.verification,
    "v=spf1 include:_spf.protonmail.ch ~all",
  ]

  allow_overwrite = true
}

resource "aws_route53_record" "mail_dkim" {
  for_each = local.mail_dkim_records

  zone_id = data.aws_route53_zone.mail[each.value.domain].zone_id
  name    = each.key
  type    = "CNAME"
  ttl     = 3600
  records = [each.value.target]
}

resource "aws_route53_record" "mail_dmarc" {
  for_each = local.mail_dmarc_domains

  zone_id = data.aws_route53_zone.mail[each.key].zone_id
  name    = "_dmarc.${each.key}"
  type    = "TXT"
  ttl     = 3600
  records = [each.value.dmarc_policy]
}

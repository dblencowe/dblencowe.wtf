# Committed on purpose: everything here ends up in public DNS anyway.
# Account-specific values (entry role ARN, state bucket) are supplied as
# TF_VAR_* environment variables instead - see README.md.

primary_domain   = "dblencowe.wtf"
redirect_domains = ["dblencowe.com", "dblencowe.dev"]

# Both verification tokens are already published by hand in Route 53 and are
# adopted by Terraform. Each domain's own token must stay here: the apply
# rewrites the whole apex TXT record set, so a missing token would be dropped
# and Proton would stop treating that domain as verified.
#
# Copy the DKIM targets from Proton (Settings > Domain names > the domain >
# DKIM) and uncomment them. A domain gets no DKIM or DMARC records until then.
mail_domains = {
  "dblencowe.com" = {
    verification = "protonmail-verification=4b2c3c0d2e27cabe71fc3d5a3ecc899258f80658"

    dkim = {
      # "protonmail._domainkey"  = "protonmail.domainkey.<id>.domains.proton.ch."
      # "protonmail2._domainkey" = "protonmail2.domainkey.<id>.domains.proton.ch."
      # "protonmail3._domainkey" = "protonmail3.domainkey.<id>.domains.proton.ch."
    }
  }

  # Token read from the live apex TXT record on 2026-11-15; check it against
  # Proton's domain settings before the first apply.
  "dblencowe.wtf" = {
    verification = "protonmail-verification=43d45ccb8364c9fb086083a45af5582a40121615"

    dkim = {
      # "protonmail._domainkey"  = "protonmail.domainkey.<id>.domains.proton.ch."
      # "protonmail2._domainkey" = "protonmail2.domainkey.<id>.domains.proton.ch."
      # "protonmail3._domainkey" = "protonmail3.domainkey.<id>.domains.proton.ch."
    }
  }
}

data "aws_cloudfront_cache_policy" "caching_optimized" {
  name = "Managed-CachingOptimized"
}

data "aws_cloudfront_response_headers_policy" "security_headers" {
  name = "Managed-SecurityHeadersPolicy"
}

resource "aws_cloudfront_origin_access_control" "site" {
  name                              = local.site_bucket_name
  description                       = "CloudFront access to the ${var.project} site bucket"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# Sends www. and the redirect domains to the primary domain, and serves Hugo's
# directory-style URLs from their index.html objects.
resource "aws_cloudfront_function" "viewer_request" {
  name    = "${var.project}-viewer-request"
  runtime = "cloudfront-js-2.0"
  publish = true
  code    = templatefile("${path.module}/functions/viewer-request.js", { primary_domain = var.primary_domain })
}

resource "aws_cloudfront_distribution" "site" {
  enabled             = true
  comment             = var.primary_domain
  aliases             = local.site_hostnames
  default_root_object = "index.html"
  http_version        = "http2and3"
  is_ipv6_enabled     = true
  price_class         = "PriceClass_100" # North America and Europe edges

  origin {
    origin_id                = "site-bucket"
    domain_name              = aws_s3_bucket.site.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.site.id
  }

  default_cache_behavior {
    target_origin_id           = "site-bucket"
    viewer_protocol_policy     = "redirect-to-https"
    allowed_methods            = ["GET", "HEAD"]
    cached_methods             = ["GET", "HEAD"]
    compress                   = true
    cache_policy_id            = data.aws_cloudfront_cache_policy.caching_optimized.id
    response_headers_policy_id = data.aws_cloudfront_response_headers_policy.security_headers.id

    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.viewer_request.arn
    }
  }

  # The bucket policy doesn't grant s3:ListBucket, so S3 answers 403 rather
  # than 404 for a missing object. Serve Hugo's 404 page for either.
  custom_error_response {
    error_code         = 403
    response_code      = 404
    response_page_path = "/404.html"
  }

  custom_error_response {
    error_code         = 404
    response_code      = 404
    response_page_path = "/404.html"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate_validation.site.certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }
}

resource "aws_route53_record" "site" {
  for_each = {
    for pair in setproduct(local.site_hostnames, ["A", "AAAA"]) : "${pair[0]} ${pair[1]}" => {
      name = pair[0]
      type = pair[1]
    }
  }

  zone_id = data.aws_route53_zone.site[local.hostname_domains[each.value.name]].zone_id
  name    = each.value.name
  type    = each.value.type

  # dblencowe.wtf and www.dblencowe.wtf already alias the old placeholder
  # distribution; take those records over.
  allow_overwrite = true

  alias {
    name                   = aws_cloudfront_distribution.site.domain_name
    zone_id                = aws_cloudfront_distribution.site.hosted_zone_id
    evaluate_target_health = false
  }
}

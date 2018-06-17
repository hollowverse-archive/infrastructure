# This file defines all the infrastructure needed for storing and processing
# images on hollowverse.com

# An S3 bucket to store unprocessed images (e.g. images of notable people fetched
# from Wikipedia)
resource aws_s3_bucket "unprocessed_photos_bucket" {
  bucket = "hollowverse-photos-unprocessed-${var.stage}"

  versioning {
    enabled = true
  }

  tags = "${local.common_tags}"
}

# An S3 bucket to store the processed, production-ready photos
resource aws_s3_bucket "processed_photos_bucket" {
  bucket = "hollowverse-photos-processed-${var.stage}"

  versioning {
    enabled = true
  }

  tags = "${local.common_tags}"
}

resource "aws_cloudfront_origin_access_identity" "origin_access_identity_for_photos_bucket" {
  comment = "Some comment"
}

data aws_acm_certificate "default_certificate" {
  most_recent = true
  statuses    = ["ISSUED"]
  domain      = "hollowverse.com"
}

resource aws_cloudfront_distribution "photos_cloudfront_distribution" {
  enabled = false

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn = "${data.aws_acm_certificate.default_certificate.arn}"
    ssl_support_method  = "snionly"
  }

  origin {
    domain_name = "${aws_s3_bucket.processed_photos_bucket.bucket_domain_name}"
    origin_id   = "processed-photos-bucket"

    s3_origin_config {
      origin_access_identity = "${aws_cloudfront_origin_access_identity.origin_access_identity_for_photos_bucket.cloudfront_access_identity_path}"
    }
  }

  aliases = "${compact(list(
    "photos-${var.stage}.hollowverse.com",
    "${var.stage == "production" ? "photos-1.hollowverse.com" : ""}"
  ))}"

  # Reference: https://aws.amazon.com/cloudfront/pricing/
  price_class = "PriceClass_100"

  default_cache_behavior {
    target_origin_id       = "processed-photos-bucket"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true
    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }
  }

  logging_config {
    bucket = "${aws_s3_bucket.logging_bucket.bucket_domain_name}"
    prefix = "photos/"
  }

  tags = "${local.common_tags}"
}

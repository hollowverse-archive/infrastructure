# This file defines all the infrastructure needed for storing and processing
# images on hollowverse.com

# An S3 bucket to store unprocessed images (e.g. images of notable people fetched
# from Wikipedia).
#
# We expect this to exist. We do not create it here.
# It's currently managed by `hollowverse/process-image`.
# See https://github.com/serverless/serverless/issues/4284
data aws_s3_bucket "unprocessed_photos_bucket" {
  bucket = "hollowverse-photos-unprocessed-${var.stage}"
}

# An S3 bucket to store the processed, production-ready photos
resource aws_s3_bucket "processed_photos_bucket" {
  bucket = "hollowverse-photos-processed-${var.stage}"

  versioning {
    enabled = true
  }

  tags = "${local.common_tags}"
}

resource "aws_s3_bucket_policy" "process_photos_s3_bucket_policy" {
  bucket = "${aws_s3_bucket_policy.processed_photos_bucket.id}"

  policy = <<POLICY
  {
    "Version": "2008-10-17",
    "Id": "PolicyForCloudFrontPrivateContent",
    "Statement": [
      {
        "Sid": "1",
        "Effect": "Allow",
        "Principal": {
          "AWS": "${aws_cloudfront_origin_access_identity.origin_access_identity_for_photos_bucket.iam_arn}"
        },
        "Action": "s3:GetObject",
        "Resource": "${aws_s3_bucket_policy.processed_photos_bucket.arn}/*"
      }
    ]
  }
  POLICY
}

resource "aws_cloudfront_origin_access_identity" "origin_access_identity_for_photos_bucket" {
  comment = "Allow CloudFront to access S3 bucket"
}

# We expect a valid certificate to exist in AWS Certificate Manager,
# issued for hollowverse.com and all subdomains (*.hollowverse.com)
data aws_acm_certificate "default_certificate" {
  most_recent = true
  statuses    = ["ISSUED"]
  domain      = "hollowverse.com"
}

resource aws_cloudfront_distribution "photos_cloudfront_distribution" {
  enabled = true

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn = "${data.aws_acm_certificate.default_certificate.arn}"
    ssl_support_method  = "sni-only"
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
    "${var.stage == "production" ? "photos.hollowverse.com" : ""}"
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

# We expect a hosted zone for hollowverse.com. to exist
data aws_route53_zone "hollowverse_zone" {
  name = "hollowverse.com."
}

resource aws_route53_record "photos" {
  count   = "${length(aws_cloudfront_distribution.photos_cloudfront_distribution.aliases)}"
  zone_id = "${data.aws_route53_zone.hollowverse_zone.id}"

  type = "A"
  name = "${element(aws_cloudfront_distribution.photos_cloudfront_distribution.aliases, count.index)}"

  alias {
    name                   = "${aws_cloudfront_distribution.photos_cloudfront_distribution.domain_name}"
    zone_id                = "${aws_cloudfront_distribution.photos_cloudfront_distribution.hosted_zone_id}"
    evaluate_target_health = false
  }
}

# api.hollowverse.com and possibly other subdomains are
# managed by their respective CloudFormation stacks. See `serverless.yml`
# files in other Hollowverse repositories.


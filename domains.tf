# We expect a hosted zone to exist for hollowverse.com.
data aws_route53_zone "hollowverse_zone" {
  name = "hollowverse.com."
}

resource aws_route53_record "photos" {
  count   = "${length(aws_cloudfront_distribution.photos_cloudfront_distribution.aliases)}"
  zone_id = "${data.aws_route53_zone.hollowverse_zone.id}"

  type = "A"
  ttl  = 300
  name = "${element(aws_cloudfront_distribution.photos_cloudfront_distribution.aliases, count.index)}"

  records = [
    "${aws_cloudfront_distribution.photos_cloudfront_distribution.domain_name}",
  ]
}

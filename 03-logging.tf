# We use Splunk with the AWS Add-on for Splunk to process and visualize logs
# from different AWS services. This configuration configures an S3 bucket to store
# the logs, and two SQS queues which will be queried by Splunk.

# This method of collecting logs is called S3-based SQS in Splunk.

# Logs from different AWS resources are stored here for further processing by Splunk
resource aws_s3_bucket "logging_bucket" {
  bucket_prefix = "hollowverse-logging-bucket-${var.stage}"

  tags = "${local.common_tags}"
}

# This configures the S3 bucket to notify the SQS queue of any new logs
resource aws_s3_bucket_notification "notification" {
  bucket = "${aws_s3_bucket.logging_bucket.id}"

  queue {
    queue_arn = "${aws_sqs_queue.log_queue.arn}"
    events    = ["s3:ObjectCreated:*"]
  }
}

# Messages sent to this queue will later be processed by Splunk AWS Add-on
resource "aws_sqs_queue" "log_queue" {
  name = "${local.log_queue_name}"

  tags = "${local.common_tags}"

  visibility_timeout_seconds = 600

  # The redrive policy defines how/where failed messages are sent
  redrive_policy = <<REDRIVE_POLICY
    {
      "deadLetterTargetArn": "${aws_sqs_queue.dead_letter_log_queue.arn}",
      "maxReceiveCount": 5
    }
  REDRIVE_POLICY

  policy = <<POLICY
    {
      "Version": "2012-10-17",
      "Statement": [
        {
          "Effect": "Allow",
          "Principal": "*",
          "Action": "sqs:SendMessage",
          "Resource": "arn:aws:sqs:*:*:${local.log_queue_name}",
          "Condition": {
            "ArnEquals": { "aws:SourceArn": "${aws_s3_bucket.logging_bucket.arn}" }
          }
        }
      ]
    }
  POLICY
}

# Messages that fail to be processed in the log queue will
# will be sent to this queue.
resource "aws_sqs_queue" "dead_letter_log_queue" {
  name = "${local.dead_letter_log_queue_name}"
}

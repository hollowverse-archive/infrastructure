resource "aws_sqs_queue" "loggingDeadLetterQueue" {
  name = "terraform-logging-dead-letter-queue"
}

resource "aws_sqs_queue" "logQueue" {
  name = "terraform-logging-queue"

  visibility_timeout_seconds = 600

  redrive_policy = <<REDRIVE_POLICY
    {
      "deadLetterTargetArn": "${aws_sqs_queue.loggingDeadLetterQueue.arn}",
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
          "Resource": "arn:aws:sqs:*:*:terraform-logging-queue",
          "Condition": {
            "ArnEquals": { "aws:SourceArn": "${aws_s3_bucket.loggingBucket.arn}" }
          }
        }
      ]
    }
  POLICY
}

resource aws_s3_bucket "loggingBucket" {
  bucket_prefix = "terraform-logging-bucket-"
}

resource aws_s3_bucket_notification "notification" {
  bucket = "${aws_s3_bucket.loggingBucket.id}"

  queue {
    queue_arn = "${aws_sqs_queue.logQueue.arn}"
    events    = ["s3:ObjectCreated:*"]
  }
}

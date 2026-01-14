resource "aws_s3_bucket" "website" {
  bucket_prefix = "armageddon-1labc-"
  force_destroy = true

  tags = {
    Name        = "s3 bucket for armmageddon labs"
    Environment = "Dev"
  }
}
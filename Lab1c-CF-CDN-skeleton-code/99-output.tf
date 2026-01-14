output "website_url" {
  value = "https://${aws_cloudfront_distribution.s3_distribution.domain_name}"
}




# output "bucket_info" {
#     value = {
#         name = aws_s3_bucket.website.bucket
#         arn = aws_s3_bucket.website.arn
#         }
# }


# output "policy" {
#   value = aws_s3_bucket_policy.public_access.policy
# }
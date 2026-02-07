# Explanation: Outputs are your mission report—what got built and where to find it.
output "lab1c_bonusA_example_vpc_id" {
  value = aws_vpc.lab1c_bonusA_example_vpc01.id
}

output "lab1c_bonusA_example_public_subnet_ids" {
  value = aws_subnet.lab1c_bonusA_example_public_subnets[*].id
}

output "lab1c_bonusA_example_private_subnet_ids" {
  value = aws_subnet.lab1c_bonusA_example_private_subnets[*].id
}

output "lab1c_bonusA_example_ec2_instance_id" {
  value = aws_instance.lab1c_bonusA_example_ec201.id
}

output "lab1c_bonusA_example_rds_endpoint" {
  value = aws_db_instance.lab1c_bonusA_example_rds01.address
}

output "lab1c_bonusA_example_sns_topic_arn" {
  value = aws_sns_topic.lab1c_bonusA_example_sns_topic01.arn
}

output "lab1c_bonusA_example_log_group_name" {
  value = aws_cloudwatch_log_group.lab1c_bonusA_example_log_group01.name
}

output "lab1c_bonusA_example_route53_zone_id" {
  value = local.lab1c_bonusA_example_zone_id
}

output "lab1c_bonusA_example_app_url_https" {
  value = "https://${var.app_subdomain}.${var.domain_name}"
}

# Coordinates for the WAF log destination
output "chewbacca_waf_log_destination" {
  value = var.waf_log_destination
}

output "chewbacca_waf_cw_log_group_name" {
  value = var.waf_log_destination == "cloudwatch" ? aws_cloudwatch_log_group.lab1c_bonusA_example_waf_log_group01[0].name : null
}

output "chewbacca_waf_logs_s3_bucket" {
  value = var.waf_log_destination == "s3" ? aws_s3_bucket.lab1c_bonusA_example_waf_logs_bucket01[0].bucket : null
}

output "chewbacca_waf_firehose_name" {
  value = var.waf_log_destination == "firehose" ? aws_kinesis_firehose_delivery_stream.lab1c_bonusA_example_waf_firehose01[0].name : null
}

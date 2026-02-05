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
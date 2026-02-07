#Bonus-A outputs (append to outputs.tf)

# Explanation: These outputs prove lab1c_bonusA built private hyperspace lanes (endpoints) instead of public chaos.
output "lab1c_bonusA_vpce_ssm_id" {
  value = aws_vpc_endpoint.lab1c_bonusA_vpce_ssm01.id
}

output "lab1c_bonusA_vpce_logs_id" {
  value = aws_vpc_endpoint.lab1c_bonusA_vpce_logs01.id
}

output "lab1c_bonusA_vpce_secrets_id" {
  value = aws_vpc_endpoint.lab1c_bonusA_vpce_secrets01.id
}

output "lab1c_bonusA_vpce_s3_id" {
  value = aws_vpc_endpoint.lab1c_bonusA_vpce_s3_gw01.id
}

output "lab1c_bonusA_private_ec2_instance_id_bonus" {
  value = aws_instance.lab1c_bonusA_example_ec201.id
}


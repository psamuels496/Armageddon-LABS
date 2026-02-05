# Explanation: Outputs are the mission coordinates — where to point your browser and your blasters.
output "lab1c_bonusA_example_alb_dns_name" {
  value = aws_lb.lab1c_bonusA_example_alb01.dns_name
}

output "lab1c_bonusA_example_app_fqdn" {
  value = "${var.app_subdomain}.${var.domain_name}"
}

output "lab1c_bonusA_example_target_group_arn" {
  value = aws_lb_target_group.lab1c_bonusA_example_tg01.arn
}

output "lab1c_bonusA_example_acm_cert_arn" {
  value = aws_acm_certificate.lab1c_bonusA_example_acm_cert01.arn
}

output "lab1c_bonusA_example_waf_arn" {
  value = var.enable_waf ? aws_wafv2_web_acl.lab1c_bonusA_example_waf01[0].arn : null
}

output "lab1c_bonusA_example_dashboard_name" {
  value = aws_cloudwatch_dashboard.lab1c_bonusA_example_dashboard01.dashboard_name
}
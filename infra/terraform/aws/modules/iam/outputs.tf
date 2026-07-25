output "lb_controller_role_arn" {
  value = aws_iam_role.lb_controller.arn
}

output "finops_cost_reporter_role_arn" {
  value = aws_iam_role.finops_cost_reporter.arn
}

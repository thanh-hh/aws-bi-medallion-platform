output "alert_topic_arn" {
  value = var.alert_email == "" ? null : aws_sns_topic.alerts[0].arn
}

resource "aws_cloudwatch_log_group" "this" {
  count = var.create ? 1 : 0
  # The log group name format is /aws/eks/<cluster-name>/cluster
  # Reference: https://docs.aws.amazon.com/eks/latest/userguide/control-plane-logs.html
  name              = "/aws/eks/${var.prefix}/cluster"
  retention_in_days = 7
}

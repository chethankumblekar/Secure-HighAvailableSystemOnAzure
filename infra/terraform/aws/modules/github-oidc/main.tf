# Same OIDC-federation pattern as ../eks (data "tls_certificate" + aws_iam_openid_connect_provider):
# GitHub Actions runners get short-lived AWS credentials via sts:AssumeRoleWithWebIdentity,
# no long-lived access keys stored as repo secrets.
data "tls_certificate" "github" {
  url = "https://token.actions.githubusercontent.com"
}

resource "aws_iam_openid_connect_provider" "github" {
  count = var.create_oidc_provider ? 1 : 0

  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.github.certificates[0].sha1_fingerprint]

  tags = var.tags
}

data "aws_caller_identity" "current" {}

locals {
  oidc_provider_arn = var.create_oidc_provider ? aws_iam_openid_connect_provider.github[0].arn : "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/token.actions.githubusercontent.com"
}

# Read-only, dry-run-only role for the scheduled FinOps workflow (finops-scheduled.yml):
# orphan_cleanup.py runs without --delete, cost_report.py only reads Cost Explorer.
# No write/delete permissions granted to a scheduled job on principle.
data "aws_iam_policy_document" "finops_ci_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [local.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_repo}:*"]
    }
  }
}

resource "aws_iam_role" "finops_ci" {
  name               = "${var.project_name}-${var.environment}-finops-ci"
  assume_role_policy = data.aws_iam_policy_document.finops_ci_trust.json

  tags = var.tags
}

data "aws_iam_policy_document" "finops_ci_permissions" {
  statement {
    effect = "Allow"
    actions = [
      "ce:GetCostAndUsage",
      "eks:ListClusters",
      "eks:DescribeCluster",
      "ec2:DescribeInstances",
      "ec2:DescribeNatGateways",
      "ec2:DescribeAddresses",
      "ec2:DescribeVolumes",
    ]
    resources = ["*"] # all read-only List/Describe/Get calls; none support resource-level ARN scoping
  }
}

resource "aws_iam_role_policy" "finops_ci" {
  name   = "${var.project_name}-${var.environment}-finops-ci"
  role   = aws_iam_role.finops_ci.id
  policy = data.aws_iam_policy_document.finops_ci_permissions.json
}

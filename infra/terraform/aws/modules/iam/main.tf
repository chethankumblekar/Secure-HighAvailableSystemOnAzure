# IRSA: scope the trust policy to one specific namespace/service-account via the
# OIDC provider's "sub" claim, so only that k8s ServiceAccount can assume this
# role. Mirrors the workload-identity pattern in ../../azure/modules/keyvault.
data "aws_iam_policy_document" "lb_controller_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(var.oidc_issuer_url, "https://", "")}:sub"
      values   = ["system:serviceaccount:${var.lb_controller_namespace}:${var.lb_controller_service_account_name}"]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(var.oidc_issuer_url, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lb_controller" {
  name               = "${var.project_name}-${var.environment}-lb-controller"
  assume_role_policy = data.aws_iam_policy_document.lb_controller_trust.json

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "lb_controller" {
  role       = aws_iam_role.lb_controller.name
  policy_arn = var.lb_controller_policy_arn
}

# Same IRSA pattern as lb_controller above, scoped to a different service
# account: the in-cluster CronJob that pushes AWS Cost Explorer numbers to
# Pushgateway for the Grafana FinOps dashboard. Read-only, Cost Explorer only.
data "aws_iam_policy_document" "finops_cost_reporter_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(var.oidc_issuer_url, "https://", "")}:sub"
      values   = ["system:serviceaccount:${var.finops_reporter_namespace}:${var.finops_reporter_service_account_name}"]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(var.oidc_issuer_url, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "finops_cost_reporter" {
  name               = "${var.project_name}-${var.environment}-finops-cost-reporter"
  assume_role_policy = data.aws_iam_policy_document.finops_cost_reporter_trust.json

  tags = var.tags
}

data "aws_iam_policy_document" "finops_cost_reporter_permissions" {
  statement {
    effect    = "Allow"
    actions   = ["ce:GetCostAndUsage"]
    resources = ["*"] # Cost Explorer has no resource-level ARNs to scope to.
  }
}

resource "aws_iam_role_policy" "finops_cost_reporter" {
  name   = "${var.project_name}-${var.environment}-finops-cost-reporter"
  role   = aws_iam_role.finops_cost_reporter.id
  policy = data.aws_iam_policy_document.finops_cost_reporter_permissions.json
}

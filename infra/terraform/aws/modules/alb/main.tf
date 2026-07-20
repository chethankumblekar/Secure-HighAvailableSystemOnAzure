# Permissions the AWS Load Balancer Controller needs to provision ALBs/NLBs for
# k8s Ingress/Service objects — same role the Helm/ArgoCD-installed controller
# assumes via the IRSA role wired up in ../iam. Policy JSON is the upstream
# source of truth from kubernetes-sigs/aws-load-balancer-controller; re-pull it
# before bumping the controller version rather than hand-editing.
resource "aws_iam_policy" "lb_controller" {
  name        = "${var.project_name}-${var.environment}-lb-controller"
  description = "Permissions for the AWS Load Balancer Controller to manage ALBs/NLBs on behalf of EKS"
  policy      = file("${path.module}/lb-controller-iam-policy.json")

  tags = var.tags
}

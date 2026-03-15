resource "kubernetes_service_account_v1" "dashboard_admin" {
  metadata {
    name      = "dashboard-admin"
    namespace = "kube-system"
  }
}

resource "kubernetes_cluster_role_binding_v1" "dashboard_admin" {
  metadata { name = "dashboard-admin" }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-admin"
  }
  subject {
    kind      = "ServiceAccount"
    name      = "dashboard-admin"
    namespace = "kube-system"
  }
}

resource "kubernetes_secret_v1" "dashboard_token" {
  metadata {
    name      = "dashboard-admin-token"
    namespace = "kube-system"
    annotations = {
      "kubernetes.io/service-account.name" = kubernetes_service_account_v1.dashboard_admin.metadata[0].name
    }
  }
  type       = "kubernetes.io/service-account-token"
  depends_on = [kubernetes_service_account_v1.dashboard_admin]
}

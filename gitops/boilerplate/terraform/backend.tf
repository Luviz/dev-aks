terraform {
  backend "kubernetes" {
    secret_suffix = "default"
    namespace     = "gitops-system"
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
      "app.kubernetes.io/part-of"    = "gitops"
    }
  }
}

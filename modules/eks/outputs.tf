output "eks_cluster_id" {
  value = aws_eks_cluster.eks.cluster_id
}

output "cluster_endpoint" {
  value = aws_eks_cluster.eks.endpoint
}

output "cluster_certificate_authority_data" {
  value = aws_eks_cluster.eks.certificate_authority
}


output "load_balancer_dns" {
  value = kubernetes_service.nodejs_service.status[0].load_balancer[0].ingress[0].hostname
}

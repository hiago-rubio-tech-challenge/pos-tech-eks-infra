provider "aws" {
  region = var.region
}

variable "vpc_id" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "public_subnet_ids" {
  type = list(string)
}

variable "mongo_db_uri" {
  description = "URL de conexão do MongoDB"
  type        = string
  sensitive   = true
}

resource "aws_eks_cluster" "eks" {

  name     = "pos-tech-eks"
  role_arn = "arn:aws:iam::182028773449:role/LabRole"

  vpc_config {
    subnet_ids             = var.private_subnet_ids
    endpoint_public_access = true
  }
}


data "aws_eks_cluster_auth" "cluster" {
  name = aws_eks_cluster.eks.name
}

provider "kubernetes" {
  host                   = aws_eks_cluster.eks.endpoint
  token                  = data.aws_eks_cluster_auth.cluster.token
  cluster_ca_certificate = base64decode(aws_eks_cluster.eks.certificate_authority.0.data)
}

resource "aws_eks_node_group" "pos-tech-node-group" {
  cluster_name    = aws_eks_cluster.eks.name # Referência ao cluster EKS
  node_group_name = "pos-tech-node-group"
  node_role_arn   = "arn:aws:iam::182028773449:role/LabRole"             # Usando a IAM Role existente
  subnet_ids      = [var.private_subnet_ids.0, var.private_subnet_ids.1] # Referência à subnet criada

  scaling_config {
    desired_size = 2 # Número desejado de nós
    max_size     = 3 # Tamanho máximo do grupo
    min_size     = 1 # Tamanho mínimo do grupo
  }

  # Configurações adicionais, se necessário
  tags = {
    Name = "my-node-group"
  }
}

resource "aws_eks_fargate_profile" "fargate_profile" {

  cluster_name         = aws_eks_cluster.eks.name
  fargate_profile_name = "tech-challenge-fargate-profile"

  pod_execution_role_arn = "arn:aws:iam::182028773449:role/LabRole"

  subnet_ids = [
    var.private_subnet_ids.0, var.private_subnet_ids.1
  ]

  selector {
    namespace = "tech-challenge-namespace"
  }
}

resource "kubernetes_namespace" "tech_challenge" {

  metadata {
    name = "tech-challenge-namespace"
  }
}

resource "kubernetes_deployment" "nodejs_app" {

  metadata {
    name      = "nodejs-app"
    namespace = kubernetes_namespace.tech_challenge.metadata[0].name
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "nodejs-app"
      }
    }

    template {
      metadata {
        labels = {
          app = "nodejs-app"
        }
      }

      spec {
        container {
          name  = "nodejs-app"
          image = "182028773449.dkr.ecr.us-east-1.amazonaws.com/tech-challenge-hiago:latest"

          port {
            container_port = 3000
          }

          env {
            name  = "MONGO_URL"
            value = var.mongo_db_uri
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "nodejs_service" {

  metadata {
    name      = "nodejs-service"
    namespace = kubernetes_namespace.tech_challenge.metadata[0].name
  }

  spec {
    type = "LoadBalancer"

    selector = {
      app = kubernetes_deployment.nodejs_app.metadata[0].name
    }

    port {
      protocol    = "TCP"
      port        = 3000
      target_port = 3000
    }
  }
}

resource "kubernetes_horizontal_pod_autoscaler" "nodejs_app_hpa" {

  metadata {
    name      = "nodejs-app-hpa"
    namespace = kubernetes_namespace.tech_challenge.metadata[0].name
  }

  spec {
    scale_target_ref {
      api_version = "apps/v1"
      kind        = "Deployment"
      name        = kubernetes_deployment.nodejs_app.metadata[0].name
    }

    min_replicas                      = 1
    max_replicas                      = 5
    target_cpu_utilization_percentage = 50
  }
}


resource "kubernetes_network_policy" "allow-external" {
  metadata {
    name      = "allow-external"
    namespace = kubernetes_namespace.tech_challenge.metadata[0].name
  }

  spec {
    pod_selector {
      match_labels = {
        app = "nodejs-app"
      }
    }

    policy_types = ["Ingress", "Egress"]

    ingress {
      from {
        # Permite que qualquer pod externo se conecte
        pod_selector {}
      }
    }

    egress {
      to {
        # Permite que os pods se conectem a qualquer lugar na Internet
        namespace_selector {}
      }
    }
  }
}

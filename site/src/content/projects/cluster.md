---
title: "Bootsraping a k8s cluster with argocd applicationsets, helm, and gitOPS"
date: 2024-01-07T13:13 
draft: false
---

### Bootstraping a k8s cluster.

All the code can be find in the following [repo](https://github.com/oscar-todo-app/todo-app) in the infra cluster folder. 

1st what are mutliple ways that we can make sure that once we have a cluster we have all the basics things installed on them:

- Cert manager
- Ingress controller 
- Secrets manger
- Dns
- Observability

We could use terraform to install along with the cluster, but that would tie the infrastructure along our apps. And if we want to scale we would need to make changes possibly to multiple places apply several clusters.

What if we could declare our applications in a stateful way and have a single source of truth?

That's where [GitOps](https://about.gitlab.com/topics/gitops/) comes to play.

First we need a k8s cluster check the we are going to use the 3 tier app one.


First we make sure argo is installed this is the only app i'm going to install with terraform.

``` terraform

terraform {

  required_providers {
    helm = {
      source = "hashicorp/helm"
    }
  }
}
provider "helm" {
  kubernetes {
    host                   = var.clusterHost
    cluster_ca_certificate = base64decode(var.clusterToken)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      args        = ["eks", "get-token", "--cluster-name", var.clusterName]
      command     = "aws"
    }
  }
}
resource "helm_release" "argocd-install" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  namespace        = "argocd"
  create_namespace = true
  timeout          = 600
}
```

And once this is deployed we can get the credentials:

``` sh 
aws eks --region {{ region }} update-kubeconfig --name {{ cluster_name }} 
```

#### Once this is deployed we can create an applicationset
``` yaml 
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: dependencies
  namespace: argocd
spec:
  goTemplate: true
  goTemplateOptions: ["missingkey=error"]
  generators:
    - git:
        repoURL: https://github.com/oscarsjlh/todo-app
        revision: main
        directories:
          - path: k8s/apps/*
  template:
    metadata:
      name: "{{.path.basename}}"
    spec:
      project: default
      source:
        repoURL: https://github.com/oscarsjlh/todo-app
        targetRevision: main
        helm:
          releaseName: "{{.path.basename}}"
          parameters:
          valueFiles:
            - "Values.yaml"
        path: "{{.path.path}}"
      destination:
        server: https://kubernetes.default.svc
        namespace: "{{.path.basename}}"
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
        syncOptions:
          - CreateNamespace=true
```

And then we have the apps folder with the helm charts and Values we want to deploy


#### For example cert manager:

Chart.yaml
``` yaml 

apiVersion: v2
name: cert-manager
description: A Helm chart for Kubernetes
type: application
version: 0.1.0
appVersion: "1.0"
dependencies:
  - name: cert-manager
    version: v1.13.3
    repository: https://charts.jetstack.io

```
And Values.yaml

``` yaml 

cert-manager:
  serviceAccount:
    annotations:
      eks.amazonaws.com/role-arn: 
  securityContext:
    enabled: true
    fsGroup: 1001

```


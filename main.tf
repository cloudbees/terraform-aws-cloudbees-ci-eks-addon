# Copyright (c) CloudBees, Inc.

locals {
  secret_data   = fileexists(var.secrets_file) ? yamldecode(file(var.secrets_file)) : {}
  create_secret = length(local.secret_data) > 0
  oc_secrets_mount = [
    <<-EOT
      OperationsCenter:
        ContainerEnv:
          - name: SECRETS
            value: /var/run/secrets/cbci
        ExtraVolumes:
          - name: cbci-secrets
            secret:
              secretName: cbci-secrets
        ExtraVolumeMounts:
          - name: cbci-secrets
            mountPath: /var/run/secrets/cbci
            readOnly: true
      EOT
  ]
}

resource "kubernetes_namespace" "cbci" {

  metadata {
    name = try(var.helm_config.namespace, "cbci")
  }

}

# Secrets to be passed to Casc
# https://github.com/jenkinsci/configuration-as-code-plugin/blob/master/docs/features/secrets.adoc#kubernetes-secrets
resource "kubernetes_secret" "oc_secrets" {
  count = local.create_secret ? 1 : 0

  metadata {
    name      = "cbci-secrets"
    namespace = kubernetes_namespace.cbci.metadata[0].name
  }

  data = yamldecode(file(var.secrets_file))
}

resource "helm_release" "cloudbees_ci" {

  name             = try(var.helm_config.name, "cloudbees-ci")
  namespace        = try(var.helm_config.namespace, "cbci")
  create_namespace = false
  description      = try(var.helm_config.description, null)
  chart            = "cloudbees-core"
  #Chart versions: #https://artifacthub.io/packages/helm/cloudbees/cloudbees-core/
  #App version: https://docs.cloudbees.com/docs/release-notes/latest/cloudbees-ci/
  version    = try(var.helm_config.version, "3.15666.0+5ea03547ce92")
  repository = try(var.helm_config.repository, "https://public-charts.artifacts.cloudbees.com/repository/public/")
  values = local.create_secret ? concat(var.helm_config.values, local.oc_secrets_mount, [templatefile("${path.module}/values.yml", {
    hosted_zone  = var.hosted_zone
    cert_arn     = var.cert_arn
    LicFirstName = var.temp_license["first_name"]
    LicLastName  = var.temp_license["last_name"]
    LicEmail     = var.temp_license["email"]
    LicCompany   = var.temp_license["company"]
    })]) : concat(var.helm_config.values, [templatefile("${path.module}/values.yml", {
    hosted_zone  = var.hosted_zone
    cert_arn     = var.cert_arn
    LicFirstName = var.temp_license["first_name"]
    LicLastName  = var.temp_license["last_name"]
    LicEmail     = var.temp_license["email"]
    LicCompany   = var.temp_license["company"]
  })])

  timeout                    = try(var.helm_config.timeout, 1200)
  repository_key_file        = try(var.helm_config.repository_key_file, null)
  repository_cert_file       = try(var.helm_config.repository_cert_file, null)
  repository_ca_file         = try(var.helm_config.repository_ca_file, null)
  repository_username        = try(var.helm_config.repository_username, null)
  repository_password        = try(var.helm_config.repository_password, null)
  devel                      = try(var.helm_config.devel, null)
  verify                     = try(var.helm_config.verify, null)
  keyring                    = try(var.helm_config.keyring, null)
  disable_webhooks           = try(var.helm_config.disable_webhooks, null)
  reuse_values               = try(var.helm_config.reuse_values, null)
  reset_values               = try(var.helm_config.reset_values, null)
  force_update               = try(var.helm_config.force_update, null)
  recreate_pods              = try(var.helm_config.recreate_pods, null)
  cleanup_on_fail            = try(var.helm_config.cleanup_on_fail, null)
  max_history                = try(var.helm_config.max_history, null)
  atomic                     = try(var.helm_config.atomic, null)
  skip_crds                  = try(var.helm_config.skip_crds, null)
  render_subchart_notes      = try(var.helm_config.render_subchart_notes, null)
  disable_openapi_validation = try(var.helm_config.disable_openapi_validation, null)
  wait                       = try(var.helm_config.wait, true)
  wait_for_jobs              = try(var.helm_config.wait_for_jobs, null)
  dependency_update          = try(var.helm_config.dependency_update, null)
  replace                    = try(var.helm_config.replace, null)
  lint                       = try(var.helm_config.lint, null)

  dynamic "postrender" {
    for_each = can(var.helm_config.postrender_binary_path) ? [1] : []

    content {
      binary_path = var.helm_config.postrender_binary_path
    }
  }

  dynamic "set" {
    for_each = try(var.helm_config.set, [])

    content {
      name  = set.value.name
      value = set.value.value
      type  = try(set.value.type, null)
    }
  }

  dynamic "set_sensitive" {
    for_each = try(var.helm_config.set_sensitive, {})

    content {
      name  = set_sensitive.value.name
      value = set_sensitive.value.value
      type  = try(set_sensitive.value.type, null)
    }
  }

  depends_on = [
    kubernetes_namespace.cbci
  ]
}

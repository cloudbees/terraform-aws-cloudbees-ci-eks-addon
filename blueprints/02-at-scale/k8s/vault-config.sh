#!/usr/bin/env bash

# Copyright (c) CloudBees, Inc.

set -xeuo pipefail

# Vault namespace
vault_ns="${1:-vault}"
# App role name
approle="cbci-oc"

# https://github.com/hashicorp/terraform-aws-hashicorp-vault-eks-addon?tab=readme-ov-file#usage
## Useal the vault
for i in {1..3}; do
  read -r -p "INFO: Enter Unseal Key number $i [press Enter]: " key
  if [ -z "$key" ]; then
    echo "ERROR: Empty key is not allowed" && exit 1
  fi
  kubectl exec -it vault-0 -n "$vault_ns" -- vault operator unseal "$key"
done
# https://developer.hashicorp.com/vault/tutorials/auth-methods/approle
## Login as admin using token
kubectl exec -it vault-0 -n "$vault_ns" -- vault login
## Create example secrets to be mapped from CloudBees CI
kubectl exec -it vault-0 -n "$vault_ns" -- vault secrets enable --version=2 --path=secret-v2 kv || echo "Path is already enabled"
kubectl exec -it vault-0 -n "$vault_ns" -- vault kv put "secret-v2/$approle/secret-a" username="userVaultExample" password="passw0rdVaultExample"
kubectl exec -it vault-0 -n "$vault_ns" -- vault kv put "secret-v2/$approle/secret-b" secret="secretVaultExample"
kubectl exec -it vault-0 -n "$vault_ns" -- vault auth enable approle || echo "Path is already in use at approle"
## Create App Role to connect cloudbees CI to Vault
kubectl exec -it vault-0 -n "$vault_ns" -- vault policy write "$approle" -<<EOF
path "secret-v2/data/$approle/*" {
  capabilities = [ "read"]
}
EOF
kubectl exec -it vault-0 -n "$vault_ns" -- vault write "auth/approle/role/$approle" token_policies="$approle" token_ttl=1h token_max_ttl=4h
## Get Role ID and Secret ID App Role for CloudBees CI Vault Plugin configuration
kubectl exec -it vault-0 -n "$vault_ns" -- vault read "auth/approle/role/$approle/role-id"
kubectl exec -it vault-0 -n "$vault_ns" -- vault write -force "auth/approle/role/$approle/secret-id"

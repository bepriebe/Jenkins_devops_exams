#!/usr/bin/env bash
set -eu

output="${1:-./jenkins-exam-kubeconfig}"
namespace="${K8S_NAMESPACE:-jenkins-exam-dev}"
server="${K8S_SERVER:-https://192.168.178.23:6443}"
service_account="jenkins-exam-deployer"
token_secret="jenkins-exam-deployer-token"

if ! command -v kubectl >/dev/null 2>&1; then
  echo "kubectl is required" >&2
  exit 1
fi

if ! kubectl -n "$namespace" get serviceaccount "$service_account" >/dev/null 2>&1; then
  echo "ServiceAccount $service_account is missing in $namespace; apply k8s/exam-rbac.yaml first" >&2
  exit 1
fi

umask 077
tmp_config=$(mktemp)
tmp_ca=$(mktemp)
trap 'rm -f "$tmp_config" "$tmp_ca"' EXIT

ca_data=$(kubectl config view --raw \
  -o jsonpath='{.clusters[0].cluster.certificate-authority-data}')
if [ -z "$ca_data" ]; then
  echo "Could not read the cluster CA from the current kubectl configuration" >&2
  exit 1
fi
printf '%s' "$ca_data" | base64 --decode > "$tmp_ca"

token=""
for _ in $(seq 1 30); do
  token=$(kubectl -n "$namespace" get secret "$token_secret" \
    -o jsonpath='{.data.token}' 2>/dev/null | base64 --decode || true)
  if [ -n "$token" ]; then
    break
  fi
  sleep 1
done

if [ -z "$token" ]; then
  echo "Secret $token_secret has no token; apply the bootstrap manifest and retry" >&2
  exit 1
fi

kubectl --kubeconfig="$tmp_config" config set-cluster jenkins-exam \
  --server="$server" \
  --certificate-authority="$tmp_ca" \
  --embed-certs=true >/dev/null
kubectl --kubeconfig="$tmp_config" config set-credentials "$service_account" \
  --token="$token" >/dev/null
kubectl --kubeconfig="$tmp_config" config set-context jenkins-exam \
  --cluster=jenkins-exam \
  --user="$service_account" \
  --namespace=jenkins-exam-dev >/dev/null
kubectl --kubeconfig="$tmp_config" config use-context jenkins-exam >/dev/null

mkdir -p "$(dirname "$output")"
mv "$tmp_config" "$output"
trap - EXIT
chmod 600 "$output"
echo "Created $output for $service_account; upload it to Jenkins as credential kubeconfig-exam."
printf 'deployments dev: '
kubectl --kubeconfig="$output" auth can-i create deployments -n jenkins-exam-dev
printf 'deployments prod: '
kubectl --kubeconfig="$output" auth can-i create deployments -n jenkins-exam-prod
printf 'namespaces: '
kubectl --kubeconfig="$output" auth can-i create namespaces
echo "Do not commit or print this file."

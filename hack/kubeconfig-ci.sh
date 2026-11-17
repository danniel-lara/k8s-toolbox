#!/usr/bin/env bash
# Gera um kubeconfig SOMENTE LEITURA para a pipeline, com um contexto por cluster.
#
# uso: hack/kubeconfig-ci.sh <contexto> [contexto...] > kubeconfig-ci.yaml
#
# Em cada cluster: cria o namespace/ServiceAccount/RBAC do k8s/toolbox.yaml (sem o Deployment)
# e um token de longa duração (k8s/ci-token.yaml). Usa o seu acesso atual de admin para isso.
# Depois cole o conteúdo do arquivo numa variável do GitLab do tipo File chamada KUBECONFIG
# e apague o arquivo local.
set -euo pipefail

[ $# -gt 0 ] || { echo "uso: $0 <contexto> [contexto...] > kubeconfig-ci.yaml" >&2; exit 1; }

DIR="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
files=()
n=0

for ctx in "$@"; do
  n=$((n + 1))
  echo "→ $ctx" >&2
  # -l '!app' aplica tudo do toolbox.yaml, menos o Deployment (único objeto com label app)
  kubectl --context "$ctx" apply -l '!app' -f "$DIR/k8s/toolbox.yaml" >&2
  kubectl --context "$ctx" apply -f "$DIR/k8s/ci-token.yaml" >&2

  token=""
  for _ in $(seq 1 20); do   # o controller leva alguns segundos para preencher o token
    token="$(kubectl --context "$ctx" -n toolbox get secret toolbox-ci-token \
      -o jsonpath='{.data.token}' 2>/dev/null | base64 -d || true)"
    [ -n "$token" ] && break
    sleep 1
  done
  [ -n "$token" ] || { echo "token não foi gerado em $ctx" >&2; exit 1; }

  ca="$(kubectl --context "$ctx" -n toolbox get secret toolbox-ci-token -o jsonpath='{.data.ca\.crt}')"
  cluster="$(kubectl config view -o jsonpath="{.contexts[?(@.name==\"$ctx\")].context.cluster}")"
  server="$(kubectl config view -o jsonpath="{.clusters[?(@.name==\"$cluster\")].cluster.server}")"
  case "$server" in
    *127.0.0.1*|*localhost*|*0.0.0.0*)
      echo "  aviso: $ctx aponta para $server; o runner do GitLab não vai alcançar esse endereço" >&2 ;;
  esac

  cat > "$TMP/$n.yaml" <<EOF
apiVersion: v1
kind: Config
clusters:
  - name: "$ctx"
    cluster:
      server: "$server"
      certificate-authority-data: "$ca"
users:
  - name: "$ctx-toolbox"
    user:
      token: "$token"
contexts:
  - name: "$ctx"
    context:
      cluster: "$ctx"
      user: "$ctx-toolbox"
EOF
  files+=("$TMP/$n.yaml")
done

KUBECONFIG="$(IFS=:; echo "${files[*]}")" kubectl config view --flatten > "$TMP/all.yaml"
kubectl --kubeconfig "$TMP/all.yaml" config use-context "$1" >/dev/null   # contexto padrão
cat "$TMP/all.yaml"

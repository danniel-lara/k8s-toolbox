# shellcheck shell=bash
# Funções comuns dos scripts k8s-*

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  RED=$'\e[31m'; GRN=$'\e[32m'; YEL=$'\e[33m'; CYN=$'\e[36m'
  BLD=$'\e[1m'; DIM=$'\e[2m'; RST=$'\e[0m'
else
  RED=; GRN=; YEL=; CYN=; BLD=; DIM=; RST=
fi

title()  { printf '\n%s%s━━ %s%s\n' "$BLD" "$CYN" "$*" "$RST"; }
ok()     { printf '  %s✔%s %s\n' "$GRN" "$RST" "$*"; }
warn()   { printf '  %s!%s %s\n' "$YEL" "$RST" "$*"; }
fail()   { printf '  %s✘%s %s\n' "$RED" "$RST" "$*"; }
hint()   { printf '    %s→ %s%s\n' "$DIM" "$*" "$RST"; }
indent() { sed 's/^/      /'; }

# report <rótulo> [fail|warn]
# Lê stdin: vazio = ok; senão mostra as linhas como problema. Retorna 1 se houve problema.
report() {
  local label="$1" level="${2:-fail}" out n
  out="$(sed '/^[[:space:]]*$/d')"
  if [ -z "$out" ]; then ok "$label: nenhum"; return 0; fi
  n="$(printf '%s\n' "$out" | wc -l | tr -d ' ')"
  "$level" "$label ($n)"
  printf '%s\n' "$out" | indent
  return 1
}

# Namespace atual: kubeconfig -> ServiceAccount do pod -> default
current_ns() {
  local ns sa=/var/run/secrets/kubernetes.io/serviceaccount/namespace
  ns="$(kubectl config view --minify -o jsonpath='{..namespace}' 2>/dev/null)"
  [ -z "$ns" ] && [ -r "$sa" ] && ns="$(cat "$sa")"
  echo "${ns:-default}"
}

# Domínio do cluster (cluster.local na maioria dos casos), lido do resolv.conf
cluster_domain() {
  local d
  d="$(awk '/^search/{for(i=2;i<=NF;i++) if($i ~ /^svc\./){sub(/^svc\./,"",$i); print $i; exit}}' /etc/resolv.conf 2>/dev/null)"
  echo "${d:-cluster.local}"
}

in_cluster() { [ -n "${KUBERNETES_SERVICE_HOST:-}" ]; }

# parse_args "$@"  ->  NS (vazio se não informado) e ARGS (posicionais)
parse_args() {
  NS=""; ARGS=()
  while [ $# -gt 0 ]; do
    case "$1" in
      -n|--namespace) NS="${2:?faltou o namespace depois de $1}"; shift 2 ;;
      --namespace=*)  NS="${1#*=}"; shift ;;
      -h|--help)      usage; exit 0 ;;
      *)              ARGS+=("$1"); shift ;;
    esac
  done
}

require_api() {
  if ! kubectl get --raw /version >/dev/null 2>&1; then
    fail "Sem acesso à API do Kubernetes."
    hint "Dentro do cluster: o pod precisa de um ServiceAccount com RBAC (veja k8s/toolbox.yaml)."
    hint "Fora do cluster: verifique seu kubeconfig (kubectl config current-context)."
    exit 2
  fi
}

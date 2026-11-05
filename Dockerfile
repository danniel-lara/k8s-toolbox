# syntax=docker/dockerfile:1

# ---------- Estágio 1: baixa os binários ----------
FROM alpine:3.20 AS fetch
ARG TARGETARCH
ARG KUBECTL_VERSION=v1.31.4
ARG HELM_VERSION=v3.16.3
ARG K9S_VERSION=v0.32.7
ARG STERN_VERSION=1.31.0
ARG YQ_VERSION=v4.44.6
ARG POPEYE_VERSION=v0.21.5
ARG KUBECTX_VERSION=v0.9.5
ARG GRPCURL_VERSION=1.9.2

RUN apk add --no-cache curl tar
WORKDIR /out
RUN set -eux; \
    case "${TARGETARCH}" in \
      amd64) ALT=x86_64 ;; \
      arm64) ALT=arm64 ;; \
      *) echo "arquitetura não suportada: ${TARGETARCH}"; exit 1 ;; \
    esac; \
    GH=https://github.com; \
    curl -fsSLo kubectl "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${TARGETARCH}/kubectl"; \
    curl -fsSL "https://get.helm.sh/helm-${HELM_VERSION}-linux-${TARGETARCH}.tar.gz" | tar xz --strip-components=1 "linux-${TARGETARCH}/helm"; \
    curl -fsSL "$GH/derailed/k9s/releases/download/${K9S_VERSION}/k9s_Linux_${TARGETARCH}.tar.gz" | tar xz k9s; \
    curl -fsSL "$GH/stern/stern/releases/download/v${STERN_VERSION}/stern_${STERN_VERSION}_linux_${TARGETARCH}.tar.gz" | tar xz stern; \
    curl -fsSL "$GH/derailed/popeye/releases/download/${POPEYE_VERSION}/popeye_linux_${TARGETARCH}.tar.gz" | tar xz popeye; \
    curl -fsSL "$GH/ahmetb/kubectx/releases/download/${KUBECTX_VERSION}/kubens_${KUBECTX_VERSION}_linux_${ALT}.tar.gz" | tar xz kubens; \
    curl -fsSL "$GH/fullstorydev/grpcurl/releases/download/v${GRPCURL_VERSION}/grpcurl_${GRPCURL_VERSION}_linux_${ALT}.tar.gz" | tar xz grpcurl; \
    curl -fsSLo yq "$GH/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_${TARGETARCH}"; \
    chmod +x ./*

# ---------- Estágio 2: imagem final ----------
FROM alpine:3.20
LABEL org.opencontainers.image.title="k8s-toolbox" \
      org.opencontainers.image.description="Toolbox de troubleshooting para Kubernetes"

RUN apk add --no-cache \
      bash bash-completion ncurses less util-linux-misc coreutils \
      curl jq bind-tools netcat-openbsd openssl ca-certificates \
      iproute2 iputils tcpdump tzdata

COPY --from=fetch /out/ /usr/local/bin/
COPY lib/ /usr/local/lib/k8s-toolbox/
COPY bin/ /usr/local/bin/
COPY bashrc /etc/k8s-toolbox/bashrc

RUN chmod +x /usr/local/bin/k8s-* \
 && echo '. /etc/k8s-toolbox/bashrc' >> /etc/bash/bashrc \
 && kubectl completion bash > /usr/share/bash-completion/completions/kubectl \
 && helm completion bash > /usr/share/bash-completion/completions/helm \
 && stern --completion bash > /usr/share/bash-completion/completions/stern

# USER é exigido pelo popeye/k9s (binários Go sem cgo)
ENV TZ=America/Sao_Paulo \
    USER=toolbox
WORKDIR /tmp
# A imagem roda como root por padrão (necessário para tcpdump e debug de node).
# No Deployment fixo, o securityContext força um usuário sem privilégios.
CMD ["sleep", "infinity"]

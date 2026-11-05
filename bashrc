# Carregado por shells bash interativos (via /etc/bash/bashrc)
case $- in *i*) ;; *) return 0 ;; esac

[ -r /usr/share/bash-completion/bash_completion ] && . /usr/share/bash-completion/bash_completion
[ -r /usr/share/bash-completion/completions/kubectl ] && . /usr/share/bash-completion/completions/kubectl

alias k=kubectl
complete -o default -F __start_kubectl k 2>/dev/null
alias ll='ls -lah'

# HOME gravável mesmo rodando como usuário sem home (kubectl/k9s/helm criam cache)
[ -w "${HOME:-/nonexistent}" ] || export HOME=/tmp

__k8s_ns() { kubectl config view --minify -o jsonpath='{..namespace}' 2>/dev/null || true; }
PS1='\[\e[36m\]k8s-toolbox\[\e[0m\] \[\e[2m\]$(__k8s_ns)\[\e[0m\] \w \$ '

[ -z "${K8S_TOOLBOX_QUIET:-}" ] && k8s-help

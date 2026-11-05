# k8s-toolbox

Imagem de troubleshooting **focada em Kubernetes** (na linha do netshoot, só que para K8s):
traz `kubectl`, `helm`, `k9s`, `stern`, `popeye`, `kubens`, `yq/jq`, ferramentas de rede
(`dig`, `curl`, `nc`, `grpcurl`, `tcpdump`) e **scripts que diagnosticam os problemas mais comuns**.

| Comando | O que responde | Problemas cobertos |
|---|---|---|
| `k8s-doctor [-n ns]` | O que está quebrado no cluster agora? | CrashLoopBackOff, ImagePullBackOff, Pending, OOMKilled, readiness, deployments incompletos, services/ingress sem endpoints, PVC, nodes, CoreDNS, CPU/memória, boas práticas |
| `k8s-pod <pod> [-n ns]` | Por que este pod não sobe? | estado de cada container, significado do exit code, dica de correção, resources/probes, eventos, logs `--previous` |
| `k8s-svc <svc> [-n ns]` | Por que o Service/Ingress não responde? | selector × labels, pods prontos, targetPort × porta do container, EndpointSlices, DNS, TCP, NetworkPolicy, Ingress |
| `k8s-dns [nome]` | O DNS está funcionando? | resolv.conf, CoreDNS, resolução interna/externa, **cada réplica** do CoreDNS, erros nos logs |
| `k8s-node [node]` | Os nodes estão saudáveis? | NotReady, pressão de memória/disco/PID, cordon, taints, recursos alocados |

O `k8s-doctor` sai com código 1 quando encontra problema, então dá pra usar em CronJob/CI.

## Build

```bash
make build                                   # imagem local k8s-toolbox:dev
make push IMAGE=ghcr.io/<usuario>/k8s-toolbox VERSION=1.0.0   # multi-arch (amd64+arm64)
```

Ou via GitHub Actions: `git tag v1.0.0 && git push --tags` publica em `ghcr.io/<usuario>/<repo>`.

> Mac com Apple Silicon: o `make push` já gera amd64 e arm64. Se fizer `docker build` simples
> e mandar pra um cluster x86, o pod falha com `exec format error`.

## 3 formas de usar

**1. Pod temporário** (some quando você sai). O ServiceAccount `toolbox` dá permissão de leitura ao kubectl:

```bash
kubectl run tb --rm -it -n toolbox --image=ghcr.io/<usuario>/k8s-toolbox:1.0.0 \
  --overrides='{"spec":{"serviceAccountName":"toolbox"}}' -- bash
```

Para testar rede/NetworkPolicy *de dentro de outro namespace*, rode no namespace da aplicação
(sem `--overrides`; o kubectl não terá permissão, mas dig/curl/nc funcionam).

**2. Grudado num pod com problema** (compartilha rede e processos — ótimo para imagens distroless):

```bash
kubectl debug -it <pod> -n <ns> --image=ghcr.io/<usuario>/k8s-toolbox:1.0.0 --target=<container>
```

Debug de node (NotReady, kubelet, disco):

```bash
kubectl debug node/<node> -it --profile=sysadmin --image=ghcr.io/<usuario>/k8s-toolbox:1.0.0
chroot /host
systemctl status kubelet; journalctl -u kubelet --since "15 min ago"
```

**3. Fixa no cluster** (namespace `toolbox`, somente leitura, sem root):

```bash
make deploy IMAGE=ghcr.io/<usuario>/k8s-toolbox VERSION=1.0.0
make doctor        # roda k8s-doctor
make exec          # abre o shell
```

## Segurança

- O RBAC é **somente leitura** (`view` + nodes/PV/storageclasses/métricas). Não lê `secrets`.
  O `view` lê `configmaps`; se isso for sensível no seu cluster, troque por um ClusterRole próprio.
- No Deployment fixo a imagem roda como UID 1000 sem capabilities → `tcpdump`/`ping` não funcionam ali;
  use `kubectl run`/`kubectl debug` (rodam como root) quando precisar deles.
- Quando não estiver usando: `kubectl scale -n toolbox deploy/toolbox --replicas=0`.

## Atualizar versões das ferramentas

As versões ficam nos `ARG` do topo do [Dockerfile](Dockerfile). Dá pra sobrescrever no build:

```bash
docker build --build-arg KUBECTL_VERSION=v1.32.0 -t k8s-toolbox:dev .
```

Mantenha o `kubectl` no máximo uma versão minor de distância do seu cluster.

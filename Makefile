IMAGE   ?= ghcr.io/SEU_USUARIO/k8s-toolbox
VERSION ?= 1.0.0
PLATFORMS ?= linux/amd64,linux/arm64

.PHONY: build shell push deploy exec doctor undeploy

build:            ## build local (arquitetura da sua máquina)
	docker build -t $(IMAGE):$(VERSION) -t k8s-toolbox:dev .

shell: build      ## abre a toolbox localmente usando seu ~/.kube/config
	docker run --rm -it -v $(HOME)/.kube:/root/.kube:ro --network host k8s-toolbox:dev bash

push:             ## build multi-arquitetura e envia para o registry
	docker buildx build --platform $(PLATFORMS) -t $(IMAGE):$(VERSION) -t $(IMAGE):latest --push .

deploy:           ## instala a toolbox fixa no cluster (namespace toolbox)
	sed 's#image: k8s-toolbox:dev.*#image: $(IMAGE):$(VERSION)#' k8s/toolbox.yaml | kubectl apply -f -

exec:             ## entra na toolbox fixa
	kubectl exec -it -n toolbox deploy/toolbox -- bash

doctor:           ## roda o k8s-doctor na toolbox fixa
	kubectl exec -it -n toolbox deploy/toolbox -- k8s-doctor

undeploy:
	kubectl delete -f k8s/toolbox.yaml

INCLUDE_DIR=make
NAME=directus
NAMESPACE=default
#TODO (bdegeeter): support azure, aws, gcp and local (kind)
CLOUD=local
KIND_INGRESS_DIR=deploy/k8s-ingress-nginx/overlays/kind/default-ingress-secret
KIND_INGRESS_CRT=$(KIND_INGRESS_DIR)/kind-tls.crt
KIND_INGRESS_KEY=$(KIND_INGRESS_DIR)/kind-tls.key
KIND_INGRESS_DOMAIN=directus.localtest.me

include $(INCLUDE_DIR)/Makefile.tools

$(KIND_INGRESS_CRT): $(KIND_INGRESS_KEY)
	openssl req -new -x509 -key $(KIND_INGRESS_KEY) -out $(KIND_INGRESS_CRT) -days 365 -subj "/CN=$(KIND_INGRESS_DOMAIN)"

$(KIND_INGRESS_KEY):
	openssl genpkey -algorithm RSA -out $(KIND_INGRESS_KEY) -pkeyopt rsa_keygen_bits:2048

.PHONY: deploy
deploy: | $(if $(findstring $(CLOUD),local), $(KIND_INGRESS_CRT) kind-create-cluster)
	@echo "\ndeploy nginx-ingress to $(CLOUD)"
	$(KCTL_CMD) apply -k deploy/k8s-ingress-nginx/overlays/kind
	$(KCTL_CMD) wait deployment -n nginx-ingress ingress-nginx-controller --for condition=Available=True --timeout=600s

	@echo "\ndeploy cert-manager to $(CLOUD)"
	$(KCTL_CMD) apply -k deploy/cert-manager/overlays/kind
	$(KCTL_CMD) wait deployment -n cert-manager cert-manager cert-manager-webhook --for condition=Available=True --timeout=600s

	@echo "\ndeploy directus to $(CLOUD)"
	# Double deploy to load CRDs if they are being loaded for the first time
	$(KCTL_CMD) apply -k deploy/$(CLOUD)
	$(KCTL_CMD) wait deployment -n $(NAMESPACE) directus-deployment --for condition=Available=True --timeout=600s
ifeq ($(CLOUD),local)
	@echo
	@echo "Use https://$(KIND_INGRESS_DOMAIN) to access WebUI"
	@echo
endif

.PHONY: k9s
k9s: | $(K9S)
	$(K9S_CMD)

.PHONY: clean
clean: | clean-tools

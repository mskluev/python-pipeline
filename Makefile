ENV ?= dev
SERVICES ?= data_processor metadata_fetcher
COMMIT_SHA ?= $(shell git rev-parse HEAD 2>/dev/null || echo "latest")
ARTIFACT_BUCKET ?= mskluev-test
TF_DIR := infrastructure/environments/$(ENV)

.PHONY: all
all: build-lambdas push-lambdas tf-deploy

.PHONY: build-lambdas
build-lambdas:
	@for service in $(SERVICES); do \
		echo "Building $$service..."; \
		rm -rf services/$$service/package services/$$service/$$service-$(COMMIT_SHA).zip; \
		mkdir -p services/$$service/package; \
		pip install -r services/$$service/requirements.txt --target services/$$service/package; \
		if [ -d "services/$$service/src" ]; then cp -r services/$$service/src/* services/$$service/package/; fi; \
		cd services/$$service/package && zip -qr ../$$service-$(COMMIT_SHA).zip . && cd ../../..; \
		echo "Successfully built services/$$service/$$service-$(COMMIT_SHA).zip"; \
	done

.PHONY: push-lambdas
push-lambdas:
	@for service in $(SERVICES); do \
		if [ ! -f "services/$$service/$$service-$(COMMIT_SHA).zip" ]; then \
			echo "Error: services/$$service/$$service-$(COMMIT_SHA).zip not found. Run 'make build-lambdas' first."; \
			exit 1; \
		fi; \
		echo "Pushing $$service..."; \
		aws s3 cp services/$$service/$$service-$(COMMIT_SHA).zip s3://$(ARTIFACT_BUCKET)/test-pipeline/$$service/$$service-$(COMMIT_SHA).zip; \
	done

.PHONY: tf-init
tf-init:
	cd $(TF_DIR) && terraform init

.PHONY: tf-plan
tf-plan: tf-init
	cd $(TF_DIR) && terraform plan -var="commit_sha=$(COMMIT_SHA)" -var-file="$(ENV).tfvars"

.PHONY: tf-deploy
tf-deploy: tf-init
	cd $(TF_DIR) && terraform apply -var="commit_sha=$(COMMIT_SHA)" -var-file="$(ENV).tfvars" -auto-approve

.PHONY: tf-destroy
tf-destroy: tf-init
	cd $(TF_DIR) && terraform destroy -var="commit_sha=$(COMMIT_SHA)" -var-file="$(ENV).tfvars" -auto-approve

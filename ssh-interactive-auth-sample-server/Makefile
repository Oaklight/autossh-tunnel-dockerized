# Makefile for ssh-interactive-auth-sample-server

# Image name
IMAGE_NAME = ssh-interactive-auth-sample-server
TAG = latest

# Registry mirror (optional)
REGISTRY_MIRROR ?= docker.io

# Build arguments
BUILD_ARGS = --build-arg REGISTRY_MIRROR=$(REGISTRY_MIRROR)

.PHONY: all build up down clean logs shell help

all: build

build: ## Build the Docker image
	docker build $(BUILD_ARGS) -t $(IMAGE_NAME):$(TAG) .

up: ## Start the container using docker-compose
	REGISTRY_MIRROR=$(REGISTRY_MIRROR) docker compose up -d --build

down: ## Stop and remove the container
	docker compose down

clean: down ## Clean up resources
	docker rmi $(IMAGE_NAME):$(TAG) || true

logs: ## View container logs
	docker compose logs -f

shell: ## Enter the container shell
	docker compose exec ssh-server bash

help: ## Show this help message
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'
	@echo ""
	@echo "Variables:"
	@echo "  REGISTRY_MIRROR  Docker registry mirror (default: docker.io)"
# Variables
IMAGE_NAME_AUTOSSH = oaklight/autossh-tunnel
IMAGE_TAG_AUTOSSH = latest
ADDITIONAL_TAGS_AUTOSSH = v2.0.0
PLATFORMS_AUTOSSH = linux/amd64,linux/arm64/v8,linux/arm/v7,linux/arm/v6,linux/386,linux/ppc64le,linux/s390x,linux/riscv64

IMAGE_NAME_WEB = oaklight/autossh-tunnel-web-panel
IMAGE_TAG_WEB = latest
ADDITIONAL_TAGS_WEB = v2.0.0
PLATFORMS_WEB = linux/amd64,linux/arm64/v8,linux/arm/v7,linux/arm/v6,linux/386,linux/ppc64le,linux/s390x,linux/riscv64

# Registry mirror and proxy support
REGISTRY_MIRROR ?= docker.io
GOPROXY ?=

BUILD_ARGS = --build-arg REGISTRY_MIRROR=$(REGISTRY_MIRROR)

ifneq ($(GOPROXY),)
BUILD_ARGS += --build-arg GOPROXY=$(GOPROXY)
endif

# Default target
all: build-and-push-autossh build-and-push-web

# Build the multi-arch autossh-tunnel image (cache only, no push)
build-autossh:
	@echo "Building multi-arch Docker image for autossh-tunnel (cache only)..."
	@echo "Tags: $(IMAGE_NAME_AUTOSSH):$(IMAGE_TAG_AUTOSSH), $(ADDITIONAL_TAGS_AUTOSSH)"
	@echo "Using registry mirror: $(REGISTRY_MIRROR)"
	docker buildx build --platform $(PLATFORMS_AUTOSSH) \
		$(BUILD_ARGS) \
		-t $(IMAGE_NAME_AUTOSSH):$(IMAGE_TAG_AUTOSSH) \
		$(foreach tag, $(ADDITIONAL_TAGS_AUTOSSH), -t $(IMAGE_NAME_AUTOSSH):$(tag)) \
		.

# Build the multi-arch web-panel image (cache only, no push)
build-web:
	@echo "Building multi-arch Docker image for web-panel (cache only)..."
	@echo "Tags: $(IMAGE_NAME_WEB):$(IMAGE_TAG_WEB), $(ADDITIONAL_TAGS_WEB)"
	@echo "Using registry mirror: $(REGISTRY_MIRROR)"
	docker buildx build --platform $(PLATFORMS_WEB) \
		$(BUILD_ARGS) \
		-f Dockerfile.web \
		-t $(IMAGE_NAME_WEB):$(IMAGE_TAG_WEB) \
		$(foreach tag, $(ADDITIONAL_TAGS_WEB), -t $(IMAGE_NAME_WEB):$(tag)) \
		.

# Build both images (cache only)
build: build-autossh build-web
	@echo "Both images built and cached successfully!"

# Push the autossh-tunnel image from cache to Docker Hub
push-autossh:
	@echo "Pushing autossh-tunnel image from cache to Docker Hub..."
	@echo "Tags: $(IMAGE_NAME_AUTOSSH):$(IMAGE_TAG_AUTOSSH), $(ADDITIONAL_TAGS_AUTOSSH)"
	docker buildx build --platform $(PLATFORMS_AUTOSSH) \
		$(BUILD_ARGS) \
		-t $(IMAGE_NAME_AUTOSSH):$(IMAGE_TAG_AUTOSSH) \
		$(foreach tag, $(ADDITIONAL_TAGS_AUTOSSH), -t $(IMAGE_NAME_AUTOSSH):$(tag)) \
		--push .

# Push the web-panel image from cache to Docker Hub
push-web:
	@echo "Pushing web-panel image from cache to Docker Hub..."
	@echo "Tags: $(IMAGE_NAME_WEB):$(IMAGE_TAG_WEB), $(ADDITIONAL_TAGS_WEB)"
	docker buildx build --platform $(PLATFORMS_WEB) \
		$(BUILD_ARGS) \
		-f Dockerfile.web \
		-t $(IMAGE_NAME_WEB):$(IMAGE_TAG_WEB) \
		$(foreach tag, $(ADDITIONAL_TAGS_WEB), -t $(IMAGE_NAME_WEB):$(tag)) \
		--push .

# Push both images from cache
push: push-autossh push-web
	@echo "Both images pushed successfully!"

# Build and push autossh-tunnel in one step
build-and-push-autossh: build-autossh push-autossh

# Build and push web-panel in one step
build-and-push-web: build-web push-web

# Build a single-arch (amd64) autossh-tunnel image for local development and testing
build-test-autossh:
	@echo "Building amd64 Docker image for local testing of autossh-tunnel with tag: $(IMAGE_NAME_AUTOSSH):$(IMAGE_TAG_AUTOSSH)..."
	@echo "Using registry mirror: $(REGISTRY_MIRROR)"
	docker buildx build --platform linux/amd64 \
		$(BUILD_ARGS) \
		-t $(IMAGE_NAME_AUTOSSH):$(IMAGE_TAG_AUTOSSH) \
		--load .

# Build a single-arch (amd64) web-panel image for local development and testing
build-test-web:
	@echo "Building amd64 Docker image for local testing of web-panel with tag: $(IMAGE_NAME_WEB):$(IMAGE_TAG_WEB)..."
	@echo "Using registry mirror: $(REGISTRY_MIRROR)"
	docker buildx build --platform linux/amd64 \
		$(BUILD_ARGS) \
		-f Dockerfile.web \
		-t $(IMAGE_NAME_WEB):$(IMAGE_TAG_WEB) \
		--load .

# Build both autossh and web test images for local development
build-test: build-test-autossh build-test-web
	@echo "Both autossh-tunnel and web-panel test images built successfully!"

# Clean up local Docker images for both autossh-tunnel and web-panel
clean:
	@echo "Cleaning up local Docker images..."
	docker rmi $(IMAGE_NAME_AUTOSSH):$(IMAGE_TAG_AUTOSSH) $(foreach tag, $(ADDITIONAL_TAGS_AUTOSSH), $(IMAGE_NAME_AUTOSSH):$(tag)) || true
	docker rmi $(IMAGE_NAME_WEB):$(IMAGE_TAG_WEB) $(foreach tag, $(ADDITIONAL_TAGS_WEB), $(IMAGE_NAME_WEB):$(tag)) || true

# Clean up build cache
clean-cache:
	@echo "Cleaning up Docker build cache..."
	docker buildx prune -f

# Help target to show available commands
help:
	@echo "Available targets:"
	@echo ""
	@echo "  Build (cache only, no push):"
	@echo "    build-autossh      - Build multi-arch autossh-tunnel image"
	@echo "    build-web          - Build multi-arch web-panel image"
	@echo "    build              - Build both images"
	@echo ""
	@echo "  Push (from cache):"
	@echo "    push-autossh       - Push autossh-tunnel image to Docker Hub"
	@echo "    push-web           - Push web-panel image to Docker Hub"
	@echo "    push               - Push both images"
	@echo ""
	@echo "  Build and Push:"
	@echo "    build-and-push-autossh - Build and push autossh-tunnel"
	@echo "    build-and-push-web     - Build and push web-panel"
	@echo "    all                    - Build and push both (default)"
	@echo ""
	@echo "  Local Testing (amd64 only):"
	@echo "    build-test-autossh - Build autossh-tunnel for local testing"
	@echo "    build-test-web     - Build web-panel for local testing"
	@echo "    build-test         - Build both for local testing"
	@echo ""
	@echo "  Cleanup:"
	@echo "    clean              - Clean up local Docker images"
	@echo "    clean-cache        - Clean up build cache"
	@echo ""
	@echo "Environment variables:"
	@echo "  REGISTRY_MIRROR    - Docker registry mirror (default: docker.io)"
	@echo "                       Example: REGISTRY_MIRROR=docker.1ms.run make build"
	@echo "  GOPROXY            - Go proxy for building (e.g., https://goproxy.cn)"
	@echo "                       Example: GOPROXY=https://goproxy.cn make build-web"

.PHONY: all build-autossh build-web build push-autossh push-web push build-and-push-autossh build-and-push-web build-test-autossh build-test-web build-test clean clean-cache help
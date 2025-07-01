# Variables
IMAGE_NAME_AUTOSSH = oaklight/autossh-tunnel
IMAGE_TAG_AUTOSSH = latest
ADDITIONAL_TAGS_AUTOSSH = v1.6.1
PLATFORMS_AUTOSSH = linux/amd64,linux/arm64/v8,linux/arm/v7,linux/arm/v6,linux/386,linux/ppc64le,linux/s390x,linux/riscv64

IMAGE_NAME_WEB = oaklight/autossh-tunnel-web-panel
IMAGE_TAG_WEB = latest
ADDITIONAL_TAGS_WEB = v1.6.1
PLATFORMS_WEB = linux/amd64,linux/arm64/v8,linux/arm/v7,linux/arm/v6,linux/386,linux/ppc64le,linux/s390x,linux/riscv64

# Default target
all: push-autossh push-web

# Build the multi-arch autossh-tunnel image with multiple tags and push
build-autossh:
	@echo "Building and pushing multi-arch Docker image for autossh-tunnel with tags: $(IMAGE_NAME_AUTOSSH):$(IMAGE_TAG_AUTOSSH) and additional tags: $(ADDITIONAL_TAGS_AUTOSSH)..."
	docker buildx build --platform $(PLATFORMS_AUTOSSH) \
		-t $(IMAGE_NAME_AUTOSSH):$(IMAGE_TAG_AUTOSSH) \
		$(foreach tag, $(ADDITIONAL_TAGS_AUTOSSH), -t $(IMAGE_NAME_AUTOSSH):$(tag)) \
		.

# Build the multi-arch web-panel image with multiple tags and push
build-web:
	@echo "Building and pushing multi-arch Docker image for web-panel with tags: $(IMAGE_NAME_WEB):$(IMAGE_TAG_WEB) and additional tags: $(ADDITIONAL_TAGS_WEB)..."
	docker buildx build --platform $(PLATFORMS_WEB) \
		-f Dockerfile.web \
		-t $(IMAGE_NAME_WEB):$(IMAGE_TAG_WEB) \
		$(foreach tag, $(ADDITIONAL_TAGS_WEB), -t $(IMAGE_NAME_WEB):$(tag)) \
		.

# Push the multi-arch autossh-tunnel image to Docker Hub (only if already built)
push-autossh:
	@echo "Pushing multi-arch Docker image for autossh-tunnel to Docker Hub with tags: $(IMAGE_NAME_AUTOSSH):$(IMAGE_TAG_AUTOSSH) and additional tags: $(ADDITIONAL_TAGS_AUTOSSH)..."
	docker buildx build --platform $(PLATFORMS_AUTOSSH) \
		-t $(IMAGE_NAME_AUTOSSH):$(IMAGE_TAG_AUTOSSH) \
		$(foreach tag, $(ADDITIONAL_TAGS_AUTOSSH), -t $(IMAGE_NAME_AUTOSSH):$(tag)) \
		--push .

# Push the multi-arch web-panel image to Docker Hub (only if already built)
push-web:
	@echo "Pushing multi-arch Docker image for web-panel to Docker Hub with tags: $(IMAGE_NAME_WEB):$(IMAGE_TAG_WEB) and additional tags: $(ADDITIONAL_TAGS_WEB)..."
	docker buildx build --platform $(PLATFORMS_WEB) \
		-f Dockerfile.web \
		-t $(IMAGE_NAME_WEB):$(IMAGE_TAG_WEB) \
		$(foreach tag, $(ADDITIONAL_TAGS_WEB), -t $(IMAGE_NAME_WEB):$(tag)) \
		--push .

# Build a single-arch (amd64) autossh-tunnel image for local development and testing
build-test-autossh:
	@echo "Building amd64 Docker image for local testing of autossh-tunnel with tag: $(IMAGE_NAME_AUTOSSH):$(IMAGE_TAG_AUTOSSH)..."
	docker buildx build --platform linux/amd64 \
		-t $(IMAGE_NAME_AUTOSSH):$(IMAGE_TAG_AUTOSSH) \
		--load .

# Build a single-arch (amd64) web-panel image for local development and testing
build-test-web:
	@echo "Building amd64 Docker image for local testing of web-panel with tag: $(IMAGE_NAME_WEB):$(IMAGE_TAG_WEB)..."
	docker buildx build --platform linux/amd64 \
		-f Dockerfile.web \
		-t $(IMAGE_NAME_WEB):$(IMAGE_TAG_WEB) \
		--load .

# Clean up local Docker images for both autossh-tunnel and web-panel
clean:
	@echo "Cleaning up local Docker images..."
	docker rmi $(IMAGE_NAME_AUTOSSH):$(IMAGE_TAG_AUTOSSH) $(foreach tag, $(ADDITIONAL_TAGS_AUTOSSH), $(IMAGE_NAME_AUTOSSH):$(tag)) || true
	docker rmi $(IMAGE_NAME_WEB):$(IMAGE_TAG_WEB) $(foreach tag, $(ADDITIONAL_TAGS_WEB), $(IMAGE_NAME_WEB):$(tag)) || true

# Help target to show available commands
help:
	@echo "Available targets:"
	@echo "  build-autossh     - Build and push the multi-arch autossh-tunnel Docker image"
	@echo "  build-web         - Build and push the multi-arch web-panel Docker image"
	@echo "  push-autossh      - Push the multi-arch autossh-tunnel Docker image to Docker Hub (only if already built)"
	@echo "  push-web          - Push the multi-arch web-panel Docker image to Docker Hub (only if already built)"
	@echo "  build-test-autossh - Build a single-arch (amd64) autossh-tunnel Docker image for local testing"
	@echo "  build-test-web    - Build a single-arch (amd64) web-panel Docker image for local testing"
	@echo "  clean             - Clean up local Docker images for both autossh-tunnel and web-panel"
	@echo "  help              - Show this help message"

.PHONY: all build-autossh build-web push-autossh push-web build-test-autossh build-test-web clean help

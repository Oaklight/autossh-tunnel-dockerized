# Variables
IMAGE_NAME = oaklight/autossh-tunnel
IMAGE_TAG = latest
ADDITIONAL_TAGS = v1.2.0
PLATFORMS = linux/amd64,linux/arm64/v8,linux/arm/v7,linux/arm/v6,linux/386,linux/ppc64le,linux/s390x,linux/riscv64

# Default target
all: build

# Build the multi-arch image with multiple tags and push
build:
	@echo "Building and pushing multi-arch Docker image with tags: $(IMAGE_NAME):$(IMAGE_TAG) and additional tags: $(ADDITIONAL_TAGS)..."
	docker buildx build --platform $(PLATFORMS) \
		-t $(IMAGE_NAME):$(IMAGE_TAG) \
		$(foreach tag, $(ADDITIONAL_TAGS), -t $(IMAGE_NAME):$(tag)) .

# Push the multi-arch image to Docker Hub (only if already built)
push:
	@echo "Pushing multi-arch Docker image to Docker Hub with tags: $(IMAGE_NAME):$(IMAGE_TAG) and additional tags: $(ADDITIONAL_TAGS)..."
	docker buildx build --platform $(PLATFORMS) \
		-t $(IMAGE_NAME):$(IMAGE_TAG) \
		$(foreach tag, $(ADDITIONAL_TAGS), -t $(IMAGE_NAME):$(tag)) \
		--push .

# Clean up local Docker images
clean:
	@echo "Cleaning up local Docker images..."
	docker rmi $(IMAGE_NAME):$(IMAGE_TAG) $(foreach tag, $(ADDITIONAL_TAGS), $(IMAGE_NAME):$(tag)) || true

# Help target to show available commands
help:
	@echo "Available targets:"
	@echo "  build       - Build and push the multi-arch Docker image"
	@echo "  push        - Push the multi-arch Docker image to Docker Hub (only if already built)"
	@echo "  clean       - Clean up local Docker images"
	@echo "  help        - Show this help message"

.PHONY: all build push clean help
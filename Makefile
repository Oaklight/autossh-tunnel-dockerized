# Zensical Documentation Build Script
#

ZENSICAL      ?= zensical
SOURCEDIR     = docs
BUILDDIR      = site

help:
	@echo "Available targets:"
	@echo "  clean  - Remove build artifacts"
	@echo "  html   - Build HTML documentation"
	@echo "  serve  - Build and locally serve documentation"
	@echo "  live   - Live reload server for development"

.PHONY: help clean html serve live

clean:
	@echo "Cleaning build directory..."
	@rm -rf $(BUILDDIR)

html: clean
	@echo "Building HTML documentation..."
	@$(ZENSICAL) build

serve: html
	@echo "Serving documentation at http://localhost:8000"
	@cd $(BUILDDIR) && python -m http.server 8000

live:
	@echo "Starting live documentation server..."
	@$(ZENSICAL) serve

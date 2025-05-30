.PHONY: all build run clean stop release help

# Default target
all: run

# Build the app
build:
	@./run.sh --no-launch

# Build and run the app
run:
	@./run.sh

# Clean build
clean:
	@echo "Cleaning build directory..."
	@rm -rf .build
	@rm -rf build
	@echo "Clean complete"

# Stop the running app
stop:
	@./stop.sh

# Build release version
release:
	@./run.sh --release

# Build clean
rebuild: clean build

# Show help
help:
	@echo "Dragoboo Makefile"
	@echo "================"
	@echo "Available targets:"
	@echo "  make         - Build and run the app (default)"
	@echo "  make build   - Build the app without running"
	@echo "  make run     - Build and run the app"
	@echo "  make clean   - Clean build directory"
	@echo "  make stop    - Stop the running app"
	@echo "  make release - Build release version"
	@echo "  make rebuild - Clean and rebuild"
	@echo "  make help    - Show this help message"
.PHONY: help setup start stop restart logs clean build validate

# Default target
help:
	@echo "CloudOps Monitor - Available Commands"
	@echo "======================================"
	@echo "setup     - Create necessary directories and files"
	@echo "start     - Start all services"
	@echo "stop      - Stop all services"
	@echo "restart   - Restart all services"
	@echo "logs      - View logs from all services"
	@echo "clean     - Remove all containers and volumes"
	@echo "build     - Build custom Docker images"
	@echo "validate  - Validate configurations"
	@echo "status    - Show status of all services"

# Setup project directories
setup:
	@echo "Setting up CloudOps Monitor..."
	@mkdir -p prometheus/rules
	@mkdir -p grafana/provisioning/datasources
	@mkdir -p grafana/provisioning/dashboards
	@mkdir -p grafana-dashboards
	@mkdir -p alertmanager
	@mkdir -p exporters/aws-cost-exporter
	@if [ ! -f .env ]; then cp .env.example .env; echo "Created .env file - please configure your credentials"; fi
	@echo "Setup complete! Please configure your .env file before starting."

# Start all services
start:
	@echo "Starting CloudOps Monitor..."
	@docker-compose up -d
	@echo "Services started successfully!"
	@echo ""
	@echo "Access points:"
	@echo "  Grafana:        http://localhost:3000 (admin/admin)"
	@echo "  Prometheus:     http://localhost:9090"
	@echo "  AlertManager:   http://localhost:9093"
	@echo ""

# Stop all services
stop:
	@echo "Stopping CloudOps Monitor..."
	@docker-compose down
	@echo "Services stopped."

# Restart all services
restart: stop start

# View logs
logs:
	@docker-compose logs -f

# Clean everything (including volumes)
clean:
	@echo "WARNING: This will remove all containers, volumes, and data!"
	@read -p "Are you sure? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		docker-compose down -v; \
		echo "Cleanup complete."; \
	else \
		echo "Cleanup cancelled."; \
	fi

# Build custom images
build:
	@echo "Building custom Docker images..."
	@docker-compose build
	@echo "Build complete."

# Validate Prometheus configuration
validate:
	@echo "Validating configurations..."
	@docker run --rm -v $(PWD)/prometheus:/etc/prometheus prom/prometheus:v2.47.0 promtool check config /etc/prometheus/prometheus.yml
	@docker run --rm -v $(PWD)/prometheus/rules:/etc/prometheus/rules prom/prometheus:v2.47.0 promtool check rules /etc/prometheus/rules/*.yml
	@docker run --rm -v $(PWD)/alertmanager:/etc/alertmanager prom/alertmanager:v0.26.0 amtool check-config /etc/alertmanager/config.yml
	@echo "Validation complete!"

# Show status of services
status:
	@docker-compose ps

# Open Grafana in browser
open-grafana:
	@open http://localhost:3000 || xdg-open http://localhost:3000 || echo "Please open http://localhost:3000 in your browser"

# Open Prometheus in browser
open-prometheus:
	@open http://localhost:9090 || xdg-open http://localhost:9090 || echo "Please open http://localhost:9090 in your browser"

# Backup Grafana dashboards
backup-dashboards:
	@echo "Backing up Grafana dashboards..."
	@mkdir -p backups
	@docker exec cloudops-grafana grafana-cli admin data-migration export --path=/var/lib/grafana/backups
	@docker cp cloudops-grafana:/var/lib/grafana/backups backups/grafana-$(shell date +%Y%m%d-%H%M%S)
	@echo "Backup complete!"

# Test AWS credentials
test-aws:
	@echo "Testing AWS credentials..."
	@docker-compose run --rm aws-cost-exporter python -c "import boto3; ce = boto3.client('ce'); print('AWS credentials are valid!')"

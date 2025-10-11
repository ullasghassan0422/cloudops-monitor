#!/bin/bash
# setup.sh - Quick setup script for CloudOps Monitor

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}"
echo "╔════════════════════════════════════════╗"
echo "║   CloudOps Monitor Setup Script       ║"
echo "╚════════════════════════════════════════╝"
echo -e "${NC}"

# Check prerequisites
echo -e "${YELLOW}Checking prerequisites...${NC}"

command -v docker >/dev/null 2>&1 || { echo -e "${RED}Docker is required but not installed. Aborting.${NC}" >&2; exit 1; }
command -v docker-compose >/dev/null 2>&1 || { echo -e "${RED}Docker Compose is required but not installed. Aborting.${NC}" >&2; exit 1; }

echo -e "${GREEN}✓ Docker found${NC}"
echo -e "${GREEN}✓ Docker Compose found${NC}"
echo ""

# Create directory structure
echo -e "${YELLOW}Creating directory structure...${NC}"
mkdir -p prometheus/rules
mkdir -p grafana/provisioning/datasources
mkdir -p grafana/provisioning/dashboards
mkdir -p grafana-dashboards
mkdir -p alertmanager
mkdir -p exporters/aws-cost-exporter
mkdir -p scripts/auto-remediation
mkdir -p docs
echo -e "${GREEN}✓ Directories created${NC}"
echo ""

# Create .env file if it doesn't exist
if [ ! -f .env ]; then
    echo -e "${YELLOW}Creating .env file from template...${NC}"
    cp .env.example .env
    echo -e "${GREEN}✓ .env file created${NC}"
    echo -e "${YELLOW}⚠ Please edit .env file with your AWS credentials before starting${NC}"
else
    echo -e "${GREEN}✓ .env file already exists${NC}"
fi
echo ""

# Create README for AWS Cost Exporter
cat > exporters/aws-cost-exporter/README.md << 'EOF'
# AWS Cost Exporter

This exporter collects AWS cost data from Cost Explorer API and exposes it as Prometheus metrics.

## Metrics Exposed

- `aws_daily_cost` - Daily cost by service and region
- `aws_monthly_cost` - Month-to-date cost by service
- `aws_forecast_monthly_cost` - Forecasted monthly cost
- `aws_cost_by_tag` - Costs grouped by tags

## Required AWS Permissions

Your AWS credentials need the following IAM permissions:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ce:GetCostAndUsage",
        "ce:GetCostForecast"
      ],
      "Resource": "*"
    }
  ]
}
```

## Configuration

Set the following environment variables in `.env`:

- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `AWS_REGION`
EOF

echo -e "${GREEN}✓ Created AWS Cost Exporter README${NC}"
echo ""

# Create a simple getting started guide
cat > docs/getting-started.md << 'EOF'
# Getting Started with CloudOps Monitor

## Quick Start

1. **Configure AWS Credentials**
   ```bash
   # Edit .env file
   nano .env
   
   # Add your AWS credentials
   AWS_ACCESS_KEY_ID=your_key_here
   AWS_SECRET_ACCESS_KEY=your_secret_here
   AWS_REGION=us-east-1
   ```

2. **Start the Stack**
   ```bash
   make start
   # or
   docker-compose up -d
   ```

3. **Access Services**
   - Grafana: http://localhost:3000 (admin/admin)
   - Prometheus: http://localhost:9090
   - AlertManager: http://localhost:9093

4. **Verify AWS Cost Exporter**
   ```bash
   # Check if metrics are being collected
   curl http://localhost:9101/metrics
   ```

## Next Steps

1. Import pre-built dashboards in Grafana
2. Configure Slack/Email alerts in `alertmanager/config.yml`
3. Customize alert rules in `prometheus/rules/alerts.yml`
4. Add more cloud providers (Azure, GCP)

## Troubleshooting

**AWS Cost Exporter not working?**
- Check AWS credentials: `make test-aws`
- Ensure IAM permissions for Cost Explorer API
- Check logs: `docker-compose logs aws-cost-exporter`

**No metrics in Grafana?**
- Verify Prometheus is scraping: http://localhost:9090/targets
- Check data sources in Grafana

**Alerts not firing?**
- Verify AlertManager config: `make validate`
- Check alert rules: http://localhost:9090/alerts
EOF

echo -e "${GREEN}✓ Created getting started guide${NC}"
echo ""

# Create gitignore
cat > .gitignore << 'EOF'
# Environment variables
.env

# Data volumes
prometheus-data/
grafana-data/
alertmanager-data/

# Logs
*.log

# OS files
.DS_Store
Thumbs.db

# IDE
.vscode/
.idea/
*.swp
*.swo

# Backups
backups/

# Temporary files
tmp/
temp/
EOF

echo -e "${GREEN}✓ Created .gitignore${NC}"
echo ""

# Summary
echo -e "${BLUE}"
echo "╔════════════════════════════════════════╗"
echo "║        Setup Complete! 🎉             ║"
echo "╚════════════════════════════════════════╝"
echo -e "${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo -e "1. Edit ${GREEN}.env${NC} file with your AWS credentials"
echo -e "2. Run ${GREEN}make start${NC} to start all services"
echo -e "3. Access Grafana at ${GREEN}http://localhost:3000${NC} (admin/admin)"
echo ""
echo -e "${YELLOW}Useful commands:${NC}"
echo -e "  ${GREEN}make start${NC}      - Start all services"
echo -e "  ${GREEN}make stop${NC}       - Stop all services"
echo -e "  ${GREEN}make logs${NC}       - View logs"
echo -e "  ${GREEN}make validate${NC}   - Validate configurations"
echo -e "  ${GREEN}make help${NC}       - Show all available commands"
echo ""
echo -e "For more information, see ${GREEN}docs/getting-started.md${NC}"
echo ""

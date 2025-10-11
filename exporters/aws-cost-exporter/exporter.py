#!/usr/bin/env python3
# exporters/aws-cost-exporter/exporter.py

import os
import time
from datetime import datetime, timedelta
import boto3
from prometheus_client import start_http_server, Gauge, Info
import logging

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Prometheus metrics
aws_daily_cost = Gauge('aws_daily_cost', 'AWS daily cost in USD', ['service', 'region'])
aws_monthly_cost = Gauge('aws_monthly_cost', 'AWS month-to-date cost in USD', ['service'])
aws_forecast_monthly_cost = Gauge('aws_forecast_monthly_cost', 'AWS forecasted monthly cost in USD')
aws_cost_by_tag = Gauge('aws_cost_by_tag', 'AWS cost grouped by tag', ['tag_key', 'tag_value'])
aws_untagged_resources_cost = Gauge('aws_untagged_resources_cost', 'Cost of untagged resources')
exporter_info = Info('aws_cost_exporter', 'AWS Cost Exporter information')

class AWSCostExporter:
    def __init__(self):
        self.region = os.getenv('AWS_REGION', 'us-east-1')
        
        # Initialize AWS Cost Explorer client
        try:
            self.ce_client = boto3.client('ce', region_name=self.region)
            logger.info(f"Successfully initialized AWS Cost Explorer client in region {self.region}")
        except Exception as e:
            logger.error(f"Failed to initialize AWS client: {e}")
            raise

        # Set exporter info
        exporter_info.info({
            'version': '1.0.0',
            'aws_region': self.region
        })

    def get_date_range(self, days=1):
        """Get date range for cost queries"""
        end_date = datetime.now().date()
        start_date = end_date - timedelta(days=days)
        return start_date.strftime('%Y-%m-%d'), end_date.strftime('%Y-%m-%d')

    def get_month_range(self):
        """Get current month date range"""
        today = datetime.now().date()
        start_date = today.replace(day=1)
        return start_date.strftime('%Y-%m-%d'), today.strftime('%Y-%m-%d')

    def collect_daily_costs(self):
        """Collect yesterday's costs by service and region"""
        try:
            start_date, end_date = self.get_date_range(days=1)
            logger.info(f"Fetching daily costs from {start_date} to {end_date}")

            response = self.ce_client.get_cost_and_usage(
                TimePeriod={
                    'Start': start_date,
                    'End': end_date
                },
                Granularity='DAILY',
                Metrics=['UnblendedCost'],
                GroupBy=[
                    {'Type': 'DIMENSION', 'Key': 'SERVICE'},
                    {'Type': 'DIMENSION', 'Key': 'REGION'}
                ]
            )

            total_daily = 0
            for result in response['ResultsByTime']:
                for group in result['Groups']:
                    service = group['Keys'][0]
                    region = group['Keys'][1] if len(group['Keys']) > 1 else 'global'
                    cost = float(group['Metrics']['UnblendedCost']['Amount'])
                    
                    if cost > 0:
                        aws_daily_cost.labels(service=service, region=region).set(cost)
                        total_daily += cost

            logger.info(f"Total daily cost: ${total_daily:.2f}")

        except Exception as e:
            logger.error(f"Error collecting daily costs: {e}")

    def collect_monthly_costs(self):
        """Collect month-to-date costs by service"""
        try:
            start_date, end_date = self.get_month_range()
            logger.info(f"Fetching monthly costs from {start_date} to {end_date}")

            response = self.ce_client.get_cost_and_usage(
                TimePeriod={
                    'Start': start_date,
                    'End': end_date
                },
                Granularity='MONTHLY',
                Metrics=['UnblendedCost'],
                GroupBy=[
                    {'Type': 'DIMENSION', 'Key': 'SERVICE'}
                ]
            )

            total_monthly = 0
            for result in response['ResultsByTime']:
                for group in result['Groups']:
                    service = group['Keys'][0]
                    cost = float(group['Metrics']['UnblendedCost']['Amount'])
                    
                    if cost > 0:
                        aws_monthly_cost.labels(service=service).set(cost)
                        total_monthly += cost

            logger.info(f"Total monthly cost: ${total_monthly:.2f}")

        except Exception as e:
            logger.error(f"Error collecting monthly costs: {e}")

    def collect_cost_forecast(self):
        """Collect forecasted monthly cost"""
        try:
            today = datetime.now().date()
            start_date = today.strftime('%Y-%m-%d')
            
            # Forecast until end of month
            end_of_month = (today.replace(day=1) + timedelta(days=32)).replace(day=1)
            end_date = end_of_month.strftime('%Y-%m-%d')

            logger.info(f"Fetching cost forecast from {start_date} to {end_date}")

            response = self.ce_client.get_cost_forecast(
                TimePeriod={
                    'Start': start_date,
                    'End': end_date
                },
                Metric='UNBLENDED_COST',
                Granularity='MONTHLY'
            )

            forecast = float(response['Total']['Amount'])
            aws_forecast_monthly_cost.set(forecast)
            logger.info(f"Forecasted monthly cost: ${forecast:.2f}")

        except Exception as e:
            logger.error(f"Error collecting cost forecast: {e}")

    def collect_costs_by_tags(self):
        """Collect costs grouped by tags (e.g., Environment, Team)"""
        try:
            start_date, end_date = self.get_month_range()
            
            # Common tags to track
            tags_to_track = ['Environment', 'Team', 'Project', 'Owner']
            
            for tag_key in tags_to_track:
                try:
                    response = self.ce_client.get_cost_and_usage(
                        TimePeriod={
                            'Start': start_date,
                            'End': end_date
                        },
                        Granularity='MONTHLY',
                        Metrics=['UnblendedCost'],
                        GroupBy=[
                            {'Type': 'TAG', 'Key': tag_key}
                        ]
                    )

                    for result in response['ResultsByTime']:
                        for group in result['Groups']:
                            tag_value = group['Keys'][0].replace(f'{tag_key}$', '') or 'untagged'
                            cost = float(group['Metrics']['UnblendedCost']['Amount'])
                            
                            if cost > 0:
                                aws_cost_by_tag.labels(
                                    tag_key=tag_key,
                                    tag_value=tag_value
                                ).set(cost)

                except Exception as tag_error:
                    logger.warning(f"Could not fetch costs for tag {tag_key}: {tag_error}")

        except Exception as e:
            logger.error(f"Error collecting costs by tags: {e}")

    def collect_metrics(self):
        """Collect all metrics"""
        logger.info("Starting metrics collection cycle")
        
        self.collect_daily_costs()
        self.collect_monthly_costs()
        self.collect_cost_forecast()
        self.collect_costs_by_tags()
        
        logger.info("Metrics collection cycle completed")

def main():
    # Get port from environment variable
    port = int(os.getenv('EXPORTER_PORT', 9101))
    scrape_interval = int(os.getenv('SCRAPE_INTERVAL', 300))  # 5 minutes default

    logger.info(f"Starting AWS Cost Exporter on port {port}")
    
    # Start Prometheus HTTP server
    start_http_server(port)
    logger.info(f"Metrics server started on port {port}")

    # Initialize exporter
    exporter = AWSCostExporter()

    # Main loop
    while True:
        try:
            exporter.collect_metrics()
        except Exception as e:
            logger.error(f"Error in metrics collection: {e}")
        
        logger.info(f"Sleeping for {scrape_interval} seconds")
        time.sleep(scrape_interval)

if __name__ == '__main__':
    main()
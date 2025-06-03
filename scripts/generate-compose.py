#!/usr/bin/env python3
"""
Docker Compose Generator for Klever Services
Generates dynamic docker-compose.yml files for Docker Swarm deployments
"""

import json
import yaml
import sys
import argparse
from typing import Dict, List, Any, Optional


def parse_array_config(config_array):
    """Parse array-based configuration format into traditional format"""
    services = []
    images = {}
    domains = []
    ports = []
    service_envs = {}
    service_configs = {}
    service_volumes = {}
    service_resources = {}
    service_secrets = {}
    health_urls = []
    retry_config = {}
    rate_limit_config = {}
    metrics_paths = {}
    node_constraints = {}
    advanced_health = {}
    
    # Global defaults that can be overridden per service
    global_config = {
        'replicas': 1,
        'env': 'prod',
        'fqdn': 'example.com',
        'health_checks': True,
        'resource_limits': True,
        'volume_persistence': False,
        'volume_dir': '/data',
        'enable_retry': False,
        'enable_rate_limit': False,
        'enable_monitoring': False,
        'enable_network_separation': False,
        'deployment_strategy': 'rolling',
        'use_secrets': False,
        'enable_logging': True
    }
    
    external_networks = set()
    
    for svc in config_array:
        if 'service_name' not in svc:
            raise ValueError(f"Each service must have a 'service_name' field")
        
        name = svc['service_name']
        services.append(name)
        
        # Extract image (required)
        if 'image' not in svc:
            raise ValueError(f"Service '{name}' must have an 'image' field")
        images[name] = svc['image']
        
        # Extract domain and port for exposed services
        if svc.get('expose', True) and not ('worker' in name.lower() or 'job' in name.lower()):
            if 'domain' in svc:
                domains.append(svc['domain'])
            elif 'port' in svc:
                # Auto-generate domain from service name if not provided
                domains.append(name.replace('_', '-'))
            
            if 'port' in svc:
                ports.append(str(svc['port']))
        
        # Environment variables
        if 'environment' in svc:
            service_envs[name] = svc['environment']
        
        # Service-specific config
        svc_config = {}
        if 'expose' in svc:
            svc_config['expose'] = svc['expose']
        if 'networks' in svc:
            svc_config['networks'] = svc['networks']
            # Extract external networks (those starting with certain patterns or explicitly marked)
            for net in svc['networks']:
                if any(prefix in net for prefix in ['shared-', 'external-']) or '-db' in net:
                    external_networks.add(net)
        if 'internal_port' in svc:
            svc_config['internal_port'] = str(svc['internal_port'])
        
        if svc_config:
            service_configs[name] = svc_config
        
        # Volumes
        if 'volumes' in svc:
            service_volumes[name] = svc['volumes']
        
        # Resources
        if 'resources' in svc:
            service_resources[name] = svc['resources']
        
        # Health check URL
        if 'health_url' in svc:
            health_urls.append(svc['health_url'])
        else:
            health_urls.append('/health')
        
        # Advanced configurations
        if 'retry' in svc:
            retry_config[name] = svc['retry']
        
        if 'rate_limit' in svc:
            rate_limit_config[name] = svc['rate_limit']
        
        if 'metrics_path' in svc:
            metrics_paths[name] = svc['metrics_path']
        
        if 'constraints' in svc:
            node_constraints[name] = svc['constraints']
        
        if 'health_check' in svc:
            advanced_health[name] = svc['health_check']
        
        # Secrets mapping
        if 'secrets' in svc:
            service_secrets[name] = svc['secrets']
        
        # Update global config from service if explicitly set
        for key in ['replicas', 'env', 'fqdn', 'health_checks', 'resource_limits', 
                   'volume_persistence', 'volume_dir', 'enable_retry', 'enable_rate_limit',
                   'enable_monitoring', 'enable_network_separation', 'deployment_strategy',
                   'use_secrets', 'enable_logging']:
            if key in svc:
                global_config[key] = svc[key]
    
    # Remove default networks from external networks
    external_networks.discard('traefik-public')
    external_networks.discard('backend')
    external_networks.discard('database')
    
    # Ensure we have at least one domain/port for exposed services
    if not domains and any(service_configs.get(s, {}).get('expose', True) for s in services):
        domains = ['app']  # Default domain
    if not ports and any(service_configs.get(s, {}).get('expose', True) for s in services):
        ports = ['8080']  # Default port
    
    return {
        'services': services,
        'images': images,
        'domains': domains,
        'ports': ports,
        'service_envs': service_envs,
        'service_configs': service_configs,
        'service_volumes': service_volumes,
        'service_resources': service_resources,
        'service_secrets': service_secrets,
        'health_urls': health_urls,
        'external_networks': list(external_networks),
        'retry_config': retry_config,
        'rate_limit_config': rate_limit_config,
        'metrics_paths': metrics_paths,
        'node_constraints': node_constraints,
        'advanced_health': advanced_health,
        **global_config
    }


def generate_logging_config(service_name: str, env: str) -> Dict[str, Any]:
    """Generate logging configuration for a service"""
    return {
        'driver': 'json-file',
        'options': {
            'max-size': '10m' if env == 'prod' else '50m',
            'max-file': '3' if env == 'prod' else '5',
            'labels': f'service={service_name},environment={env}',
            'tag': f'{{.Name}}/{{.ID}}'
        }
    }


def generate_placement_constraints(
    service_name: str,
    env: str,
    node_constraints: Optional[Dict[str, List[str]]] = None
) -> Optional[Dict[str, List[str]]]:
    """Generate placement constraints for services"""
    constraints = []
    
    # Default constraints based on environment
    if env == 'prod':
        constraints.append('node.role == worker')
    
    # Add custom constraints if provided
    if node_constraints and service_name in node_constraints:
        constraints.extend(node_constraints[service_name])
    
    return {'constraints': constraints} if constraints else None


def generate_networks(services: List[str], enable_network_separation: bool = False, external_networks: List[str] = None) -> Dict[str, Any]:
    """Generate network configuration"""
    networks = {
        'traefik-public': {
            'external': True
        }
    }
    
    # Add external networks
    if external_networks:
        for net in external_networks:
            networks[net] = {'external': True}
    
    if not enable_network_separation:
        return networks
    
    # Add internal network for backend services
    if any(svc in ['api', 'worker', 'backend'] for svc in services):
        networks['backend'] = {
            'driver': 'overlay',
            'internal': True,
            'encrypted': True
        }
    
    # Add database network if needed
    if any(svc in ['db', 'database', 'postgres', 'mysql'] for svc in services):
        networks['database'] = {
            'driver': 'overlay',
            'internal': True,
            'encrypted': True
        }
    
    return networks


def generate_resource_limits(
    service_name: str,
    service_resources: Optional[Dict[str, Dict]] = None,
    default_limits: bool = True
) -> Optional[Dict[str, Any]]:
    """Generate resource limits per service"""
    if service_resources and service_name in service_resources:
        return service_resources[service_name]
    
    if not default_limits:
        return None
    
    # Default resource limits based on service type - only limits, no reservations
    # This prevents breaking Docker scheduler on tight VPS environments
    if 'worker' in service_name or 'job' in service_name:
        return {
            'limits': {'cpus': '1.0', 'memory': '1G'}
        }
    elif 'api' in service_name or 'backend' in service_name:
        return {
            'limits': {'cpus': '2.0', 'memory': '2G'}
        }
    else:
        return {
            'limits': {'cpus': '0.5', 'memory': '512M'}
        }


def generate_update_config(service_name: str, env: str, strategy: str = 'rolling') -> Dict[str, Any]:
    """Generate update configuration with monitoring"""
    if strategy == 'rolling':
        return {
            'parallelism': 1 if env == 'prod' else 2,
            'delay': '30s' if env == 'prod' else '10s',
            'failure_action': 'rollback',
            'monitor': '5m' if env == 'prod' else '30s',
            'max_failure_ratio': 0.1 if env == 'prod' else 0.3,
            'order': 'stop-first'
        }
    elif strategy == 'blue-green':
        return {
            'parallelism': 999,  # All at once
            'delay': '0s',
            'failure_action': 'rollback',
            'monitor': '5m',
            'max_failure_ratio': 0.0,
            'order': 'start-first'
        }
    else:  # canary
        return {
            'parallelism': 1,
            'delay': '5m',  # Slow rollout
            'failure_action': 'pause',
            'monitor': '10m',
            'max_failure_ratio': 0.1,
            'order': 'start-first'
        }


def generate_healthcheck(
    port: str,
    health_url: str,
    service_name: str,
    advanced_health: Optional[Dict] = None
) -> Dict[str, Any]:
    """Generate health check configuration"""
    if advanced_health and service_name in advanced_health:
        return advanced_health[service_name]
    
    # Default health check with better timing for production
    return {
        'test': ['CMD', 'curl', '-f', f'http://localhost:{port}{health_url}'],
        'interval': '30s',
        'timeout': '10s',
        'retries': 5,
        'start_period': '60s'
    }


def generate_compose(
    services,
    images,
    domains,
    fqdn,
    replicas,
    ports,
    env,
    health_enabled,
    resource_limits,
    volume_persistence,
    volume_dir,
    health_urls,
    service_envs,
    enable_retry=False,
    enable_rate_limit=False,
    enable_monitoring=False,
    enable_logging=True,
    deployment_strategy='rolling',
    node_constraints=None,
    service_resources=None,
    use_secrets=False,
    advanced_health=None,
    enable_network_separation=False,
    retry_config=None,
    rate_limit_config=None,
    metrics_paths=None,
    service_configs=None,
    external_networks=None,
    service_volumes=None,
    service_secrets=None
):
    """Generate a docker-compose configuration"""
    
    # Parse external networks from config
    external_nets = []
    if external_networks:
        external_nets = external_networks if isinstance(external_networks, list) else [external_networks]
    
    compose = {
        'version': '3.8',
        'services': {},
        'networks': generate_networks(services, enable_network_separation, external_nets),
        'volumes': {}
    }
    
    # Add secrets section if enabled
    if use_secrets:
        compose['secrets'] = {}

    for i, svc in enumerate(services):
        svc = svc.strip()
        
        # Get service-specific configuration
        svc_config = service_configs.get(svc, {}) if service_configs else {}
        
        # Check if service should be exposed (default: yes, unless it's a worker/job or explicitly set)
        is_exposed = svc_config.get('expose', True)
        if not is_exposed or 'worker' in svc.lower() or 'job' in svc.lower():
            is_exposed = svc_config.get('expose', False)
        
        # Get domain and port only if exposed
        domain = None
        port = None
        fqdn_full = None
        if is_exposed and i < len(domains) and i < len(ports):
            domain = domains[i]
            port = ports[i]
            fqdn_full = f"{domain}-{env}.{fqdn}"
            if env == 'prod':
                fqdn_full = f"{domain}.{fqdn}"
        
        image = images.get(svc, 'nginx:latest')
        
        # Determine which networks this service should use
        service_networks = []
        
        # Add custom networks from service config
        if 'networks' in svc_config:
            service_networks.extend(svc_config['networks'])
        else:
            # Default network assignment
            if is_exposed:
                service_networks.append('traefik-public')
            
            if enable_network_separation:
                if svc in ['api', 'backend'] or 'api' in svc.lower():
                    service_networks.append('backend')
                elif svc in ['worker', 'job'] or 'worker' in svc.lower() or 'job' in svc.lower():
                    service_networks.append('backend')
                
        # Ensure we have at least one network
        if not service_networks:
            service_networks = ['traefik-public'] if is_exposed else ['backend' if enable_network_separation else 'traefik-public']
        
        # Build labels
        labels = []
        
        # Only add Traefik labels if service is exposed
        if is_exposed and port and fqdn_full:
            # Build middleware list
            middlewares = ['secureHeaders@file']
            
            labels.extend([
                'traefik.enable=true',
                'traefik.swarm.network=traefik-public',
                f'traefik.http.routers.{svc}.rule=Host(`{fqdn_full}`)',
                f'traefik.http.routers.{svc}.entrypoints=websecure',
                f'traefik.http.routers.{svc}.tls=true',
                f'traefik.http.routers.{svc}.tls.certresolver=cloudflare',
                f'traefik.http.services.{svc}.loadbalancer.server.port={port}',
                f'traefik.http.routers.{svc}.service={svc}'
            ])
            
            # Add retry middleware if enabled
            if enable_retry:
                middlewares.append(f'{svc}-retry')
                retry_attempts = 3
                retry_interval = '100ms'
                if retry_config and svc in retry_config:
                    retry_attempts = retry_config[svc].get('attempts', 3)
                    retry_interval = retry_config[svc].get('interval', '100ms')
                labels.extend([
                    f'traefik.http.middlewares.{svc}-retry.retry.attempts={retry_attempts}',
                    f'traefik.http.middlewares.{svc}-retry.retry.initialinterval={retry_interval}'
                ])
            
            # Add rate limit middleware if enabled
            if enable_rate_limit:
                middlewares.append(f'{svc}-ratelimit')
                rate_average = 100
                rate_burst = 50
                if rate_limit_config and svc in rate_limit_config:
                    rate_average = rate_limit_config[svc].get('average', 100)
                    rate_burst = rate_limit_config[svc].get('burst', 50)
                labels.extend([
                    f'traefik.http.middlewares.{svc}-ratelimit.ratelimit.average={rate_average}',
                    f'traefik.http.middlewares.{svc}-ratelimit.ratelimit.burst={rate_burst}'
                ])
            
            # Set the middlewares
            labels.append(f'traefik.http.routers.{svc}.middlewares={",".join(middlewares)}')
        
        # Add monitoring labels if enabled (for local Prometheus instances)
        if enable_monitoring:
            metrics_path = '/metrics'
            if metrics_paths and svc in metrics_paths:
                metrics_path = metrics_paths[svc]
            
            # Get monitoring port (use service port or from config)
            monitoring_port = port if port else svc_config.get('internal_port', '8080')
            
            labels.extend([
                f'prometheus.io/scrape=true',
                f'prometheus.io/port={monitoring_port}',
                f'prometheus.io/path={metrics_path}',
                f'prometheus.io/job={svc}',
                f'service.name={svc}'
            ])
        
        config = {
            'image': image,
            'networks': service_networks,
            'environment': [
                f'SERVICE_NAME={svc}',
                f'ENVIRONMENT={env}',
                f'DOMAIN={fqdn_full}',
            ],
            'deploy': {
                'replicas': replicas,
                'labels': labels,
                'update_config': generate_update_config(svc, env, deployment_strategy),
                'restart_policy': {
                    'condition': 'on-failure',
                    'delay': '5s',
                    'max_attempts': 5,
                    'window': '120s'
                }
            }
        }
        
        # Add rollback configuration for production
        if env == 'prod':
            config['deploy']['rollback_config'] = {
                'parallelism': 1,
                'delay': '10s',
                'failure_action': 'continue',
                'monitor': '5m',
                'max_failure_ratio': 0.1
            }
        
        # Add placement constraints
        placement = generate_placement_constraints(svc, env, node_constraints)
        if placement:
            config['deploy']['placement'] = placement
        
        # Add logging configuration
        if enable_logging:
            config['logging'] = generate_logging_config(svc, env)

        # Add custom environment variables
        custom_env = service_envs.get(svc, {})
        for key, value in custom_env.items():
            # Use secrets for sensitive data in production
            if use_secrets and env == 'prod' and any(
                sensitive in key.lower() 
                for sensitive in ['password', 'secret', 'key', 'token']
            ):
                secret_name = f'{svc}_{key.lower()}'
                config.setdefault('secrets', []).append({
                    'source': secret_name,
                    'target': f'/run/secrets/{key.lower()}',
                    'mode': 0o400
                })
                compose['secrets'][secret_name] = {'external': True}
                # Set env var to point to secret file
                config['environment'].append(f'{key}_FILE=/run/secrets/{key.lower()}')
            else:
                config['environment'].append(f'{key}={value}')
        
        # Add explicitly mapped secrets from service_secrets
        if service_secrets and svc in service_secrets:
            for secret in service_secrets[svc]:
                if isinstance(secret, str):
                    # Simple secret name
                    config.setdefault('secrets', []).append(secret)
                    compose['secrets'][secret] = {'external': True}
                elif isinstance(secret, dict):
                    # Secret with custom configuration
                    secret_name = secret.get('source', secret.get('name'))
                    secret_config = {
                        'source': secret_name,
                        'target': secret.get('target', f'/run/secrets/{secret_name}'),
                    }
                    if 'mode' in secret:
                        secret_config['mode'] = secret['mode']
                    if 'uid' in secret:
                        secret_config['uid'] = secret['uid']
                    if 'gid' in secret:
                        secret_config['gid'] = secret['gid']
                    
                    config.setdefault('secrets', []).append(secret_config)
                    compose['secrets'][secret_name] = {'external': True}

        # Add health checks
        if health_enabled:
            url = health_urls[i % len(health_urls)].strip() if i < len(health_urls) else '/health'
            # Get health check port (use service port or from config)
            health_port = port if port else svc_config.get('internal_port', '8080')
            config['healthcheck'] = generate_healthcheck(
                health_port, url, svc, advanced_health
            )

        # Add resource limits
        if resource_limits or service_resources:
            resources = generate_resource_limits(svc, service_resources, resource_limits)
            if resources:
                config['deploy']['resources'] = resources

        # Add volume persistence
        service_volume_list = []
        
        # Add custom volumes from service config
        if service_volumes and svc in service_volumes:
            for vol in service_volumes[svc]:
                if isinstance(vol, dict):
                    # Volume with options
                    vol_name = vol.get('name', f'{svc}_{env}_volume')
                    vol_path = vol.get('path', volume_dir)
                    vol_type = vol.get('type', 'volume')
                    
                    if vol_type == 'bind':
                        service_volume_list.append(f"{vol_name}:{vol_path}")
                    else:
                        service_volume_list.append(f"{vol_name}:{vol_path}")
                        if vol_name not in compose['volumes']:
                            compose['volumes'][vol_name] = {
                                'driver': vol.get('driver', 'local'),
                                'labels': {
                                    'service': svc,
                                    'environment': env,
                                    'backup': vol.get('backup', 'true')
                                }
                            }
                else:
                    # Simple volume string
                    service_volume_list.append(vol)
        
        # Add default volume if persistence is enabled
        elif volume_persistence:
            volume = f'{svc}_{env}_volume'
            service_volume_list.append(f'{volume}:{volume_dir}')
            compose['volumes'][volume] = {
                'driver': 'local',
                'labels': {
                    'service': svc,
                    'environment': env,
                    'backup': 'true'
                }
            }
        
        if service_volume_list:
            config['volumes'] = service_volume_list
        
        compose['services'][svc] = config

    return compose


def main():
    parser = argparse.ArgumentParser(
        description='Generate production-ready Docker Compose configuration for Swarm deployments'
    )
    
    # Basic options
    parser.add_argument('--services', help='Comma-separated service names')
    parser.add_argument('--images', help='JSON mapping of services to images')
    parser.add_argument('--domains', help='Comma-separated domain prefixes')
    parser.add_argument('--fqdn', help='Fully qualified domain name')
    parser.add_argument('--replicas', type=int, default=1, help='Number of replicas')
    parser.add_argument('--ports', help='Comma-separated ports')
    parser.add_argument('--env', default='prod', help='Environment type (dev, staging, prod)')
    parser.add_argument('--health-checks', action='store_true', help='Enable health checks')
    parser.add_argument('--resource-limits', action='store_true', help='Enable resource limits')
    parser.add_argument('--volume-persistence', action='store_true', help='Enable volume persistence')
    parser.add_argument('--volume-dir', default='/data', help='Volume directory')
    parser.add_argument('--health-urls', default='/health', help='Health check URLs')
    parser.add_argument('--service-envs', default='{}', help='Service environment variables (JSON)')
    parser.add_argument('--output', default='docker-compose.yml', help='Output file')
    
    # Enhanced features
    parser.add_argument('--enable-retry', action='store_true', 
                       help='Enable Traefik retry middleware')
    parser.add_argument('--enable-rate-limit', action='store_true', 
                       help='Enable Traefik rate limiting')
    parser.add_argument('--enable-monitoring', action='store_true', 
                       help='Add Prometheus scraping labels for local monitoring')
    parser.add_argument('--enable-logging', action='store_true', default=True,
                       help='Enable logging configuration (default: enabled)')
    parser.add_argument('--enable-network-separation', action='store_true',
                       help='Enable network separation (frontend/backend/database)')
    
    # Advanced configuration
    parser.add_argument('--deployment-strategy', default='rolling', 
                       choices=['rolling', 'blue-green', 'canary'],
                       help='Deployment strategy (default: rolling)')
    parser.add_argument('--use-secrets', action='store_true', 
                       help='Use Docker secrets for sensitive data')
    parser.add_argument('--node-constraints', default='{}', 
                       help='Node placement constraints (JSON)')
    parser.add_argument('--service-resources', default='{}', 
                       help='Per-service resource limits (JSON)')
    parser.add_argument('--advanced-health', default='{}', 
                       help='Advanced health check configs (JSON)')
    parser.add_argument('--retry-config', default='{}',
                       help='Per-service retry configuration (JSON)')
    parser.add_argument('--rate-limit-config', default='{}',
                       help='Per-service rate limit configuration (JSON)')
    parser.add_argument('--metrics-paths', default='{}',
                       help='Per-service metrics paths (JSON)')
    parser.add_argument('--service-configs', default='{}',
                       help='Per-service configuration (JSON) - expose, networks, internal_port, etc.')
    parser.add_argument('--external-networks', nargs='*',
                       help='External networks to attach (e.g., shared-db-network)')
    parser.add_argument('--service-volumes', default='{}',
                       help='Per-service volume configuration (JSON)')
    parser.add_argument('--service-secrets', default='{}',
                       help='Per-service secrets configuration (JSON) - maps secrets to services')
    parser.add_argument('--config-file',
                       help='JSON configuration file (supports both object and array formats)')
    
    args = parser.parse_args()
    
    # Load from config file if provided
    if args.config_file:
        with open(args.config_file, 'r') as f:
            config = json.load(f)
        
        # Check if it's array format or traditional format
        if isinstance(config, list):
            # New array format - parse it
            parsed_config = parse_array_config(config)
            config = parsed_config
        
        # Extract values from config, with command-line overrides
        services = config.get('services', [])
        if isinstance(services, str):
            services = services.split(',')
        
        images = config.get('images', {})
        domains = config.get('domains', [])
        if isinstance(domains, str):
            domains = domains.split(',')
        
        # Use command line values if provided, otherwise use config file
        replicas = args.replicas if args.replicas != 1 else config.get('replicas', 1)
        ports = args.ports.split(',') if args.ports else config.get('ports', [])
        if isinstance(ports, str):
            ports = ports.split(',')
        
        env = args.env if args.env != 'prod' else config.get('env', 'prod')
        fqdn = args.fqdn if args.fqdn else config.get('fqdn', 'example.com')
        
        # Boolean flags - use command line if explicitly set
        health_enabled = args.health_checks or config.get('health_checks', False)
        resource_limits = args.resource_limits or config.get('resource_limits', False)
        volume_persistence = args.volume_persistence or config.get('volume_persistence', False)
        enable_retry = args.enable_retry or config.get('enable_retry', False)
        enable_rate_limit = args.enable_rate_limit or config.get('enable_rate_limit', False)
        enable_monitoring = args.enable_monitoring or config.get('enable_monitoring', False)
        enable_logging = args.enable_logging if not args.enable_logging else config.get('enable_logging', True)
        enable_network_separation = args.enable_network_separation or config.get('enable_network_separation', False)
        use_secrets = args.use_secrets or config.get('use_secrets', False)
        
        # Other config values
        volume_dir = args.volume_dir if args.volume_dir != '/data' else config.get('volume_dir', '/data')
        health_urls = config.get('health_urls', ['/health'])
        if isinstance(health_urls, str):
            health_urls = health_urls.split(',')
        
        deployment_strategy = args.deployment_strategy if args.deployment_strategy != 'rolling' else config.get('deployment_strategy', 'rolling')
        
        # Complex configs
        service_envs = config.get('service_envs', {})
        service_configs = config.get('service_configs', {})
        external_networks = args.external_networks or config.get('external_networks', [])
        service_volumes = config.get('service_volumes', {})
        service_secrets = config.get('service_secrets', {})
        node_constraints = config.get('node_constraints', {})
        service_resources = config.get('service_resources', {})
        advanced_health = config.get('advanced_health', {})
        retry_config = config.get('retry_config', {})
        rate_limit_config = config.get('rate_limit_config', {})
        metrics_paths = config.get('metrics_paths', {})
        
    else:
        # Parse from command line arguments
        services = args.services.split(',')
        images = json.loads(args.images)
        domains = args.domains.split(',')
        ports = args.ports.split(',')
        replicas = args.replicas
        env = args.env
        fqdn = args.fqdn
        health_enabled = args.health_checks
        resource_limits = args.resource_limits
        volume_persistence = args.volume_persistence
        volume_dir = args.volume_dir
        health_urls = args.health_urls.split(',')
        enable_retry = args.enable_retry
        enable_rate_limit = args.enable_rate_limit
        enable_monitoring = args.enable_monitoring
        enable_logging = args.enable_logging
        enable_network_separation = args.enable_network_separation
        deployment_strategy = args.deployment_strategy
        use_secrets = args.use_secrets
        external_networks = args.external_networks
        
        service_envs = json.loads(args.service_envs)
        node_constraints = json.loads(args.node_constraints) if args.node_constraints else None
        service_resources = json.loads(args.service_resources) if args.service_resources else None
        advanced_health = json.loads(args.advanced_health) if args.advanced_health else None
        retry_config = json.loads(args.retry_config) if args.retry_config else None
        rate_limit_config = json.loads(args.rate_limit_config) if args.rate_limit_config else None
        metrics_paths = json.loads(args.metrics_paths) if args.metrics_paths else None
        service_configs = json.loads(args.service_configs) if args.service_configs else None
        service_volumes = json.loads(args.service_volumes) if args.service_volumes else None
        service_secrets = json.loads(args.service_secrets) if args.service_secrets else None
    
    # Validate inputs
    if not args.config_file and (not args.services or not args.images or not args.domains or not args.fqdn or not args.ports):
        print("❌ When not using --config-file, the following arguments are required: --services, --images, --domains, --fqdn, --ports")
        sys.exit(1)
    
    if not services:
        print("❌ Services are required")
        sys.exit(1)
    
    # Only require domains and ports if we have exposed services
    if args.config_file:
        # Check if any service is exposed
        has_exposed = any(
            service_configs.get(svc, {}).get('expose', True) 
            for svc in services 
            if not ('worker' in svc.lower() or 'job' in svc.lower())
        )
        if has_exposed and (not domains or not ports):
            print("❌ Domains and ports are required for exposed services")
            sys.exit(1)
    elif not domains or not ports:
        print("❌ Services, domains, and ports are required")
        sys.exit(1)
    
    if volume_dir and not volume_dir.startswith('/'):
        print("❌ volume_dir must be an absolute path")
        sys.exit(1)
    
    # Generate compose
    compose = generate_compose(
        services=services,
        images=images,
        domains=domains,
        fqdn=fqdn,
        replicas=replicas,
        ports=ports,
        env=env,
        health_enabled=health_enabled,
        resource_limits=resource_limits,
        volume_persistence=volume_persistence,
        volume_dir=volume_dir if volume_persistence else None,
        health_urls=health_urls,
        service_envs=service_envs,
        enable_retry=enable_retry,
        enable_rate_limit=enable_rate_limit,
        enable_monitoring=enable_monitoring,
        enable_logging=enable_logging,
        deployment_strategy=deployment_strategy,
        node_constraints=node_constraints,
        service_resources=service_resources,
        use_secrets=use_secrets,
        advanced_health=advanced_health,
        enable_network_separation=enable_network_separation,
        retry_config=retry_config,
        rate_limit_config=rate_limit_config,
        metrics_paths=metrics_paths,
        service_configs=service_configs,
        external_networks=external_networks,
        service_volumes=service_volumes,
        service_secrets=service_secrets
    )
    
    # Write output
    with open(args.output, 'w') as f:
        yaml.dump(compose, f, default_flow_style=False, sort_keys=False)
    
    print(f"✅ Generated {args.output}")
    
    # Print warnings if applicable
    if args.use_secrets:
        print("⚠️  Remember to create the external secrets before deploying")
    if node_constraints:
        print("⚠️  Ensure nodes have the required labels for placement constraints")
    if args.enable_network_separation:
        print("ℹ️  Network separation enabled - ensure services can communicate as needed")


if __name__ == '__main__':
    main()
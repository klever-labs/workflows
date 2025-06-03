# Resource Limits Configuration Examples

## Default Behavior (No Reservations)

When you enable `--resource-limits` or set `"resource_limits": true`, the script applies only upper limits without reservations.
This prevents breaking Docker's scheduler on VPS with limited resources.

### Example: Basic Resource Limits

```json
[
  {
    "service_name": "api",
    "image": "myapp/api:v1.0",
    "port": 8080,
    "resource_limits": true
  }
]
```

This generates:

```yaml
resources:
  limits:
    cpus: '2.0'    # Maximum CPU cores
    memory: 2G     # Maximum memory
  # No reservations - Docker can schedule freely
```

## Custom Resource Configuration

### With Reservations (Guaranteed Resources)

If you need guaranteed resources, explicitly specify them:

```json
[
  {
    "service_name": "database",
    "image": "postgres:15",
    "expose": false,
    "resources": {
      "limits": {
        "cpus": "4",
        "memory": "8G"
      },
      "reservations": {
        "cpus": "2",
        "memory": "4G"
      }
    }
  }
]
```

### Different Limits per Service Type

Default limits when `resource_limits` is enabled:

- **API/Backend services**: 2 CPU cores, 2GB memory
- **Workers/Jobs**: 1 CPU core, 1GB memory  
- **Other services**: 0.5 CPU cores, 512MB memory

### Disable Limits for Specific Services

```json
[
  {
    "service_name": "api",
    "image": "myapp/api:v1.0",
    "resource_limits": false  // No limits for this service
  },
  {
    "service_name": "worker",
    "image": "myapp/worker:v1.0",
    "resource_limits": true   // Default limits applied
  }
]
```

## VPS-Friendly Configuration

For tight VPS environments, use only limits:

```json
[
  {
    "service_name": "api",
    "image": "myapp/api:v1.0",
    "resources": {
      "limits": {
        "cpus": "0.5",
        "memory": "256M"
      }
      // No reservations - maximum flexibility
    }
  },
  {
    "service_name": "worker",
    "image": "myapp/worker:v1.0",
    "resources": {
      "limits": {
        "cpus": "0.25",
        "memory": "128M"
      }
    }
  }
]
```

## Production Example with Mixed Resources

```json
[
  {
    "service_name": "api",
    "image": "myapp/api:prod",
    "resources": {
      "limits": {"cpus": "2", "memory": "2G"}
      // No reservations for flexibility
    }
  },
  {
    "service_name": "database",
    "image": "postgres:15",
    "resources": {
      "limits": {"cpus": "4", "memory": "4G"},
      "reservations": {"cpus": "1", "memory": "2G"}  // Guaranteed resources for DB
    }
  },
  {
    "service_name": "cache",
    "image": "redis:7",
    "resources": {
      "limits": {"cpus": "0.5", "memory": "512M"}
    }
  }
]
```

## Command Line Examples

### Enable default limits (no reservations)

```bash
python3 scripts/generate-compose.py \
  --services "api,worker" \
  --images '{"api": "myapp/api:v1", "worker": "myapp/worker:v1"}' \
  --resource-limits \
  # ... other options
```

### Custom resources with reservations

```bash
python3 scripts/generate-compose.py \
  --services "api,db" \
  --images '{"api": "myapp/api:v1", "db": "postgres:15"}' \
  --service-resources '{"db": {"limits": {"cpus": "4", "memory": "8G"}, "reservations": {"cpus": "2", "memory": "4G"}}}' \
  # ... other options
```

## Best Practices

1. **For VPS/tight resources**: Use only limits, no reservations
2. **For dedicated servers**: Can use reservations for critical services
3. **For databases**: Consider reservations to guarantee performance
4. **For stateless services**: Limits only are usually sufficient
5. **Monitor and adjust**: Start conservative and increase based on metrics

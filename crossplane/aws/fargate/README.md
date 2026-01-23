# Loadgen Fargate Configuration

## Required Manual Configuration

Before deploying, update the following placeholder values:

### scheduled-rules.yaml

Replace subnet and security group placeholders with actual values:

```yaml
subnets:
  - subnet-xxxxx  # Private subnet in us-east-1a
  - subnet-xxxxx  # Private subnet in us-east-1b
securityGroups:
  - sg-xxxxx      # tops-loadgen-v2-sg
```

### task-definition.yaml

Replace `ACCOUNT_ID` with your AWS account ID:

```yaml
image: 123456789012.dkr.ecr.us-east-1.amazonaws.com/tops-tor:latest
image: 123456789012.dkr.ecr.us-east-1.amazonaws.com/tops-k6:latest
```

## Network Requirements

The loadgen tasks require:
- Subnets with NAT gateway access (for Tor and external requests)
- Security group allowing all egress traffic
- No ingress rules needed (tasks don't receive traffic)

## Testing Locally

Build and run containers locally:

```bash
# Build Tor sidecar
docker build -t tops-tor:local containers/tor/

# Build k6
docker build -t tops-k6:local containers/k6/

# Run Tor sidecar
docker run -d --name tor-sidecar -p 9050:9050 tops-tor:local

# Run k6 (uses host network to access Tor)
docker run --rm --network host \
  -e K6_SOCKS5_PROXY=socks5://localhost:9050 \
  -e TARGET_URL=https://httpbin.org \
  tops-k6:local
```

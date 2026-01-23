FROM grafana/k6:0.49.0

# Switch to root to install AWS CLI
USER root

RUN apk add --no-cache \
    aws-cli \
    ca-certificates

# Copy load test scripts
COPY scripts/ /scripts/

# Copy entrypoint
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Switch back to k6 user
USER k6

ENTRYPOINT ["/entrypoint.sh"]
CMD ["run", "--quiet", "/scripts/loadtest.js"]

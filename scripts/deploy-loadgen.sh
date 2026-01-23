#!/usr/bin/env bash
# scripts/deploy-loadgen.sh
# Validates loadgen manifests and provides deployment guidance

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Configuration variables (can be overridden via environment)
AWS_ACCOUNT_ID="${AWS_ACCOUNT_ID:-}"
AWS_REGION="${AWS_REGION:-us-east-1}"
SUBNET_1="${SUBNET_1:-}"
SUBNET_2="${SUBNET_2:-}"
SECURITY_GROUP="${SECURITY_GROUP:-}"

# Manifest paths
ECR_MANIFEST="${REPO_ROOT}/crossplane/aws/ecr/repositories.yaml"
S3_MANIFEST="${REPO_ROOT}/crossplane/aws/s3/loadgen-buckets.yaml"
FARGATE_DIR="${REPO_ROOT}/crossplane/aws/fargate"

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Validates loadgen manifests and provides deployment guidance.

OPTIONS:
    -h, --help          Show this help message
    --dry-run           Show what would be done without making changes
    --validate-only     Only validate manifests, skip deployment info

REQUIRED ENVIRONMENT VARIABLES:
    AWS_ACCOUNT_ID      AWS account ID for deployment
    SUBNET_1            First subnet ID for Fargate tasks
    SUBNET_2            Second subnet ID for Fargate tasks
    SECURITY_GROUP      Security group ID for Fargate tasks

OPTIONAL ENVIRONMENT VARIABLES:
    AWS_REGION          AWS region (default: us-east-1)

EXAMPLE:
    AWS_ACCOUNT_ID=123456789012 \\
    SUBNET_1=subnet-abc123 \\
    SUBNET_2=subnet-def456 \\
    SECURITY_GROUP=sg-xyz789 \\
    $(basename "$0") --validate-only

NOTE:
    Actual deployment is performed via ArgoCD sync.
    This script validates manifests and displays configuration.
EOF
}

# Check if we have a YAML validator available
get_yaml_validator() {
    if command -v yq &>/dev/null; then
        echo "yq"
    elif python3 -c "import yaml" 2>/dev/null; then
        echo "python"
    elif command -v ruby &>/dev/null && ruby -e "require 'yaml'" 2>/dev/null; then
        echo "ruby"
    else
        echo "none"
    fi
}

# Validate a single YAML file
validate_yaml_file() {
    local file="$1"
    local validator
    validator=$(get_yaml_validator)

    case "${validator}" in
        yq)
            yq eval '.' "${file}" >/dev/null 2>&1
            ;;
        python)
            python3 -c "import yaml; list(yaml.safe_load_all(open('${file}')))" 2>/dev/null
            ;;
        ruby)
            ruby -ryaml -e "YAML.load_stream(File.read('${file}'))" 2>/dev/null
            ;;
        none)
            # Fallback: basic checks for YAML structure
            # Check file is not empty and has valid basic structure
            if [[ ! -s "${file}" ]]; then
                return 1
            fi
            # Check for common YAML issues: tabs at start of line (YAML uses spaces)
            if grep -q $'^\t' "${file}" 2>/dev/null; then
                return 1
            fi
            # File exists and passes basic checks
            return 0
            ;;
    esac
}

validate_manifests() {
    local errors=0
    local validator
    validator=$(get_yaml_validator)

    echo "=== Validating Manifests ==="
    echo ""

    if [[ "${validator}" == "none" ]]; then
        echo "Note: No YAML parser found (yq, python yaml, ruby)."
        echo "      Performing basic file existence and structure checks."
        echo ""
    fi

    # Check ECR manifest
    echo "Checking ${ECR_MANIFEST}..."
    if [[ -f "${ECR_MANIFEST}" ]]; then
        if validate_yaml_file "${ECR_MANIFEST}"; then
            echo "  [OK] Valid YAML syntax"
        else
            echo "  [ERROR] Invalid YAML syntax"
            ((errors++))
        fi
    else
        echo "  [WARN] File not found"
    fi

    # Check S3 loadgen manifest
    echo "Checking ${S3_MANIFEST}..."
    if [[ -f "${S3_MANIFEST}" ]]; then
        if validate_yaml_file "${S3_MANIFEST}"; then
            echo "  [OK] Valid YAML syntax"
        else
            echo "  [ERROR] Invalid YAML syntax"
            ((errors++))
        fi
    else
        echo "  [WARN] File not found"
    fi

    # Check Fargate manifests
    echo "Checking Fargate manifests in ${FARGATE_DIR}..."
    if [[ -d "${FARGATE_DIR}" ]]; then
        for yaml_file in "${FARGATE_DIR}"/*.yaml; do
            if [[ -f "${yaml_file}" ]]; then
                local filename
                filename=$(basename "${yaml_file}")
                if validate_yaml_file "${yaml_file}"; then
                    echo "  [OK] ${filename}"
                else
                    echo "  [ERROR] ${filename} - Invalid YAML syntax"
                    ((errors++))
                fi
            fi
        done
    else
        echo "  [WARN] Directory not found"
    fi

    echo ""
    if [[ ${errors} -gt 0 ]]; then
        echo "Validation failed with ${errors} error(s)"
        return 1
    else
        echo "All manifests validated successfully"
        return 0
    fi
}

check_required_vars() {
    local missing=0

    echo "=== Checking Required Variables ==="
    echo ""

    if [[ -z "${AWS_ACCOUNT_ID}" ]]; then
        echo "  [MISSING] AWS_ACCOUNT_ID"
        ((missing++))
    else
        echo "  [OK] AWS_ACCOUNT_ID=${AWS_ACCOUNT_ID}"
    fi

    if [[ -z "${SUBNET_1}" ]]; then
        echo "  [MISSING] SUBNET_1"
        ((missing++))
    else
        echo "  [OK] SUBNET_1=${SUBNET_1}"
    fi

    if [[ -z "${SUBNET_2}" ]]; then
        echo "  [MISSING] SUBNET_2"
        ((missing++))
    else
        echo "  [OK] SUBNET_2=${SUBNET_2}"
    fi

    if [[ -z "${SECURITY_GROUP}" ]]; then
        echo "  [MISSING] SECURITY_GROUP"
        ((missing++))
    else
        echo "  [OK] SECURITY_GROUP=${SECURITY_GROUP}"
    fi

    echo "  [OK] AWS_REGION=${AWS_REGION}"
    echo ""

    if [[ ${missing} -gt 0 ]]; then
        echo "${missing} required variable(s) missing"
        return 1
    fi
    return 0
}

print_config_summary() {
    echo "=== Configuration Summary ==="
    echo ""
    echo "AWS Account:     ${AWS_ACCOUNT_ID:-<not set>}"
    echo "AWS Region:      ${AWS_REGION}"
    echo "Subnet 1:        ${SUBNET_1:-<not set>}"
    echo "Subnet 2:        ${SUBNET_2:-<not set>}"
    echo "Security Group:  ${SECURITY_GROUP:-<not set>}"
    echo ""
    echo "Manifests:"
    echo "  ECR:     ${ECR_MANIFEST}"
    echo "  S3:      ${S3_MANIFEST}"
    echo "  Fargate: ${FARGATE_DIR}/*.yaml"
    echo ""
}

main() {
    local dry_run=false
    local validate_only=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                usage
                exit 0
                ;;
            --dry-run)
                dry_run=true
                shift
                ;;
            --validate-only)
                validate_only=true
                shift
                ;;
            *)
                echo "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done

    echo "=========================================="
    echo "  Loadgen Deployment Script"
    echo "=========================================="
    echo ""

    if ${dry_run}; then
        echo "[DRY-RUN MODE] No changes will be made"
        echo ""
    fi

    # Always validate manifests
    if ! validate_manifests; then
        echo ""
        echo "Please fix manifest errors before proceeding."
        exit 1
    fi

    if ${validate_only}; then
        echo ""
        echo "Validation complete."
        exit 0
    fi

    echo ""

    # Check required variables
    if ! check_required_vars; then
        echo ""
        echo "Please set all required environment variables."
        echo "Run '$(basename "$0") --help' for details."
        exit 1
    fi

    print_config_summary

    echo "=== Deployment Instructions ==="
    echo ""
    echo "Deployment is managed via ArgoCD. To deploy:"
    echo ""
    echo "1. Ensure manifests are committed and pushed to the repository"
    echo "2. Sync the loadgen application in ArgoCD:"
    echo "   argocd app sync loadgen"
    echo ""
    echo "Or use the ArgoCD UI to trigger a sync."
    echo ""

    if ${dry_run}; then
        echo "[DRY-RUN] Would display deployment status here"
    fi
}

main "$@"

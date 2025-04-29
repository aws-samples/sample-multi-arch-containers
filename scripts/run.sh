#!/bin/bash
set -e

# Configuration
REPOSITORY_NAME="opencv-multi-arch"
IMAGE_TAG="latest"
AWS_REGION="${1:-eu-west-1}"  # Default to eu-west-1 if not provided
ARCH_SUFFIX="${2}"  # Optional architecture suffix (amd64 or arm64)
PORT=5000

# Get AWS account ID
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# ECR repository URI
ECR_URI="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
REPOSITORY_URI="${ECR_URI}/${REPOSITORY_NAME}"

# Function to display usage information
usage() {
    echo "Usage: $0 [aws-region] [arch-suffix]"
    echo "Examples:"
    echo "  $0                     # Run multi-arch image from default region"
    echo "  $0 us-west-2           # Run multi-arch image from specified region"
    echo "  $0 us-west-2 amd64     # Run amd64 image from specified region"
    echo "  $0 eu-west-1 arm64     # Run arm64 image from specified region"
}

# Detect host architecture
detect_arch() {
    local arch=$(uname -m)
    case "$arch" in
        x86_64)
            echo "amd64"
            ;;
        arm64|aarch64)
            echo "arm64"
            ;;
        *)
            echo "Unsupported architecture: $arch"
            exit 1
            ;;
    esac
}

# Function to authenticate Docker with ECR
ecr_login() {
    echo "Authenticating Docker with ECR in region ${AWS_REGION}..."
    aws ecr get-login-password --region "${AWS_REGION}" | docker login --username AWS --password-stdin "${ECR_URI}"
}

# Main execution
echo "===== Running OpenCV Multi-Architecture Demo from ECR ====="

# Check if Docker is available
if ! command -v docker &> /dev/null; then
    echo "Error: Docker is not installed or not in PATH"
    exit 1
fi

# Check if AWS CLI is available
if ! command -v aws &> /dev/null; then
    echo "Error: AWS CLI is not installed or not in PATH"
    exit 1
fi

# Check AWS credentials
if ! aws sts get-caller-identity &> /dev/null; then
    echo "Error: AWS credentials not configured or insufficient permissions"
    exit 1
fi

# Login to ECR
ecr_login

# Determine which image to run
HOST_ARCH=$(detect_arch)
ARCH_TO_USE="${ARCH_SUFFIX:-$HOST_ARCH}"  # Use provided arch or detected host arch

if [ -n "$ARCH_SUFFIX" ]; then
    echo "Forcing architecture: $ARCH_TO_USE"
    FULL_IMAGE_NAME="${REPOSITORY_URI}:${IMAGE_TAG}-${ARCH_TO_USE}"
    
    # Add --platform flag to force architecture and disable emulation
    PLATFORM_FLAG="--platform linux/${ARCH_TO_USE}"
    echo "Disabling automatic emulation with: $PLATFORM_FLAG"
else
    echo "Using multi-architecture image (host architecture: $HOST_ARCH)"
    FULL_IMAGE_NAME="${REPOSITORY_URI}:${IMAGE_TAG}"
    PLATFORM_FLAG=""
fi

echo "Running image: $FULL_IMAGE_NAME"

# Pull the image
echo "Pulling image from ECR..."
docker pull ${FULL_IMAGE_NAME}

# Run the container
echo "Starting container..."
docker run --rm -p ${PORT}:5000 ${PLATFORM_FLAG} ${FULL_IMAGE_NAME}

echo "===== Container stopped ====="

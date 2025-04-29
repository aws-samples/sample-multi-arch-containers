#!/bin/bash
set -e

# Configuration
REPOSITORY_NAME="opencv-multi-arch"
IMAGE_TAG="latest"
AWS_REGION="${1:-eu-west-1}"  # Default to eu-west-1 if not provided
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# ECR repository URI
ECR_URI="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
REPOSITORY_URI="${ECR_URI}/${REPOSITORY_NAME}"

# Function to display usage information
usage() {
    echo "Usage: $0 [aws-region]"
    echo "Example: $0 us-west-2"
    echo "If region is not provided, eu-west-1 will be used."
}

# Function to ensure ECR repository exists
ensure_repository() {
    echo "Checking if ECR repository exists: ${REPOSITORY_NAME}"
    
    # Check if repository exists
    if ! aws ecr describe-repositories --repository-names "${REPOSITORY_NAME}" --region "${AWS_REGION}" &> /dev/null; then
        echo "Creating ECR repository: ${REPOSITORY_NAME}"
        aws ecr create-repository --repository-name "${REPOSITORY_NAME}" --region "${AWS_REGION}"
    else
        echo "ECR repository already exists: ${REPOSITORY_NAME}"
    fi
}

# Function to authenticate Docker with ECR
ecr_login() {
    echo "Authenticating Docker with ECR in region ${AWS_REGION}..."
    aws ecr get-login-password --region "${AWS_REGION}" | docker login --username AWS --password-stdin "${ECR_URI}"
}

# Function to build for a specific platform
build_single_platform() {
    local platform=$1
    local tag_suffix=$2
    
    echo "Building for platform: $platform"
    docker build \
        --platform $platform \
        -t "${REPOSITORY_URI}:${IMAGE_TAG}-${tag_suffix}" \
        .
    
    echo "Successfully built ${REPOSITORY_URI}:${IMAGE_TAG}-${tag_suffix}"
    
    # Push the single-architecture image
    echo "Pushing ${REPOSITORY_URI}:${IMAGE_TAG}-${tag_suffix}"
    docker push "${REPOSITORY_URI}:${IMAGE_TAG}-${tag_suffix}"
}

# Main execution
echo "===== OpenCV Multi-Architecture Docker Build for ECR ====="

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

# Ensure ECR repository exists
ensure_repository

# Login to ECR
ecr_login

# Build and push single platform images
build_single_platform "linux/amd64" "amd64"
build_single_platform "linux/arm64" "arm64"

echo "===== Build process completed ====="
echo "Images (per architecture) are available at:"
echo "  AMD64: ${REPOSITORY_URI}:${IMAGE_TAG}-amd64"
echo "  ARM64: ${REPOSITORY_URI}:${IMAGE_TAG}-arm64"
echo ""
echo "For your demo, you can now show architecture incompatibility by running:"
echo "  ./scripts/run.sh ${AWS_REGION} amd64  # Should fail on ARM hosts"
echo "  ./scripts/run.sh ${AWS_REGION} arm64  # Should fail on x86 hosts"
echo ""
echo "Then, to demonstrate the multi-architecture solution, you can run:"
echo "  docker buildx create --name multi-arch-builder --use"
echo "  docker buildx build --platform linux/amd64,linux/arm64 \\"
echo "    -t ${REPOSITORY_URI}:${IMAGE_TAG} \\"
echo "    --push ."
echo ""
echo "Finally, run the multi-arch image with:"
echo "  ./scripts/run.sh ${AWS_REGION}"

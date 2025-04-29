# Migrating applications to AWS Graviton on Amazon EKS

This project demonstrates how to build and run multi-architecture Docker images using OpenCV as an example of a native library that requires architecture-specific binaries.

## Project Structure

```
multi_arch_demo/
├── build/              # Build artifacts
├── docs/               # Documentation
├── scripts/            # Build and run scripts
│   ├── build.sh                # Script to build architecture-specific images
│   ├── build_multi_arch.sh     # Script to build multi-architecture image
│   └── run.sh                  # Script to run Docker containers
├── src/                # Source code
│   ├── app.py          # Flask application
│   └── templates/      # HTML templates
│       └── index.html  # Main page template
├── Dockerfile          # Docker build instructions
├── README.md           # This file
└── requirements.txt    # Python dependencies
```

## Why Multi-Architecture Images?

Native libraries like OpenCV are compiled for specific CPU architectures. When running in containers:

- An x86_64 (amd64) binary won't work on ARM64 systems
- An ARM64 binary won't work on x86_64 systems

Multi-architecture images solve this by:
1. Building separate images for each architecture
2. Publishing them with the same tag
3. Docker automatically pulls the correct image for your system's architecture

## How the Demo Works

1. The Flask app attempts to load and use OpenCV
2. If the OpenCV binary matches the host architecture, it works correctly
3. If there's an architecture mismatch, it fails with an error
4. The web interface displays the result and system information

When you access the web application:
- It will show your system's architecture
- It will attempt to load and use OpenCV
- If successful, you'll see OpenCV version and build information
- If there's an architecture mismatch, you'll see a clear error message

This demonstrates why multi-architecture Docker images are necessary for applications using native libraries like OpenCV.

## Prerequisites

- Docker installed
- Docker BuildX for multi-architecture builds
- AWS CLI configured with appropriate permissions for ECR

## Building the Images

To build architecture-specific images for ECR:

```bash
# Using default region (eu-west-1)
./scripts/build.sh

# Using specific region
./scripts/build.sh us-west-2
```

This script will:
1. Create the ECR repository if it doesn't exist
2. Authenticate Docker with ECR
3. Build and push architecture-specific images (amd64 and arm64)

## Demonstrating Architecture Incompatibility

To demonstrate architecture incompatibility issues:

```bash
# On ARM Mac, run the amd64 image (should fail)
./scripts/run.sh eu-west-1 amd64

# On ARM Mac, run the arm64 image (should work)
./scripts/run.sh eu-west-1 arm64

# On x86 machine, run the arm64 image (should fail)
./scripts/run.sh eu-west-1 arm64

# On x86 machine, run the amd64 image (should work)
./scripts/run.sh eu-west-1 amd64
```

## Building Multi-Architecture Images

After demonstrating the incompatibility issue, you can show the solution by building a multi-architecture image:

```bash
# Build and push multi-architecture image
./scripts/build_multi_arch.sh
```

Then run the multi-architecture image, which will work on any architecture:

```bash
# Run multi-architecture image
./scripts/run.sh
```

## License

MIT

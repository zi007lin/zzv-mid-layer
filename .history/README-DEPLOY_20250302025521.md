# ZZV.io Application

This repository contains the ZZV.io application, configured for development in Cursor.sh and production deployment to Kubernetes using GitHub Actions.

## Development with Cursor.sh

### Setup

1. Clone this repository in Cursor.sh
2. Cursor will automatically detect the `.cursor.json` file and set up the development environment
3. Click "Setup Development Environment" to start the Docker services

### Development Commands

Cursor.sh provides the following custom commands for development:

- `test`: Run the test suite
- `format`: Format code with mix format
- `deps`: Install dependencies
- `iex`: Start an interactive Elixir shell
- `logs`: View application logs

### Development Flow

1. Make changes to the code
2. The Phoenix server will automatically reload with your changes
3. Run tests to verify your changes work
4. Commit and push your changes to GitHub

## Deployment with GitHub Actions

The application is configured to automatically deploy to Kubernetes when changes are pushed to the `main` branch.

### CI/CD Pipeline

1. **Test**: The GitHub workflow will first run all tests
2. **Build**: If tests pass, it builds a Docker image and pushes it to GitHub Container Registry
3. **Deploy**: Finally, it updates the Kubernetes deployment with the new image

### Required Secrets

The following secrets must be configured in GitHub:

- `KUBE_CONFIG`: Kubernetes configuration for deployment
- `MONGODB_URL`: MongoDB connection URL for production
- `SECRET_KEY_BASE`: Secret key base for production
- `TLS_CERT_PATH`: Path to TLS certificate file
- `TLS_KEY_PATH`: Path to TLS key file

## Project Structure

- `/` - Main application code
- `/config` - Configuration files
  - `/config/dev.exs` - Development configuration
  - `/config/prod.exs` - Production configuration
- `/kubernetes` - Kubernetes deployment manifests
- `/.github/workflows` - GitHub Actions workflows
- `/docker-compose.dev.yml` - Development services configuration
- `/Dockerfile` - Production container definition
- `/Dockerfile.dev` - Development container definition

## Environment Variables

### Development

- `MIX_ENV`: Set to `dev` for development
- `DATABASE_URL`: MongoDB connection string
- `KAFKA_BROKER`: Kafka broker address
- `PORT`: Application port (4000 for development)
- `DOMAIN`: Domain name (localhost for development)

### Production

- `MIX_ENV`: Set to `prod` for production
- `DATABASE_URL`: Production MongoDB connection string
- `KAFKA_BROKER`: Production Kafka broker address
- `PORT`: Application port (443 for production)
- `DOMAIN`: Domain name (zzv.io for production)
- `SECRET_KEY_BASE`: Secret key for session encryption

## Architecture

The application is designed to:

1. Use port 443 for all instance-to-instance and client-to-instance communication
2. Provide SSH administration access for admin users
3. Run in a Kubernetes environment for production
4. Scale horizontally as needed

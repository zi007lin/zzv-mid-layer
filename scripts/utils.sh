cat > scripts/utils.sh << 'EOF'
#!/bin/bash

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
  echo -e "${GREEN}[INFO]${NC} $1"
}

log_warning() {
  echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
  echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check command status
check_status() {
  if [ $? -eq 0 ]; then
    log_info "✅ $1 completed successfully"
  else
    log_error "❌ $1 failed"
    exit 1
  fi
}
EOF
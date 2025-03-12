#!/usr/bin/env bash

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Verbosity level (0=errors only, 1=warnings, 2=info, 3=debug)
# Can be overridden by setting VERBOSE_LEVEL environment variable
VERBOSE_LEVEL=${VERBOSE_LEVEL:-2}

# Logging functions
log_debug() {
  if [ $VERBOSE_LEVEL -ge 3 ]; then
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] ${PURPLE}[DEBUG]${NC} $1"
  fi
}

log_info() {
  if [ $VERBOSE_LEVEL -ge 2 ]; then
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] ${GREEN}[INFO]${NC} $1"
  fi
}

log_warning() {
  if [ $VERBOSE_LEVEL -ge 1 ]; then
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] ${YELLOW}[WARNING]${NC} $1"
  fi
}

log_error() {
  echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] ${RED}[ERROR]${NC} $1"
}

log_success() {
  if [ $VERBOSE_LEVEL -ge 2 ]; then
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] ${GREEN}[SUCCESS]${NC} ✅ $1"
  fi
}

# Function to check command status
check_status() {
  local exit_code=$?
  local custom_exit_code=${2:-1}  # Use provided exit code or default to 1
  
  if [ $exit_code -ne 0 ]; then
    log_error "❌ $1 (Exit code: $exit_code)"
    exit $custom_exit_code
  else
    log_success "$1"
  fi
}

# Function to check if a command exists
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Function to check if running as root
check_root() {
  if [ "$(id -u)" -ne 0 ]; then
    log_error "This script must be run as root or with sudo"
    exit 1
  fi
}

# Function to backup a file
backup_file() {
  local file=$1
  local backup="${file}.bak.$(date +%Y%m%d%H%M%S)"
  
  if [ -f "$file" ]; then
    log_info "Backing up $file to $backup"
    cp "$file" "$backup" || {
      log_error "Failed to backup $file"
      return 1
    }
    return 0
  else
    log_warning "File $file doesn't exist, nothing to backup"
    return 1
  fi
}

# Function to display elapsed time
timer_start() {
  START_TIME=$(date +%s)
}

timer_end() {
  local message=${1:-"Operation completed in"}
  if [ -n "$START_TIME" ]; then
    END_TIME=$(date +%s)
    ELAPSED=$((END_TIME - START_TIME))
    log_info "$message $(format_time $ELAPSED)"
    unset START_TIME
  fi
}

format_time() {
  local seconds=$1
  local minutes=$((seconds / 60))
  local hours=$((minutes / 60))
  
  seconds=$((seconds % 60))
  minutes=$((minutes % 60))
  
  if [ $hours -gt 0 ]; then
    echo "${hours}h ${minutes}m ${seconds}s"
  elif [ $minutes -gt 0 ]; then
    echo "${minutes}m ${seconds}s"
  else
    echo "${seconds}s"
  fi
}
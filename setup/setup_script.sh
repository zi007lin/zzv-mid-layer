#!/bin/bash

# Function to execute YAML commands
execute_yaml() {
  local section="$1"
  echo "Executing: $section"

  yq e ".$section[]" setup.yml | while read -r cmd; do
    echo "Running: $cmd"
    eval "$cmd"
  done
}

# Update system and reinstall packages
execute_yaml "system_info"
execute_yaml "installed_packages"

# Restore firewall and networking
execute_yaml "firewall"
execute_yaml "network"

# Restore user settings
execute_yaml "user_permissions"

# Restore environment variables
execute_yaml "env_variables"

# Finalize setup
execute_yaml "finalize"

echo "Ubuntu instance setup is complete."


sudo apt update && sudo apt install -y yq

chmod +x setup.sh
./setup.sh


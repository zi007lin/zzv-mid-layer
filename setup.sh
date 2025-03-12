#!/bin/bash
# Make all shell scripts executable
find . -name "*.sh" -type f -exec chmod +x {} \;
echo "All shell scripts are now executable"
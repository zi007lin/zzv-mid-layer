#!/bin/bash

# Corporate Go Environment Setup Script for Citi
# Run this script to configure Go for your corporate network

echo "Setting up Go environment for Citi corporate network..."

# Get user credentials
read -p "Enter your Citi username: " CITI_USERNAME
read -s -p "Enter your Citi password: " CITI_PASSWORD
echo ""

# Repository configuration - modify these as needed
echo "Available Go repositories in your Artifactory:"
echo "1. go-3rdparty-local (third-party packages)"
echo "2. go-cto-enterprise-local (CTO enterprise packages)"
echo "3. go-gcg-enterprise-local (GCG enterprise packages)"
echo "4. go-icg-enterprise-local (ICG enterprise packages)"
echo ""

# Let user choose repositories or use defaults
read -p "Use default repositories (go-3rdparty-local,go-cto-enterprise-local)? [Y/n]: " USE_DEFAULTS

if [[ $USE_DEFAULTS =~ ^[Nn]$ ]]; then
    echo "Enter repository names (comma-separated, e.g., go-3rdparty-local,go-cto-enterprise-local):"
    read -p "Repositories: " REPO_NAMES
else
    REPO_NAMES="go-3rdparty-local,go-cto-enterprise-local"
fi

# Build GOPROXY URLs
ARTIFACTORY_BASE="https://${CITI_USERNAME}:${CITI_PASSWORD}@www.artifactrepository.citigroup.net/artifactory/api/go"
GOPROXY_URLS=""

IFS=',' read -ra REPOS <<< "$REPO_NAMES"
for repo in "${REPOS[@]}"; do
    repo=$(echo "$repo" | xargs)  # trim whitespace
    if [ -n "$GOPROXY_URLS" ]; then
        GOPROXY_URLS="${GOPROXY_URLS},"
    fi
    GOPROXY_URLS="${GOPROXY_URLS}${ARTIFACTORY_BASE}/${repo}"
done

# Add fallback options
GOPROXY_URLS="${GOPROXY_URLS},https://proxy.golang.org,direct"

# 1. Set up corporate proxy
export HTTP_PROXY=http://cspnaproxy1.wlb2.nam.nsroot.net:8888
export HTTPS_PROXY=http://cspnaproxy1.wlb2.nam.nsroot.net:8888
export NO_PROXY=localhost,127.0.0.1,.citigroup.net,.citi.com

# 2. Configure Go with selected repositories
export GOPROXY="$GOPROXY_URLS"

# 3. Set private modules (adjust patterns as needed)
export GOPRIVATE=*.citigroup.net/*,*.citi.com/*,github.com/citigroup/*

# 4. Disable checksum validation temporarily to avoid sum.golang.org issues
export GOSUMDB=off

# 5. Set other Go environment variables
export GOOS=windows  # Adjust if you're on Linux/Mac
export GOARCH=amd64
export CGO_ENABLED=1

# 6. Make these settings persistent
echo "Making settings persistent..."

# For bash users
if [ -f ~/.bashrc ]; then
    echo "# Corporate Go Settings" >> ~/.bashrc
    echo "export HTTP_PROXY=http://cspnaproxy1.wlb2.nam.nsroot.net:8888" >> ~/.bashrc
    echo "export HTTPS_PROXY=http://cspnaproxy1.wlb2.nam.nsroot.net:8888" >> ~/.bashrc
    echo "export NO_PROXY=localhost,127.0.0.1,.citigroup.net,.citi.com" >> ~/.bashrc
    echo "export GOPROXY=\"$GOPROXY\"" >> ~/.bashrc
    echo "export GOPRIVATE=*.citigroup.net/*,*.citi.com/*,github.com/citigroup/*" >> ~/.bashrc
    echo "export GOSUMDB=off" >> ~/.bashrc
fi

# For zsh users
if [ -f ~/.zshrc ]; then
    echo "# Corporate Go Settings" >> ~/.zshrc
    echo "export HTTP_PROXY=http://cspnaproxy1.wlb2.nam.nsroot.net:8888" >> ~/.zshrc
    echo "export HTTPS_PROXY=http://cspnaproxy1.wlb2.nam.nsroot.net:8888" >> ~/.zshrc
    echo "export NO_PROXY=localhost,127.0.0.1,.citigroup.net,.citi.com" >> ~/.zshrc
    echo "export GOPROXY=\"$GOPROXY\"" >> ~/.zshrc
    echo "export GOPRIVATE=*.citigroup.net/*,*.citi.com/*,github.com/citigroup/*" >> ~/.zshrc
    echo "export GOSUMDB=off" >> ~/.zshrc
fi

# 7. Set up .netrc for authentication (backup method)
echo "Setting up .netrc authentication..."
cat > ~/.netrc << EOF
machine www.artifactrepository.citigroup.net
login $CITI_USERNAME
password $CITI_PASSWORD
EOF

chmod 600 ~/.netrc

# 8. Test the configuration
echo "Testing Go configuration..."
echo "GOPROXY: $(go env GOPROXY)"
echo "GOPRIVATE: $(go env GOPRIVATE)"
echo "GOSUMDB: $(go env GOSUMDB)"

# 9. Try downloading a common module
echo "Testing module download..."
cd /tmp
go mod init test-download 2>/dev/null
go get github.com/stretchr/testify@latest

if [ $? -eq 0 ]; then
    echo "✅ Go configuration successful!"
    echo "You can now use 'go get', 'go mod download', etc."
else
    echo "❌ There might still be issues. Try the manual steps below."
fi

# 10. Clean up test
rm -rf /tmp/go.mod /tmp/go.sum 2>/dev/null

echo ""
echo "Setup complete! Restart your terminal or run 'source ~/.bashrc' (or ~/.zshrc)"
echo ""
echo "Manual verification steps:"
echo "1. go env GOPROXY"
echo "2. go env GOPRIVATE" 
echo "3. go env GOSUMDB"
echo "4. go get github.com/stretchr/testify@latest"

# Alternative configurations if the above doesn't work:
echo ""
echo "=== Alternative Configurations if Issues Persist ==="
echo ""
echo "Option 1 - Direct mode only (fastest):"
echo "export GOPROXY=direct"
echo "export GOSUMDB=off"
echo ""
echo "Option 2 - Public proxy only:"
echo "export GOPROXY=https://proxy.golang.org,direct"
echo "export GOSUMDB=sum.golang.org"
echo ""
echo "Option 3 - Athens proxy (if available):"
echo "export GOPROXY=https://athens.your-company.com,direct"
echo ""
echo "VS Code Integration:"
echo "Add these to your VS Code settings.json:"
echo '{'
echo '  "go.toolsEnvVars": {'
echo '    "GOPROXY": "direct",'
echo '    "GOSUMDB": "off"'
echo '  }'
echo '}'
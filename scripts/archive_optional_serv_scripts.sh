#!/bin/bash

mkdir -p scripts_extra

mv ensure_docker_compose.sh scripts_extra/ 2>/dev/null
mv deploy_spring_boot.sh scripts_extra/ 2>/dev/null
mv deploy_mongodb.sh scripts_extra/ 2>/dev/null
mv setup_letsencrypt.sh scripts_extra/ 2>/dev/null
mv install_reverse_proxy_test.sh scripts_extra/ 2>/dev/null

echo "✅ Moved legacy or optional service scripts to scripts_extra/"

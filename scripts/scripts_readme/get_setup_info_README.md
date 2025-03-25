I'll create a shell script that gathers system information, which will be useful for diagnosing issues or documenting your system configuration.

This enhanced system information gathering script provides comprehensive diagnostics for your system. It collects detailed information about:

- System and OS details
- Resource usage (disk, memory, CPU)
- Installed packages
- Running services with special attention to critical services
- Network configuration and port usage
- Firewall rules
- Environment variables
- User permissions and group memberships
- Docker containers and Kubernetes resources
- Configuration files for SSLH and NGINX

The script includes several improvements over the original:

1. **Organized output**: Creates a timestamped directory for all output files
2. **Better formatting**: Adds headers and sections for improved readability
3. **Enhanced compatibility**: Checks for command availability and provides alternatives
4. **Special focus on port 443**: Specifically checks port 443 usage as requested
5. **Configuration inspection**: Examines SSLH and NGINX configs to verify proper setup
6. **Failsafes**: Handles errors gracefully when commands aren't available
7. **Summary report**: Creates a concise overview of the most important information
8. **Archive creation**: Packages everything into a tar.gz file for easy sharing

To use the script:
1. Save it to a file (e.g., `get_setup_info.sh`)
2. Make it executable: `chmod +x get_setup_info.sh`
3. Run it: `./get_setup_info.sh`
4. Review the summary: `cat system_info_*/summary.txt`

This will help you verify that SSH and HTTPS are properly configured to share port 443 as implemented in your setup.sh script.

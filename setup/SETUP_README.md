Based on the filenames in the image (`get_setup_info.sh`, `setup_script.sh`, `setup.sh`, and `setup.yml`), here’s the correct sequence to execute the setup:

### **Step 1: Extract System Information (Optional)**
Run this if you want to gather system details before setting up:
```bash
chmod +x get_setup_info.sh
./get_setup_info.sh
```
This script will generate system information files but does not install or configure anything.

### **Step 2: Run `setup.sh` to Configure the System**
Since `setup.sh` is designed to dynamically read from `setup.yml`, it will:
- Check and install missing packages.
- Configure networking, firewall, and user permissions.
- Restore system state based on the required configuration.

Run:
```bash
chmod +x setup.sh
./setup.sh
```

### **Step 3: Remove `setup_script.sh` (If Redundant)**
If `setup.sh` fully replaces `setup_script.sh`, you no longer need `setup_script.sh`. Delete it:
```bash
rm setup_script.sh
```

---

### **Final YAML Output**
```yaml
####
execution_sequence:
  1: "Run `chmod +x get_setup_info.sh && ./get_setup_info.sh` (Optional - Gather system details)"
  2: "Run `chmod +x setup.sh && ./setup.sh` (Main setup - Installs and configures everything)"
  3: "Delete `setup_script.sh` if `setup.sh` is complete (`rm setup_script.sh`)"
####
```

Now, **`setup.sh` is the only required file** for setting up a new Ubuntu instance. 🚀

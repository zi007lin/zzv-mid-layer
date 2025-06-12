Here is a full `vscode_jfrog.md` file that explains how to **manually inject a token into `.jfrog/jfrog-cli.conf`** and configure **VSCode + environment variables** for **token-based access to JFrog Artifactory**, including support for Go, Python, and Node.js/NPM:

---

### 📄 `vscode_jfrog.md`

````md
# 🔐 VSCode + JFrog Artifactory Token Integration Guide

This guide describes how to configure **VSCode**, **JFrog CLI**, and various language environments (Go, Python, Node.js) to authenticate using a **permanent access token** for JFrog Artifactory, e.g., `https://artifactrepository.citigroup.net`.

---

## ✅ STEP 1: Inject Token into `.jfrog/jfrog-cli.conf`

### Location:
- Windows: `%USERPROFILE%\.jfrog\jfrog-cli.conf`
- Linux/macOS: `~/.jfrog/jfrog-cli.conf`

### Manual Token Injection (Example):
Open or create the file and insert the following:

```json
{
  "version": "2",
  "artifactory": [
    {
      "serverId": "citi-jfrog",
      "url": "https://artifactrepository.citigroup.net/artifactory",
      "accessToken": "AKCpBuoBsB5EyY8",  // Replace with your actual token
      "isDefault": true
    }
  ]
}
````

> 💡 If you used `jfrog rt config`, this file is auto-generated. You can also manually edit it to rotate tokens.

---

## ✅ STEP 2: Global VSCode Settings (settings.json)

Open with: `Ctrl+Shift+P → Preferences: Open Settings (JSON)`

```jsonc
{
  // Go support with JFrog as GOPROXY
  "go.toolsEnvVars": {
    "GOPROXY": "https://ds85201:AKCpBuoBsB5EyY8@artifactrepository.citigroup.net/artifactory/api/go/goproxy",
    "GONOSUMDB": "github.com,citigroup.net"
  },

  // Python: use pip via Artifactory
  "python.envFile": "${workspaceFolder}/.env",
  "terminal.integrated.env.windows": {
    "PIP_INDEX_URL": "https://ds85201:AKCpBuoBsB5EyY8@artifactrepository.citigroup.net/artifactory/api/pypi/pypi-virtual/simple"
  },

  // NPM
  "npm.registry": "https://artifactrepository.citigroup.net/artifactory/api/npm/npm-virtual/"
}
```

---

## ✅ STEP 3: Tool-Specific Setup

### A. Go (persistent env config)

```bash
go env -w GOPROXY=https://ds85201:AKCpBuoBsB5EyY8@artifactrepository.citigroup.net/artifactory/api/go/goproxy
go env -w GONOSUMDB=github.com,citigroup.net
```

### B. Python pip (Windows: `pip.ini`)

File: `C:\Users\<You>\pip\pip.ini`

```ini
[global]
index-url = https://ds85201:AKCpBuoBsB5EyY8@artifactrepository.citigroup.net/artifactory/api/pypi/pypi-virtual/simple
```

### C. NPM (Windows: `%USERPROFILE%\.npmrc`)

```ini
registry=https://artifactrepository.citigroup.net/artifactory/api/npm/npm-virtual/
//artifactrepository.citigroup.net/artifactory/api/npm/npm-virtual/:_authToken=AKCpBuoBsB5EyY8
always-auth=true
```

---

## ✅ STEP 4: PowerShell Profile (Auto-load on Terminal Open)

Open your PowerShell profile:

```powershell
notepad $PROFILE
```

Add:

```powershell
$env:GOPROXY = "https://ds85201:AKCpBuoBsB5EyY8@artifactrepository.citigroup.net/artifactory/api/go/goproxy"
$env:GONOSUMDB = "github.com,citigroup.net"
$env:PIP_INDEX_URL = "https://ds85201:AKCpBuoBsB5EyY8@artifactrepository.citigroup.net/artifactory/api/pypi/pypi-virtual/simple"
```

---

## 🛑 Security Tips

* Never commit tokens to version control
* Prefer using JFrog's built-in token management (`accessToken`) over storing in CLI flags
* Rotate tokens regularly in `.jfrog/jfrog-cli.conf`

---

## ✅ Optional: JFrog CLI Testing

After configuration, test it:

```bash
jfrog rt ping --server-id=citi-jfrog
```

If successful:

```text
OK
```

---

**Maintained by:** `Dan (Citi GCP Observability Sprint)`
**Last Updated:** 2025-06-12

```

---

Let me know if you want this exported as a `.md` file or zipped with a sample `.env`, `.npmrc`, and `pip.ini`.
```

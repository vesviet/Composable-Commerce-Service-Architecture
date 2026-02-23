# IDE & Tools Setup

**Purpose**: Complete IDE configuration and development tools setup  
**Audience**: Developers setting up their development environment  

---

## 🚀 Quick Start

### VS Code (Recommended)
```bash
# Install VS Code
brew install --cask visual-studio-code  # macOS
sudo snap install code --classic         # Ubuntu
# Download from https://code.visualstudio.com/ for Windows
```

### Essential Extensions
```bash
# Core Go development
code --install-extension golang.go
code --install-extension golang.go-nightly

# Git & collaboration
code --install-extension eamodio.gitlens
code --install-extension ms-vscode.git-graph

# Docker & Kubernetes
code --install-extension ms-azuretools.vscode-docker
code --install-extension ms-kubernetes-tools.vscode-kubernetes-tools

# API testing
code --install-extension humao.rest-client
code --install-extension ms-vscode.thunder-client

# Productivity
code --install-extension redhat.vscode-yaml
code --install-extension ms-vscode.vscode-json
```

---

## ⚙️ VS Code Configuration

### Workspace Settings (`.vscode/settings.json`)
```json
{
  "go.useLanguageServer": true,
  "go.formatTool": "goimports",
  "go.lintTool": "golangci-lint",
  "go.lintOnSave": "workspace",
  "go.vetOnSave": "workspace",
  "go.buildOnSave": "workspace",
  "go.testFlags": ["-v"],
  "go.coverOnSave": true,
  
  "editor.formatOnSave": true,
  "editor.codeActionsOnSave": {
    "source.organizeImports": true
  },
  "editor.rulers": [80, 120],
  "editor.tabSize": 4,
  "editor.insertSpaces": false,
  
  "files.exclude": {
    "**/vendor": true,
    "**/bin": true,
    "**/dist": true
  },
  
  "git.enableSmartCommit": true,
  "git.autofetch": true
}
```

### Launch Configuration (`.vscode/launch.json`)
```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Launch Auth Service",
      "type": "go",
      "request": "launch",
      "mode": "auto",
      "program": "${workspaceFolder}/auth/cmd/auth/main.go",
      "args": ["-conf", "${workspaceFolder}/auth/configs/config.yaml"],
      "env": {
        "ENVIRONMENT": "development",
        "LOG_LEVEL": "debug"
      },
      "console": "integratedTerminal"
    }
  ]
}
```

### Tasks (`.vscode/tasks.json`)
```json
{
  "version": "2.0.0",
  "tasks": [
    {
      "label": "go: build",
      "type": "shell",
      "command": "go",
      "args": ["build", "./..."],
      "group": {"kind": "build", "isDefault": true}
    },
    {
      "label": "go: test",
      "type": "shell",
      "command": "go",
      "args": ["test", "./...", "-v"],
      "group": {"kind": "test", "isDefault": true}
    }
  ]
}
```

---

## 🐹 GoLand Setup

### Initial Configuration
1. **Go SDK**: File → Settings → Go → GOROOT → Set Go installation path
2. **GOPATH**: File → Settings → Go → GOPATH → Set workspace path
3. **Go Modules**: Enable Go Modules integration
4. **Code Style**: Configure tabs (use tab character, size 4)

### Run/Debug Configuration
1. **Run → Edit Configurations**
2. **Add Go Build configuration**
3. **Set program directory** to service directory
4. **Add arguments**: `-conf configs/config.yaml`
5. **Environment**: `ENVIRONMENT=development`, `LOG_LEVEL=debug`

---

## 🛠️ Essential Development Tools

### Go Tools
```bash
# Install essential tools
go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest
go install github.com/air-verse/air@latest
go install github.com/swaggo/swag/cmd/swag@latest
go install google.golang.org/protobuf/cmd/protoc-gen-go@latest
go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@latest

# Add to PATH
export PATH=$PATH:$(go env GOPATH)/bin
```

### API Testing
```bash
# Postman
brew install --cask postman  # macOS
snap install postman        # Ubuntu

# Insomnia (alternative)
brew install --cask insomnia  # macOS
```

### Database Tools
```bash
# TablePlus (recommended)
brew install --cask tableplus  # macOS

# DBeaver (free)
brew install --cask dbeaver-community  # macOS
sudo snap install dbeaver-ce           # Ubuntu
```

### Docker Tools
```bash
# Lazydocker (TUI for Docker)
brew install jesseduffield/lazydocker/lazydocker  # macOS
```

---

## 🎯 Productivity Tips

### VS Code Shortcuts
- **Go to Definition**: F12
- **Go to Symbol**: Ctrl+Shift+O
- **Format Document**: Shift+Alt+F
- **Toggle Line Comment**: Ctrl+/
- **Toggle Block Comment**: Shift+Alt+A
- **Run Task**: Ctrl+Shift+P → "Tasks: Run Task"
- **Start Debugging**: F5

### GoLand Shortcuts
- **Go to Definition**: Ctrl+B
- **Find Usages**: Alt+F7
- **Format Code**: Ctrl+Alt+L
- **Optimize Imports**: Ctrl+Alt+O
- **Run**: Shift+F10
- **Debug**: Shift+F9

### Debugging Tips
1. **Use conditional breakpoints** for complex scenarios
2. **Set exception breakpoints** to catch panics
3. **Use the debug console** to evaluate expressions
4. **Watch variables** to monitor state changes
5. **Use step filters** to skip library code

---

## 🔧 Troubleshooting

### Common Issues

#### Go Extension Not Working
```bash
# Update Go extension
code --install-extension golang.go@latest

# Clear Go extension cache
rm -rf ~/Library/Application\ Support/Code/User/globalStorage/golang.go
```

#### Module Issues
```bash
# Clean module cache
go clean -modcache
go mod download
go mod tidy
```

#### Docker Integration Issues
```bash
# Restart Docker daemon
sudo systemctl restart docker  # Linux
# Restart Docker Desktop       # Windows/macOS

# Check Docker integration in VS Code
# Command Palette → "Docker: Logs"
```

---

## 📚 Learning Resources

### Official Documentation
- [VS Code Documentation](https://code.visualstudio.com/docs)
- [GoLand Documentation](https://www.jetbrains.com/go/documentation/)
- [Go Extension for VS Code](https://marketplace.visualstudio.com/items?itemName=golang.go)

### Tutorials
- [VS Code Go Tutorial](https://code.visualstudio.com/docs/go/get-started)
- [GoLand Webinars](https://www.jetbrains.com/go/webinars/)
- [Go Debugging Guide](https://github.com/golang/vscode-go/blob/master/docs/debugging.md)

---

**Last Updated**: February 3, 2026  
**Review Cycle**: Monthly or when tools change  
**Maintained By**: Development Team

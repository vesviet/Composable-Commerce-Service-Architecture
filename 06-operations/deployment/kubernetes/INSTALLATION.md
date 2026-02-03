# Installation Checklist - k3d + Tilt

## 📋 Prerequisites Check

- [ ] **OS**: Linux (Ubuntu/Debian) hoặc Mac
- [ ] **Docker**: Đã cài đặt và đang chạy
- [ ] **Git**: Đã cài đặt
- [ ] **Disk Space**: Ít nhất 10GB trống
- [ ] **RAM**: Ít nhất 8GB (khuyến nghị 16GB)

### Verify Prerequisites

```bash
# Check Docker
docker --version
docker ps  # Should work without errors

# Check Git
git --version

# Check disk space
df -h

# Check RAM
free -h
```

---

## 🔧 Step 1: Install k3d

### Option A: Install to ~/.local/bin (No sudo required) ⭐ Recommended

```bash
# 1. Create local bin directory
mkdir -p ~/.local/bin

# 2. Download k3d binary
K3D_VERSION=v5.7.0
curl -Lo /tmp/k3d https://github.com/k3d-io/k3d/releases/download/${K3D_VERSION}/k3d-linux-amd64

# 3. Make executable
chmod +x /tmp/k3d

# 4. Move to local bin
mv /tmp/k3d ~/.local/bin/k3d

# 5. Add to PATH (add to ~/.zshrc or ~/.bashrc)
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc

# 6. Verify installation
k3d version
```

**Checklist:**
- [ ] Created ~/.local/bin directory
- [ ] Downloaded k3d binary
- [ ] Made executable
- [ ] Moved to ~/.local/bin
- [ ] Added to PATH
- [ ] Verified: `k3d version` works

### Option B: Install with script (Requires sudo)

```bash
# Install k3d
curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash

# Verify
k3d version
```

**Checklist:**
- [ ] Ran install script
- [ ] Verified: `k3d version` works

---

## 🔧 Step 2: Install kubectl

### Option A: Install to ~/.local/bin (No sudo required) ⭐ Recommended

```bash
# 1. Download kubectl
KUBECTL_VERSION=$(curl -L -s https://dl.k8s.io/release/stable.txt)
curl -LO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl"

# 2. Make executable
chmod +x kubectl

# 3. Move to local bin
mv kubectl ~/.local/bin/kubectl

# 4. Verify installation
kubectl version --client
```

**Checklist:**
- [ ] Downloaded kubectl
- [ ] Made executable
- [ ] Moved to ~/.local/bin
- [ ] Verified: `kubectl version --client` works

### Option B: Install with package manager (Requires sudo)

```bash
# Ubuntu/Debian
curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo gpg --dearmor -o /usr/share/keyrings/kubernetes-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update
sudo apt-get install -y kubectl

# Verify
kubectl version --client
```

**Checklist:**
- [ ] Added Kubernetes repository
- [ ] Installed kubectl
- [ ] Verified: `kubectl version --client` works

---

## 🔧 Step 3: Install Helm (Optional, for Dapr)

### Option A: Install to ~/.local/bin (No sudo required) ⭐ Recommended

```bash
# 1. Download Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# 2. If script requires sudo, download binary manually:
HELM_VERSION=v3.14.0
curl -Lo /tmp/helm.tar.gz https://get.helm.sh/helm-${HELM_VERSION}-linux-amd64.tar.gz
tar -xzf /tmp/helm.tar.gz -C /tmp
mv /tmp/linux-amd64/helm ~/.local/bin/helm
rm -rf /tmp/helm.tar.gz /tmp/linux-amd64

# 3. Verify installation
helm version
```

**Checklist:**
- [ ] Downloaded Helm
- [ ] Extracted and moved to ~/.local/bin
- [ ] Verified: `helm version` works

### Option B: Install with script (Requires sudo)

```bash
# Install Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Verify
helm version
```

**Checklist:**
- [ ] Ran install script
- [ ] Verified: `helm version` works

---

## 🔧 Step 4: Install Tilt

### Option A: Install with script (Recommended)

```bash
# 1. Install Tilt
curl -fsSL https://raw.githubusercontent.com/tilt-dev/tilt/master/scripts/install.sh | bash

# 2. Verify installation
tilt version
```

**Checklist:**
- [ ] Ran install script
- [ ] Verified: `tilt version` works

### Option B: Install manually (No sudo required)

```bash
# 1. Download Tilt binary
TILT_VERSION=0.33.7
curl -fsSL https://github.com/tilt-dev/tilt/releases/download/v${TILT_VERSION}/tilt.${TILT_VERSION}.linux.x86_64.tar.gz | tar -xzf -

# 2. Move to local bin
mv tilt ~/.local/bin/tilt

# 3. Verify installation
tilt version
```

**Checklist:**
- [ ] Downloaded Tilt binary
- [ ] Extracted and moved to ~/.local/bin
- [ ] Verified: `tilt version` works

---

## ✅ Step 5: Verify All Installations

Run this command to verify all tools are installed:

```bash
echo "=== Installation Verification ==="
echo ""
echo "k3d:"
k3d version || echo "❌ k3d not found"
echo ""
echo "kubectl:"
kubectl version --client || echo "❌ kubectl not found"
echo ""
echo "helm:"
helm version || echo "❌ helm not found"
echo ""
echo "tilt:"
tilt version || echo "❌ tilt not found"
echo ""
echo "docker:"
docker --version || echo "❌ docker not found"
```

**Checklist:**
- [ ] k3d version works
- [ ] kubectl version works
- [ ] helm version works (optional)
- [ ] tilt version works
- [ ] docker version works

---

## 🚀 Step 6: Setup k3d Cluster

```bash
# 1. Navigate to project root
cd /home/tuananh/microservices

# 2. Run setup script
./k8s-local/setup-cluster.sh

# 3. Verify cluster
kubectl cluster-info
kubectl get nodes
```

**Checklist:**
- [ ] Ran setup-cluster.sh
- [ ] Cluster created successfully
- [ ] `kubectl cluster-info` works
- [ ] `kubectl get nodes` shows nodes

---

## 🎯 Step 7: Test Tilt (Optional)

```bash
# 1. Navigate to project root
cd /home/tuananh/microservices

# 2. Start Tilt (if Tiltfile exists)
tilt up

# 3. Open browser to http://localhost:10350
# 4. Press 'q' to quit Tilt
```

**Checklist:**
- [ ] Tilt starts without errors
- [ ] Tilt UI accessible at http://localhost:10350
- [ ] Can see services in Tilt UI

---

## 🔍 Troubleshooting

### k3d not found

```bash
# Check if in PATH
echo $PATH | grep -q ".local/bin" || echo "⚠️  ~/.local/bin not in PATH"

# Add to PATH
export PATH="$HOME/.local/bin:$PATH"
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

### kubectl not found

```bash
# Check installation
ls -la ~/.local/bin/kubectl

# Add to PATH if needed
export PATH="$HOME/.local/bin:$PATH"
```

### Tilt not found

```bash
# Check installation
ls -la ~/.local/bin/tilt

# Reinstall if needed
curl -fsSL https://raw.githubusercontent.com/tilt-dev/tilt/master/scripts/install.sh | bash
```

### Docker not running

```bash
# Check Docker status
sudo systemctl status docker

# Start Docker
sudo systemctl start docker

# Enable Docker on boot
sudo systemctl enable docker
```

### Permission denied

```bash
# If getting permission errors, check file permissions
chmod +x ~/.local/bin/*

# Or use sudo for system-wide installation
```

---

## 📝 Quick Reference

### Useful Commands

```bash
# k3d
k3d cluster list
k3d cluster start microservices
k3d cluster stop microservices
k3d cluster delete microservices

# kubectl
kubectl cluster-info
kubectl get nodes
kubectl get pods -A

# Tilt
tilt up          # Start Tilt
tilt down        # Stop Tilt
tilt logs        # View logs
tilt doctor      # Check Tilt setup
```

### PATH Configuration

Add to `~/.zshrc` or `~/.bashrc`:

```bash
# Add local bin to PATH
export PATH="$HOME/.local/bin:$PATH"
```

Then reload:
```bash
source ~/.zshrc
# or
source ~/.bashrc
```

---

## ✅ Final Checklist

Before proceeding to setup cluster and deploy services:

- [ ] ✅ k3d installed and working
- [ ] ✅ kubectl installed and working
- [ ] ✅ helm installed and working (optional)
- [ ] ✅ tilt installed and working
- [ ] ✅ docker running
- [ ] ✅ PATH configured correctly
- [ ] ✅ All tools verified with version commands

**Next Steps:**
1. Run `./k8s-local/setup-cluster.sh` to create k3d cluster
2. Run `./k8s-local/deploy-infra.sh` to deploy infrastructure
3. Create Tiltfile for hot reload development
4. Run `tilt up` to start development

---

## 📚 Additional Resources

- [k3d Documentation](https://k3d.io/)
- [Tilt Documentation](https://docs.tilt.dev/)
- [kubectl Documentation](https://kubernetes.io/docs/reference/kubectl/)
- [Helm Documentation](https://helm.sh/docs/)


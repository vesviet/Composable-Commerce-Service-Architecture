# Environment Setup Guide

This guide explains how to set up environment variables for the microservices platform.

---

## 🔐 Required Tokens

### GitLab Personal Access Token

**Required for**: Building Docker images that access private GitLab repositories

**How to generate**:
1. Go to [GitLab Personal Access Tokens](https://gitlab.com/-/user_settings/personal_access_tokens)
2. Create a new token with the following scopes:
   - `read_api`
   - `read_repository`
3. Copy the token and add it to your `.env` file

**Usage**: Used in Docker builds to access private `gitlab.com/ta-microservices/*` repositories

### GitHub Personal Access Token

**Required for**: Documentation deployment, GitHub Actions, or accessing private GitHub repositories

**How to generate**:
1. Go to [GitHub Settings > Developer settings > Personal access tokens](https://github.com/settings/tokens)
2. Generate a new token (classic) with the following permissions:
   - `repo` (for private repositories)
   - `workflow` (for GitHub Actions)
3. Copy the token and add it to your `.env` file

**Usage**: Used for documentation deployment, CI/CD workflows, or accessing private GitHub repositories

---

## 📝 Setup Instructions

### 1. Create `.env` File

Copy the example file:

```bash
cd /home/user/microservices
cp .env.example .env
```

### 2. Update Token Values

Edit `.env` and add your tokens:

```bash
# GitLab Token (required for Docker builds)
GITLAB_TOKEN=your_gitlab_token_here

# GitHub Token (for docs/deployment)
GITHUB_TOKEN=ghp_your_github_token_here
```

### 3. Load Environment Variables

**Option A: Export manually**
```bash
export GITLAB_TOKEN=your_token_here
export GITHUB_TOKEN=your_token_here
```

**Option B: Source .env file**
```bash
# Add to your shell profile (~/.bashrc, ~/.zshrc)
set -a
source /home/user/microservices/.env
set +a
```

**Option C: Use with docker-compose**
```bash
# docker-compose automatically reads .env file
docker compose up -d
```

---

## 🐳 Docker Compose Usage

Docker Compose automatically reads `.env` file from the project root:

```bash
# From project root
cd /home/user/microservices

# Docker Compose will use GITLAB_TOKEN from .env
docker compose up -d
```

**Note**: If `.env` is not found, Docker Compose will use empty string (`${GITLAB_TOKEN:-}`)

---

## 🔒 Security Best Practices

1. **Never commit `.env` file**
   - Already added to `.gitignore`
   - Contains sensitive tokens

2. **Use `.env.example` for documentation**
   - Commit `.env.example` with placeholder values
   - Team members copy and fill in their own tokens

3. **Rotate tokens regularly**
   - Update tokens every 90 days
   - Revoke old tokens when creating new ones

4. **Use different tokens for different environments**
   - Development: Personal tokens
   - Staging/Production: Service account tokens with minimal permissions

5. **Limit token permissions**
   - Only grant necessary scopes
   - Don't use admin tokens for builds

---

## 🧪 Testing Token Setup

### Test GitLab Token

```bash
# Test GitLab token (if curl available)
curl -H "PRIVATE-TOKEN: $GITLAB_TOKEN" https://gitlab.com/api/v4/user
```

### Test GitHub Token

```bash
# Test GitHub token (if curl available)
curl -H "Authorization: token $GITHUB_TOKEN" https://api.github.com/user
```

### Test Docker Build

```bash
# Build a service that uses GITLAB_TOKEN
cd order
docker compose build order-service
# Should succeed if token is valid
```

---

## 📚 Related Documentation

- [Docker Compose Setup](../README.md)
- [Service Development Guide](./DEVELOPMENT.md)
- [Deployment Guide](./DEPLOYMENT.md)

---

## 🆘 Troubleshooting

### Error: "Failed to fetch from GitLab"
- **Cause**: Invalid or missing `GITLAB_TOKEN`
- **Solution**: Check token is set correctly in `.env` or environment

### Error: "Repository not found"
- **Cause**: Token doesn't have `read_repository` permission
- **Solution**: Regenerate token with correct permissions

### Error: "Authentication failed"
- **Cause**: Token expired or revoked
- **Solution**: Generate new token and update `.env`

### Docker Build Fails
- **Cause**: `GITLAB_TOKEN` not passed to Docker build
- **Solution**: Ensure `.env` file exists and is in project root

---

**Last Updated**: December 2024


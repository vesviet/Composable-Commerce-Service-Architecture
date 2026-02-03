# Git Workflow Guide

**Purpose**: Standard Git workflow for the microservices team  
**Audience**: All developers working on the codebase  
**Prerequisites**: Basic Git knowledge, completed [Local Development Setup](../getting-started/local-development-setup.md)  

---

## 🎯 Workflow Philosophy

Our Git workflow is designed for:
- **Collaboration**: Multiple developers working simultaneously
- **Quality**: Code review and automated testing
- **Traceability**: Clear history and change tracking
- **Safety**: Prevent broken code from reaching production
- **Efficiency**: Smooth integration and deployment process

---

## 🌳 Branching Strategy

### Main Branches
```
main (production)
├── develop (staging)
├── feature/user-authentication
├── feature/payment-integration
├── bugfix/login-validation-error
└── hotfix/security-patch
```

### Branch Types

#### **main** Branch
- **Purpose**: Production-ready code
- **Protection**: Direct commits disabled
- **Deployment**: Automatically deployed to production
- **Stability**: Always stable and tested

#### **develop** Branch  
- **Purpose**: Integration and staging environment
- **Protection**: Pull requests required
- **Deployment**: Automatically deployed to staging
- **Stability**: Should be relatively stable

#### **feature/** Branches
- **Purpose**: New features and enhancements
- **Naming**: `feature/description-of-feature`
- **Lifespan**: From development to merge into develop
- **Example**: `feature/user-profile-management`

#### **bugfix/** Branches
- **Purpose**: Bug fixes for issues in production
- **Naming**: `bugfix/description-of-bugfix`
- **Priority**: High priority, fast turnaround
- **Example**: `bugfix/memory-leak-in-auth-service`

#### **hotfix/** Branches
- **Purpose**: Critical fixes for production issues
- **Naming**: `hotfix/critical-security-fix`
- **Process**: Branch from main, merge to main and develop
- **Example**: `hotfix/security-vulnerability-patch`

---

## 🔄 Daily Workflow

### 1. Start Your Day
```bash
# Update your local branches
git checkout main
git pull origin main

git checkout develop  
git pull origin develop

# Check current status
git status
git branch -a
```

### 2. Start New Feature
```bash
# Create feature branch from latest develop
git checkout develop
git pull origin develop
git checkout -b feature/new-user-dashboard

# Verify you're on the new branch
git branch
```

### 3. Work on Your Feature
```bash
# Make your changes
# Edit files, add features, fix bugs...

# Check what you've changed
git status
git diff

# Stage your changes
git add path/to/changed/files
# Or stage all changes
git add .

# Commit with proper message
git commit -m "feat(dashboard): add user profile section

- Implement user profile display
- Add avatar upload functionality
- Include profile editing capabilities
- Add comprehensive unit tests

Closes #TICKET-456"
```

### 4. Keep Branch Updated
```bash
# Regularly sync with develop to avoid conflicts
git checkout develop
git pull origin develop

# Rebase your feature branch
git checkout feature/new-user-dashboard
git rebase develop

# If conflicts occur, resolve them:
git status  # See conflicts
# Edit conflicted files
git add path/to/resolved/files
git rebase --continue
```

### 5. Push and Create Merge Request
```bash
# Push your branch
git push origin feature/new-user-dashboard

# Create merge request in GitLab UI
# Target: develop branch
# Title: feat(dashboard): add user profile section
# Description: Include details and testing info
```

---

## 📝 Commit Message Standards

### Commit Message Format
```
<type>(<scope>): <subject>

<body>

<footer>
```

### Types
- **feat**: New feature
- **fix**: Bug fix
- **docs**: Documentation changes
- **style**: Code formatting, no functional changes
- **refactor**: Code refactoring, no functional changes
- **test**: Adding or updating tests
- **chore**: Maintenance tasks, dependencies, etc.
- **perf**: Performance improvements
- **ci**: CI/CD related changes

### Scopes
- **service-name**: Specific service (auth, order, etc.)
- **common**: Shared library changes
- **infra**: Infrastructure changes
- **docs**: Documentation changes
- **ci**: CI/CD changes

### Examples

#### Good Commit Messages
```bash
feat(auth): add two-factor authentication

- Implement TOTP support
- Add backup codes generation
- Update login flow to support 2FA
- Add comprehensive tests

Closes #AUTH-123

fix(order): resolve memory leak in order processing

- Fix goroutine leak in order service
- Add proper resource cleanup
- Add memory usage monitoring

Fixes #ORDER-456

docs(readme): update local development setup

- Add Docker Desktop installation
- Update Go version requirements
- Fix broken links
- Add troubleshooting section
```

#### Bad Commit Messages
```bash
# Too generic
git commit -m "fixed bug"

# No description
git commit -m "feat: add stuff"

# Wrong format
git commit -m "I fixed the login issue"

# No scope
git commit -m "feat: add user authentication"
```

---

## 🔀 Merge Request (MR) Process

### Creating Merge Request
1. **Push Branch**: Ensure your branch is pushed to origin
2. **Create MR**: Use GitLab UI to create merge request
3. **Fill Template**: Complete all sections in MR template
4. **Assign Reviewer**: Request review from team member
5. **Wait for CI**: Ensure all CI checks pass

### MR Template
```markdown
## Description
Brief description of what this MR does and why it's needed.

## Type of Change
- [ ] Bug fix (non-breaking change that fixes an issue)
- [ ] New feature (non-breaking change that adds functionality)
- [ ] Breaking change (fix or feature that would cause existing functionality to not work as expected)
- [ ] Documentation update

## Testing
- [ ] Unit tests pass
- [ ] Integration tests pass
- [ ] Manual testing completed
- [ ] Performance testing completed (if applicable)

## Checklist
- [ ] Code follows project style guidelines
- [ ] Self-review of the code completed
- [ ] Code is self-documentary with comments where needed
- [ ] Documentation updated if required
- [ ] Tests added/updated for new functionality
- [ ] No breaking changes without proper communication

## Screenshots/Demo
(If applicable)

## Related Issues
Closes #TICKET-123
```

### Review Process
1. **Automated Checks**: CI/CD pipeline runs automatically
2. **Code Review**: Assigned reviewer checks your code
3. **Feedback**: Reviewer provides suggestions or requests changes
4. **Updates**: Make requested changes and push updates
5. **Approval**: Reviewer approves the MR
6. **Merge**: Merge into target branch (usually develop)

---

## 🚨 Handling Conflicts

### During Rebase
```bash
# Rebase with develop
git checkout feature/my-feature
git rebase develop

# If conflicts occur:
git status  # See conflicted files

# Edit conflicted files and resolve conflicts
# Remove conflict markers and choose correct code

# Mark conflicts as resolved
git add path/to/resolved/file
git add path/to/another/resolved/file

# Continue rebase
git rebase --continue

# If you want to abort and start over
git rebase --abort
```

### During Merge
```bash
# When merging into develop
git checkout develop
git merge feature/my-feature

# Resolve conflicts in same way
# Edit files, add them, then commit
git commit  # This will create a merge commit
```

### Best Practices for Conflicts
- **Communicate**: Let your team know about conflicts
- **Small Changes**: Keep branches small to reduce conflicts
- **Regular Sync**: Rebase frequently with develop
- **Ask for Help**: Don't hesitate to ask for help with complex conflicts

---

## 🔙 Hotfix Process

### When to Use Hotfix
- **Critical Security Issues**: Vulnerabilities that need immediate fixing
- **Production Outages**: Bugs causing service disruption
- **Data Corruption**: Issues affecting data integrity
- **Revenue Impact**: Bugs affecting business operations

### Hotfix Workflow
```bash
# 1. Create hotfix branch from main
git checkout main
git pull origin main
git checkout -b hotfix/critical-security-fix

# 2. Fix the issue
# Make minimal, focused changes
git add .
git commit -m "hotfix(security): patch SQL injection vulnerability

- Sanitize user input in query parameters
- Add input validation middleware
- Update security tests

Fixes #SECURITY-789"

# 3. Test thoroughly
# Run all tests, manual testing, security scans

# 4. Merge to main
git checkout main
git merge hotfix/critical-security-fix
git tag -a v1.2.1 -m "Release version 1.2.1"
git push origin main --tags

# 5. Also merge to develop to include in next release
git checkout develop
git merge hotfix/critical-security-fix
git push origin develop

# 6. Delete hotfix branch
git branch -d hotfix/critical-security-fix
git push origin --delete hotfix/critical-security-fix
```

---

## 🛠️ Advanced Git Techniques

### Interactive Rebase
```bash
# Clean up commit history before merging
git checkout feature/my-feature
git rebase -i HEAD~5

# Commands in interactive rebase:
# pick: use commit
# reword: change commit message
# edit: amend commit
# squash: combine with previous commit
# fixup: combine with previous (discard message)
# drop: remove commit
```

### Cherry-pick
```bash
# Apply specific commit to another branch
git checkout develop
git cherry-pick abc1234  # Commit hash from feature branch

# Cherry-pick without committing
git cherry-pick --no-commit abc1234
```

### Stashing
```bash
# Save current work temporarily
git stash push -m "work in progress"

# List stashes
git stash list

# Apply stash
git stash pop

# Apply and keep stash
git stash apply stash@{0}

# Drop stash
git stash drop stash@{0}
```

### Bisect for Bug Hunting
```bash
# Find commit that introduced bug
git bisect start
git bisect bad          # Current version has bug
git bisect good v1.0.0   # Known good version

# Git will checkout commits for testing
# Test each version and mark as good or bad
git bisect good         # This version works
git bisect bad          # This version has bug

# When done, git shows the problematic commit
git bisect reset
```

---

## 📊 Git Best Practices

### Daily Habits
- **Pull Before Work**: Always start with `git pull`
- **Commit Often**: Small, focused commits
- **Push Regularly**: Don't let branches get too far behind
- **Clean History**: Use rebase to keep history clean
- **Descriptive Messages**: Write clear, informative commit messages

### Branch Management
- **Delete Merged Branches**: Keep repository clean
- **Protect Main Branches**: Use branch protection rules
- **Meaningful Names**: Use descriptive branch names
- **Short-lived Branches**: Merge branches promptly
- **Regular Cleanup**: Remove old, unused branches

### Collaboration
- **Communicate**: Let team know about large changes
- **Review Code**: Participate in code reviews
- **Help Others**: Assist with conflicts and issues
- **Document**: Document significant decisions
- **Follow Standards**: Maintain consistency

---

## 🔍 Troubleshooting

### Common Issues

#### "Detached HEAD" State
```bash
# You're in detached HEAD state
git checkout main  # Or any other branch
git checkout -b new-branch-name  # If you want to keep changes
```

#### Accidentally Committed to Wrong Branch
```bash
# Move commit to correct branch
git checkout correct-branch
git cherry-pick wrong-branch~1  # Get the commit
git checkout wrong-branch
git reset --hard HEAD~1        # Remove from wrong branch
```

#### Lost Commit
```bash
# Find lost commit
git reflog

# Recover lost commit
git checkout abc1234  # Commit hash from reflog
git checkout -b recovery-branch
```

#### Merge Gone Wrong
```bash
# Abort merge
git merge --abort

# Or reset to before merge
git reset --hard HEAD~1
```

---

## 📞 Getting Help

### Resources
- **Git Documentation**: [https://git-scm.com/doc](https://git-scm.com/doc)
- **GitLab Documentation**: [https://docs.gitlab.com/ee/git/](https://docs.gitlab.com/ee/git/)
- **Interactive Git Tutorial**: [https://learngitbranching.js.org/](https://learngitbranching.js.org/)

### Team Support
- **Slack #git-help**: Git-specific questions
- **Code Review**: Ask for help in MR comments
- **Senior Developers**: Mentorship and guidance
- **Tech Lead**: Complex workflow questions

---

**Last Updated**: February 3, 2026  
**Review Cycle**: Quarterly or when workflow changes  
**Maintained By**: Development Team

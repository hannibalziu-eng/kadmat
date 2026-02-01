# 🚀 Kadmat Development Workflow

## 📋 Branch Strategy

### Main Branches:
- **`main`** - Production-ready code, stable releases only
- **`develop`** - Integration branch for ongoing development

### Supporting Branches:
- **`feature/*`** - New features (e.g., `feature/payment-integration`)
- **`bugfix/*`** - Bug fixes (e.g., `bugfix/auth-error`)
- **`hotfix/*`** - Critical production fixes (e.g., `hotfix/crash-fix`)
- **`release/*`** - Release preparation (e.g., `release/v1.2.0`)

## 🔄 Workflow Steps

### 1. Starting New Work
```bash
# Always start from develop
git checkout develop
git pull origin develop

# Create feature branch
git checkout -b feature/your-feature-name
```

### 2. Making Changes
```bash
# Stage your changes
git add .

# Commit with clear message
git commit -m "feat: Add payment confirmation screen"
```

### 3. Pushing Changes
```bash
# Push to remote
git push -u origin feature/your-feature-name
```

### 4. Creating Pull Request
- Go to GitHub: https://github.com/hannibalziu-eng/kadmat
- Create PR from `feature/*` → `develop`
- Add description and reviewers
- Wait for approval

### 5. Merging to Develop
```bash
# After PR approval
git checkout develop
git pull origin develop
git merge feature/your-feature-name
git push origin develop
```

## 📝 Commit Message Convention

```
type(scope): description

Types:
- feat: New feature
- fix: Bug fix
- docs: Documentation changes
- style: Code style changes (formatting)
- refactor: Code refactoring
- test: Adding tests
- chore: Maintenance tasks

Examples:
- feat(auth): Add biometric login
- fix(payment): Resolve transaction timeout
- docs(readme): Update installation steps
```

## 🏷️ Version Tagging

```bash
# Tag releases
git tag -a v1.0.0 -m "Release version 1.0.0"
git push origin v1.0.0
```

## 🔍 Code Review Checklist

Before submitting PR:
- [ ] Code follows Flutter style guide
- [ ] All tests pass
- [ ] No console errors
- [ ] Documentation updated
- [ ] No sensitive data in code
- [ ] Performance tested

## 🚨 Hotfix Workflow

```bash
# For critical production bugs
git checkout main
git pull origin main
git checkout -b hotfix/critical-bug

# Fix the bug
git add .
git commit -m "fix: Critical auth token issue"
git push origin hotfix/critical-bug

# Create PR to main
# After approval, merge to main AND develop
```

## 📊 Project Status

- **Current Branch:** develop
- **Latest Commit:** d627fc5
- **Flutter Version:** 3.x
- **Backend:** Node.js + Supabase

## 🔗 Useful Links

- Repository: https://github.com/hannibalziu-eng/kadmat
- Issues: https://github.com/hannibalziu-eng/kadmat/issues
- Actions: https://github.com/hannibalziu-eng/kadmat/actions

---

**Last Updated:** 2026-02-02

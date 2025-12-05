---
description: Sync changes to GitHub automatically after making code changes
---

# Git Sync Workflow

After making code changes, run this workflow to sync with GitHub:

// turbo-all

1. Stage all changes:
```bash
cd /Users/wew/Desktop/kadmat && git add .
```

2. Commit with descriptive message:
```bash
cd /Users/wew/Desktop/kadmat && git commit -m "Update: [describe changes]"
```

3. Push to GitHub:
```bash
cd /Users/wew/Desktop/kadmat && git push origin main
```

## Notes
- Replace `[describe changes]` with actual description of what changed
- If push fails due to conflicts, run: `git pull origin main --rebase` first

# Firebase Test Lab Setup Guide

## Overview
This guide explains how to set up Firebase Test Lab integration with GitHub Actions for automated testing of the Kadmat app.

## Prerequisites
- GitHub repository with admin access
- Google Cloud Platform (GCP) account
- Firebase project: `lykadmat`
- gcloud CLI installed locally

## Step 1: Create Service Account

### 1.1 Create Service Account in GCP Console
```bash
gcloud iam service-accounts create github-actions \\
  --project=lykadmat \\
  --display-name="GitHub Actions CI/CD"
```

### 1.2 Grant Permissions
```bash
# Firebase Test Lab Admin
gcloud projects add-iam-policy-binding lykadmat \\
  --member="serviceAccount:github-actions@lykadmat.iam.gserviceaccount.com" \\
  --role="roles/firebase.testlabAdmin"

# Cloud Storage Admin (for test results)
gcloud projects add-iam-policy-binding lykadmat \\
  --member="serviceAccount:github-actions@lykadmat.iam.gserviceaccount.com" \\
  --role="roles/storage.admin"
```

### 1.3 Create JSON Key
```bash
gcloud iam service-accounts keys create github-actions-key.json \\
  --iam-account=github-actions@lykadmat.iam.gserviceaccount.com
```

⚠️ **Important**: Keep this JSON file secure and never commit it to the repository!

## Step 2: Create Cloud Storage Bucket

```bash
# Create bucket for test results
gsutil mb -p lykadmat gs://test-lab-kadmat

# Set lifecycle to auto-delete old test results after 30 days
gsutil lifecycle set /dev/stdin gs://test-lab-kadmat <<EOF
{
  "lifecycle": {
    "rule": [{
      "action": {"type": "Delete"},
      "condition": {"age": 30}
    }]
  }
}
EOF
```

## Step 3: Configure GitHub Secrets

### 3.1 Navigate to GitHub Secrets
1. Go to `https://github.com/hannibalziu-eng/kadmat/settings/secrets/actions`
2. Click **New repository secret**

### 3.2 Add Required Secrets

#### GCP_SA_KEY
```
Name: GCP_SA_KEY
Value: <paste entire contents of github-actions-key.json>
```

#### GCP_PROJECT_ID (Optional)
```
Name: GCP_PROJECT_ID
Value: lykadmat
```

#### SUPABASE_TEST_URL (Optional - for E2E tests)
```
Name: SUPABASE_TEST_URL
Value: https://your-test-project.supabase.co
```

#### SUPABASE_TEST_ANON_KEY (Optional - for E2E tests)
```
Name: SUPABASE_TEST_ANON_KEY
Value: your-test-anon-key
```

## Step 4: Verify Workflow

### 4.1 Push a Test Commit
```bash
cd /path/to/kadmat
git add .
git commit -m "test: Trigger Firebase Test Lab workflow"
git push origin main
```

### 4.2 Monitor Workflow
1. Go to `https://github.com/hannibalziu-eng/kadmat/actions`
2. Click on the latest **Firebase Test Lab** workflow run
3. Check each step's logs

### 4.3 Expected Behavior
- ✅ Unit tests run successfully
- ✅ App APK builds
- ✅ Test APK builds (if integration tests exist)
- ✅ APKs uploaded as artifacts
- ⚠️ Firebase Test Lab runs only on `main` branch and only if `GCP_SA_KEY` secret exists

## Step 5: View Test Results

### Firebase Console
1. Go to `https://console.firebase.google.com/project/lykadmat/testlab`
2. View test matrix results
3. Check device screenshots and logs

### GitHub Actions
1. Go to workflow run page
2. Download artifacts (APKs)
3. View logs for detailed test output

### Cloud Storage
```bash
# List test results
gsutil ls gs://test-lab-kadmat/

# Download specific test result
gsutil -m cp -r gs://test-lab-kadmat/test-results-123456/ ./
```

## Troubleshooting

### Build Fails: "gradlew: Permission denied"
```bash
cd android
chmod +x gradlew
git add gradlew
git commit -m "fix: Make gradlew executable"
git push
```

### Firebase Test Lab: "Permission denied"
- Verify service account has `firebase.testlabAdmin` role
- Check that `GCP_SA_KEY` secret is correctly formatted JSON

### Test APK Not Found
- Ensure integration_test/ directory exists
- Check that `assembleDebugAndroidTest` gradle task succeeds

### Bucket Does Not Exist
```bash
gsutil mb -p lykadmat gs://test-lab-kadmat
```

## Cost Optimization

### Free Tier Limits
- Firebase Test Lab: **10 physical device tests/day** free
- After that: ~$1/hour for physical devices

### Recommendations
1. Run Test Lab only on `main` branch (already configured)
2. Use `continue-on-error: true` to not block CI on Test Lab failures
3. Set lifecycle policy on storage bucket (already configured)
4. Use virtual devices for development PRs:
   ```yaml
   --device model=Pixel2.arm,version=30,locale=en
   ```

## Workflow Configuration

The workflow file is located at: `.github/workflows/firebase_test_lab.yml`

### Triggers
- Push to `main` branch
- Pull requests to `main` branch
- Manual trigger (workflow_dispatch)

### Key Features
- Multi-device testing (Pixel 5, MediumPhone)
- APK artifact uploads
- Optional Firebase Test Lab (requires secrets)
- Code coverage reporting

## Next Steps

1. ✅ Create service account and secrets
2. ✅ Create storage bucket
3. ⏳ Add integration_test/ directory to repository
4. ⏳ Test workflow end-to-end
5. ⏳ Add more devices to test matrix

## References

- [Firebase Test Lab Documentation](https://firebase.google.com/docs/test-lab)
- [GitHub Actions for Android](https://github.com/actions/setup-java)
- [Flutter CI/CD Best Practices](https://docs.flutter.dev/deployment/cd)

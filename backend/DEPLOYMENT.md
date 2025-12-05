# Kadmat Production Deployment Guide

## Prerequisites

- ✅ Node.js 18+ installed
- ✅ Supabase project created
- ✅ Flutter SDK installed
- ✅ Backend code tested locally

---

## Backend Deployment

### 1. Database Setup (Supabase)

#### Apply Schema
1. Open Supabase SQL Editor: https://supabase.com/dashboard/project/YOUR_PROJECT_ID/sql/new
2. Copy and paste `database-schema.sql`
3. Execute

#### Apply RLS Policies ⚠️ CRITICAL
1. Open same SQL Editor
2. Copy and paste `rls-policies.sql`
3. Execute
4. Verify: `node scripts/db-verification.js`

#### Add Seed Data
```bash
cd backend
node scripts/add-seed-data.js
```

Expected output:
```
✅ Successfully added 7 services
```

### 2. Environment Variables

Create `.env.production`:
```env
PORT=3000
NODE_ENV=production

# Supabase (from dashboard)
SUPABASE_URL=https://YOUR_PROJECT.supabase.co
SUPABASE_ANON_KEY=your_anon_key_here
SUPABASE_SERVICE_ROLE_KEY=your_service_role_key_here

# JWT (matches Supabase JWT secret)
JWT_SECRET=your_supabase_jwt_secret
```

### 3. Install Dependencies
```bash
npm install --production
```

### 4. Test Before Deploy
```bash
# Run verification
node scripts/db-verification.js

# Test integration
node tests/integration_simulation.js

# Test performance
node tests/load_test.js
```

Expected results:
- ✅ Database verification: All checks pass
- ✅ Integration: Auth 100%, Jobs depend on RLS
- ✅ Performance: <500ms average

### 5. Deploy to Production

**Option A: VPS/Cloud (DigitalOcean, AWS, etc.)**
```bash
# Install PM2 for process management
npm install -g pm2

# Start server
pm2 start src/index.js --name kadmat-backend

# Enable auto-restart on server reboot
pm2 startup
pm2 save
```

**Option B: Docker**
```bash
# Build image
docker build -t kadmat-backend .

# Run container
docker run -d \
  -p 3000:3000 \
  --env-file .env.production \
  --name kadmat-backend \
  kadmat-backend
```

**Option C: Serverless (Vercel, Railway, etc.)**
- Push to GitHub
- Connect repository to platform
- Add environment variables
- Deploy

---

## Flutter App Deployment

### 1. Update API Endpoint

Edit `lib/src/core/api/endpoints.dart`:
```dart
class Endpoints {
  static const baseUrl = 'https://your-production-api.com/api';
  // Remove /api if your backend already includes it in routes
}
```

### 2. Update Dependencies
```bash
cd ../  # Go to Flutter project root
flutter pub get
```

### 3. Build Production App

**Android**:
```bash
flutter build apk --release
# APK will be at: build/app/outputs/flutter-apk/app-release.apk
```

**iOS**:
```bash
flutter build ios --release
# Open Xcode and archive
```

### 4. Test Production Build

Before publishing:
1. Install production APK on real device
2. Test registration → login → token refresh
3. Test error scenarios (no internet, etc.)
4. Verify Arabic UI displays correctly

---

## Post-Deployment Verification

### 1. Smoke Tests (5 min)

Using production API:
```bash
# Test health endpoint
curl https://your-api.com/

# Test registration
curl -X POST https://your-api.com/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "test123",
    "full_name": "Test User",
    "user_type": "customer",
    "phone": "1234567890"
  }'
```

Expected: 201 Created

### 2. Monitor Logs

**PM2**:
```bash
pm2 logs kadmat-backend --lines 50
```

**Docker**:
```bash
docker logs kadmat-backend -f
```

Look for:
- ✅ No error stack traces
- ✅ Successful database connections
- ✅ Response times <500ms

### 3. Performance Check

Use production app to:
1. Register new user (should be <1s)
2. Login (should be <500ms)
3. Wait for token expiration (~1 hour)
4. Make request (should auto-refresh)

---

## Rollback Plan

If issues arise:

### Quick Rollback
```bash
# PM2
pm2 stop kadmat-backend
pm2 start kadmat-backend-v1  # Previous version

# Docker
docker stop kadmat-backend
docker start kadmat-backend-v1
```

### Database Rollback
Take snapshot before applying RLS policies:
1. Supabase Dashboard → Database → Backups
2. Click "Take Snapshot"
3. Restore if needed

---

## Monitoring (Recommended)

### Essential Metrics to Track
- Response times (target: <500ms p95)
- Error rates (target: <1%)
- Token refresh success rate (target: >99%)
- Database connection pool usage

### Tools
- **Free**: Supabase built-in monitoring
- **Paid**: New Relic, DataDog, Sentry

### Alerts to Set Up
- 🚨 Error rate >5%
- 🚨 Response time >2s
- 🚨 Database connection failures

---

## Security Checklist

Before going live:

- [ ] RLS policies applied and tested
- [ ] CORS configured for production domain only
- [ ] Rate limiting enabled (already done ✅)
- [ ] Helmet security headers active (already done ✅)
- [ ] Environment variables not in code
- [ ] Service role key kept secret
- [ ] HTTPS enforced (use Cloudflare/Let's Encrypt)

---

## Troubleshooting

### Issue: "Token refresh failed"
**Cause**: Refresh token expired or invalid  
**Solution**: User needs to re-login (expected after 30 days)

### Issue: "RLS policy violation"
**Cause**: RLS policies not applied or incorrect  
**Solution**: Re-run `rls-policies.sql` in Supabase

### Issue: "Wallet not found"
**Cause**: Trigger not creating wallet  
**Solution**: Run `node scripts/debug-trigger.js` to diagnose

### Issue: High response times
**Cause**: Database not optimized  
**Solution**: Check Supabase dashboard for slow queries

---

## Support Commands

```bash
# Check server status
pm2 status

# View error logs only
pm2 logs kadmat-backend --err

# Restart server
pm2 restart kadmat-backend

# Database health check
node scripts/db-verification.js

# Performance test
node tests/load_test.js
```

---

## Success Criteria

After deployment, verify:
- ✅ Users can register and login
- ✅ Tokens refresh automatically
- ✅ Error messages display in Arabic
- ✅ Response times <500ms
- ✅ No 500 errors in logs (404/401 are ok)

---

## Getting Help

1. Check logs first: `pm2 logs` or `docker logs`
2. Run diagnostic: `node scripts/db-verification.js`
3. Review walkthrough.md for common issues
4. Check Supabase logs for database errors

---

**Deployment Checklist**:
- [ ] RLS policies applied
- [ ] Seed data added
- [ ] Environment variables set
- [ ] Tests passing locally
- [ ] Production endpoint updated in Flutter
- [ ] Smoke tests passed
- [ ] Monitoring set up
- [ ] Rollback plan ready

**Estimated deployment time**: 30-45 minutes

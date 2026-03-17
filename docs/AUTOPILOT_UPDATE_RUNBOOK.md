# Autopilot Update Runbook

Goal: run DB updates + contract audits with one command and no repeated manual env edits.

## 1) One-time setup

1. Create env file:

```bash
cd /Users/wew/Desktop/kadmat/backend
cp .env.autopilot.example .env.autopilot
```

2. Fill real values in `.env.autopilot`:
- `STAGING_SUPABASE_URL`
- `STAGING_SUPABASE_SERVICE_ROLE_KEY`
- `STAGING_SUPABASE_DB_PASSWORD`
- `PROD_SUPABASE_URL`
- `PROD_SUPABASE_SERVICE_ROLE_KEY`
- `PROD_SUPABASE_DB_PASSWORD`

Important:
- Use real project refs (no placeholders like `YOUR_REAL_*`).
- Keep passwords without extra spaces.

## 2) Run updates (single command)

### Staging

```bash
cd /Users/wew/Desktop/kadmat/backend
npm run autopilot:update:staging
```

### Production

```bash
cd /Users/wew/Desktop/kadmat/backend
npm run autopilot:update:prod
```

## 3) What the script does

`scripts/autopilot-update.sh` will:
1. Load `.env` then `.env.autopilot`.
2. Resolve DB URL automatically from Supabase URL + DB password.
3. Apply migrations:
   - `29_create_api_idempotency_keys.sql`
   - `30_wallet_commission_idempotency.sql`
   - `31_add_jobs_after_photos.sql`
   - `32_notifications_dedupe_key_upsert_fix.sql`
   - `33_notification_lifecycle_events.sql`
4. Run release contract audits.

## 4) Optional flags

Skip audits:

```bash
bash scripts/autopilot-update.sh staging --skip-release-audits
```

Help:

```bash
bash scripts/autopilot-update.sh --help
```

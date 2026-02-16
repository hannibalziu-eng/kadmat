# Kadmat Backend

Production-ready backend for Kadmat service marketplace platform.

## 🚀 Quick Start

```bash
# Install dependencies
npm install

# Setup environment
cp .env.example .env
# Edit .env with your Supabase credentials

# Run database setup
node scripts/add-seed-data.js

# Start development server
npm run dev
```

Server runs at: http://localhost:3000

## 📋 Features

- ✅ User authentication (customer & technician)
- ✅ Automatic token refresh
- ✅ Job creation and management
- ✅ Wallet system with transactions
- ✅ Location-based technician search
- ✅ Real-time job status tracking
- ✅ Centralized error handling
- ✅ Rate limiting & security headers

## 🛠️ Tech Stack

- **Runtime**: Node.js 18+
- **Framework**: Express.js
- **Database**: PostgreSQL (via Supabase)
- **Auth**: Supabase Auth (JWT)
- **Validation**: Joi
- **Testing**: Jest, Supertest

## 📁 Project Structure

```
backend/
├── src/
│   ├── controllers/     # Request handlers
│   ├── routes/          # API routes
│   ├── middleware/      # Auth, errors, etc.
│   └── config/          # Supabase config
├── tests/               # Integration tests
├── scripts/             # Utility scripts
└── database-schema.sql  # Database setup
```

## 🔧 Environment Variables

```env
PORT=3000
NODE_ENV=development

SUPABASE_URL=https://xxx.supabase.co
SUPABASE_ANON_KEY=your_anon_key
SUPABASE_SERVICE_ROLE_KEY=your_service_role_key
JWT_SECRET=your_jwt_secret
```

## 🧪 Testing

```bash
# Unit tests
npm test

# Integration tests
node tests/integration_simulation.js

# Load tests
node tests/load_test.js

# Token refresh test
node tests/token-refresh-test.js

# Database verification
node scripts/db-verification.js

# Nearby jobs RPC contract audit
npm run audit:rpc

# Accept-offer + location RPC contract audit
npm run audit:accept-offer-contract

# One-shot release contract audits
npm run audit:release-contracts
```

## 📊 API Endpoints

### Auth
- `POST /api/auth/register` - Register new user
- `POST /api/auth/login` - Login user
- `POST /api/auth/refresh` - Refresh access token

### Jobs
- `POST /api/jobs` - Create new job
- `GET /api/jobs/nearby` - Get nearby jobs (technicians)
- `GET /api/jobs/my-jobs` - Get user's jobs
- `POST /api/jobs/:id/accept` - Accept job (technician)
- `POST /api/jobs/:id/complete` - Complete job

### Wallet
- `GET /api/wallet` - Get wallet balance
- `GET /api/wallet/transactions` - Get transaction history

### Technician
- `POST /api/technician/location` - Update location
- `POST /api/technician/toggle-online` - Toggle online status

## 🔒 Security

- Helmet.js for HTTP headers
- Rate limiting (100 req/15min per IP)
- CORS enabled
- Row Level Security (RLS) via Supabase
- JWT token validation
- Input validation with Joi

## 🚀 Deployment

See [DEPLOYMENT.md](./DEPLOYMENT.md) for detailed production deployment instructions.
For accept-offer rollout and DB contract verification, use:
[ACCEPT_OFFER_ROLLOUT_RUNBOOK.md](./ACCEPT_OFFER_ROLLOUT_RUNBOOK.md)

## 📈 Performance

Current benchmarks:
- Login: **204ms** average
- Registration: **595ms** average  
- Token refresh: **<500ms**
- All endpoints: **<1s** response time

## 🐛 Troubleshooting

### Database Issues
```bash
node scripts/db-verification.js
```

### Trigger Not Working
```bash
node scripts/debug-trigger.js
```

### RLS Policies Missing
Apply `rls-policies.sql` in Supabase SQL Editor.

## 📝 License

Proprietary

## 👥 Authors

Kadmat Development Team

## 🔗 Links

- [Supabase Dashboard](https://supabase.com/dashboard)
- [API Documentation](#) (Coming soon)

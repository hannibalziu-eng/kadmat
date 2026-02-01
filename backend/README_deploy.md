Kadmat Backend Deployment Readiness

Overview
- This document outlines steps to deploy Kadmat backend in cluster mode for scalability.

Prerequisites
- Node.js environment
- PM2 installed (global or via npm/yarn)
- Access to backend repository
- Environment variables configured (.env) for production

Deployment Steps
1) Install PM2 (if not installed)
   npm i -g pm2

2) Start clustering
   pm2 start backend/pm2.config.js --name kadmat-api

3) Validate deployment
   - pm2 ls
   - curl http://<host>:3000/health
   - curl http://<host>:3000/health/ready

4) Observability
   - Set up Prometheus/OpenTelemetry if needed
   - Route PM2 logs to a centralized system if available

5) Load testing
   - Run load tests to verify clustering with your chosen tool (k6/Artillery)
   - Adjust PM2 instances in ecosystem config if needed

Notes
- Ensure RPCs and RBAC/RLS policies are correctly configured for multi-worker setup.
- Review health checks for readiness and liveness in cluster mode.

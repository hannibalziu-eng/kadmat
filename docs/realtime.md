# Real-Time Architecture Documentation

## Overview
The real-time updates in Kadmat are powered by **Supabase Realtime**, allowing the application to receive instant updates for job status changes, new job requests, and technician assignments without manual polling.

## Core Components

### 1. `SupabaseRealtimeService`
Located at: `lib/src/core/realtime/supabase_realtime_service.dart`

This centralized service manages all Supabase Realtime channels. It abstracts the complexity of channel subscription, event filtering, and type casting.

**Key Methods:**
- `streamJob(jobId)`: Streams updates for a specific job.
- `streamNearbyJobs(...)`: Streams new jobs within a specific area/status.
- `streamMyJobs(userId)`: Streams jobs assigned to or created by the user.

### 2. `JobRepository` Integration
The `JobRepository` consumes the `SupabaseRealtimeService` to expose high-level streams to the domain layer.

**Refactored Methods:**
- `watchNearbyJobs`: Now uses `streamNearbyJobs` instead of a one-time fetch or raw stream.
- `watchMyJobs`: Uses `streamMyJobs`.
- **REMOVED**: `getNearbyJobs` (Future-based) and `_createJobFallback` (Insecure direct DB write).

## State Management (Riverpod)
Real-time streams are exposed via Riverpod providers in `job_controller.dart`.

- `watchNearbyJobsStreamProvider`: Used by the Technician Dashboard.
- `watchMyJobsRealtimeProvider`: Used for "My Jobs" lists and earning stats.
- `watchJobRealtimeProvider`: Used for the Job Detail screen.

## Security & Architecture Changes
- **No Direct DB Writes for Logic:** Fallback mechanisms that wrote directly to the database in case of API failure (e.g., in `createJob`) have been **removed**. All critical state transitions MUST go through the backend API to ensure the `JobStateMachine` and business rules are enforced.
- **Fail-Fast:** If the API is down or rate-limited, the app will now report an error rather than bypassing business logic.

## Usage Example

```dart
// In a ConsumerWidget
final jobsAsync = ref.watch(watchNearbyJobsStreamProvider(lat: ..., lng: ...));

jobsAsync.when(
  data: (jobs) => JobsList(jobs: jobs),
  loading: () => const CircularProgressIndicator(),
  error: (err, stack) => Text('Error: $err'),
);
```

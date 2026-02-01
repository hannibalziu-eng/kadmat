---
description: # 🎯 **Kadmat Complete Workflow** - رد واحد
---

---
name: Kadmat Complete Workflow (Supabase Edition)
description: شامل لكل مراحل التطوير - من الفكرة إلى الإطلاق (Supabase & Flutter)
tags: [kadmat, complete, production, supabase, flutter, full-cycle]
priority: high
---
# 🚀 Kadmat Complete Development Workflow (Supabase Edition)
## 📋 Overview
هذا Workflow يغطي دورة التطوير الكاملة من البداية للنهاية مع الالتزام بقواعد "كدمات":
- Planning & Analysis
- Backend Development (Supabase/Node.js)
- Frontend Development (Flutter)
- Testing
- Deployment
---
## 🎯 Phase 1: Planning & Requirements
### Step 1: Feature Definition
USER INPUT: ✓ Feature name/description ✓ User stories (who, what, why) ✓ Acceptance criteria ✓ Priority level ✓ Estimated effort

**AGENT ACTIONS:**
- Break down into technical tasks
- Create task checklist
- Identify affected modules (Flutter/Backend)
- List database changes needed (SQL/RLS)
- Note security implications
**DELIVERABLE:** Feature breakdown document
---
### Step 2: Technical Architecture Planning
REVIEW: ✓ UI Components needed ✓ Backend endpoints/RPCs ✓ Database schema changes ✓ RLS Policies updates ✓ API contracts

**CREATE:**
- Task list with dependencies
- Tech stack decisions (Supabase Edge Functions vs Node.js Backend)
- Library/package requirements
- Estimated timeline
**DELIVERABLE:** Technical specification document
---
## 🔧 Phase 2: Backend Development (Supabase & Node.js)
### Step 3: Database Schema & RLS
POSTGRESQL TASKS: ✓ Write CREATE TABLE / ALTER TABLE scripts ✓ Add PostGIS Geography columns for location ✓ Add indexes (GIST for location, Btree for IDs/Status) ✓ Enable Row Level Security (RLS) ✓ Write RLS Policies (MANDATORY)

**CODE PATTERN (Migration):**
```sql
-- Migration: migrations/001_create_jobs_table.sql
-- 1. Create Table
CREATE TABLE IF NOT EXISTS public.jobs (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  title TEXT NOT NULL,
  status TEXT NOT NULL CHECK (status IN ('pending', 'searching', 'price_pending', 'accepted', 'in_progress', 'completed', 'cancelled', 'no_technician_found')),
  technician_id UUID REFERENCES auth.users(id),
  customer_id UUID REFERENCES auth.users(id) NOT NULL,
  location GEOGRAPHY(POINT) NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
-- 2. Create Indexes
CREATE INDEX IF NOT EXISTS idx_jobs_status ON public.jobs(status);
CREATE INDEX IF NOT EXISTS idx_jobs_location ON public.jobs USING GIST(location);
CREATE INDEX IF NOT EXISTS idx_jobs_tech_id ON public.jobs(technician_id);
-- 3. Enable RLS
ALTER TABLE public.jobs ENABLE ROW LEVEL SECURITY;
-- 4. RLS Policies (Security Rules)
-- Techs can see jobs if they are assigned OR if job is available nearby (handled via RPC usually, but strict RLS for direct select)
CREATE POLICY "Customers can view their own jobs" 
ON public.jobs FOR SELECT 
USING (auth.uid() = customer_id);
CREATE POLICY "Technicians can view assigned jobs" 
ON public.jobs FOR SELECT 
USING (auth.uid() = technician_id);
DELIVERABLE: Migration scripts ready to execute

Step 4: Backend Functions (RPC)
POSTGRESQL RPC TASKS:
✓ Write SQL Functions for complex logic
✓ Use ST_DWithin for location search
✓ Handle constraints (Technician Locking)
✓ Grant EXECUTE permissions
CODE PATTERN (RPC):

-- Function: Get Nearby Jobs
-- Only returns jobs that are 'pending' or 'searching'
-- And checks if technician is NOT locked is usually done in app logic or wrapper function, 
-- but pure search logic is here:
CREATE OR REPLACE FUNCTION get_nearby_jobs(
  p_lat DOUBLE PRECISION,
  p_lng DOUBLE PRECISION,
  p_radius_km DOUBLE PRECISION
) 
RETURNS SETOF jobs 
LANGUAGE plpgsql
SECURITY DEFINER -- Use Security Definer to bypass RLS for the search radius logic if needed, or stick to INVOKER
AS $$
BEGIN
  RETURN QUERY
  SELECT *
  FROM jobs
  WHERE 
    status IN ('pending', 'searching')
    AND ST_DWithin(
      location,
      ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326)::geography,
      p_radius_km * 1000
    )
    AND created_at > NOW() - INTERVAL '24 hours' -- Time window logic
  ORDER BY 
    location <-> ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326)::geography;
END;
$$;
DELIVERABLE: Backend functions tested and deployed

Step 5: Backend API / Edge Functions (Node.js)
NODE.JS TASKS:
✓ Create endpoints for sensitive actions (e.g. Accept Job)
✓ Validate 'Authorization' header (Supabase JWT)
✓ Validate State Transitions (Backend is Truth)
✓ Handle Notifications (FCM)
CODE PATTERN (Express/Node.js):

// Route: Accept Job
router.post('/jobs/:id/accept', authenticateUser, async (req, res) => {
  const { id } = req.params;
  const technicianId = req.user.id;
  // 1. Check if Technician is LOCKED
  const { count } = await supabaseAdmin
    .from('jobs')
    .select('*', { count: 'exact', head: true })
    .eq('technician_id', technicianId)
    .in('status', ['accepted', 'in_progress']);
  if (count > 0) {
    return res.status(403).json({ error: 'TECHNICIAN_LOCKED' });
  }
  // 2. Atomic Update using Service Role Key
  const { data, error } = await supabaseAdmin
    .from('jobs')
    .update({ 
      status: 'accepted', 
      technician_id: technicianId,
      updated_at: new Date()
    })
    .eq('id', id)
    .in('status', ['pending', 'searching']) // Optimistic locking
    .select()
    .single();
  if (error || !data) {
    return res.status(409).json({ error: 'Job already taken or invalid' });
  }
  // 3. Send Notification to Customer
  await sendFCM(data.customer_id, 'Technician Accepted!');
  return res.json(data);
});
DELIVERABLE: Node.js endpoints implemented & tested

🎨 Phase 3: Frontend Development (Flutter)
Step 6: Data Models & Repository Layer
FLUTTER EXAMPLE:

/// Job Data Model (Freezed is recommended, but simplified here)
class Job {
  final String id;
  final String title;
  final String status;
  final String? technicianId;
  final DateTime createdAt;
  // ... other fields
  Job.fromJson(Map<String, dynamic> json)
      : id = json['id'],
        title = json['title'],
        status = json['status'],
        technicianId = json['technician_id'],
        createdAt = DateTime.parse(json['created_at']);
}
/// Job Repository - Data Access Layer
class JobRepository {
  final SupabaseClient _supabase;
  JobRepository({required SupabaseClient supabase}) : _supabase = supabase;
  /// Get nearby available jobs using RPC
  Future<List<Job>> getNearbyJobs({
    required double latitude,
    required double longitude,
    double radiusKm = 15,
  }) async {
    try {
      final response = await _supabase.rpc(
        'get_nearby_jobs',
        params: {
          'p_lat': latitude,
          'p_lng': longitude,
          'p_radius_km': radiusKm,
        },
      );
      
      return (response as List).map((j) => Job.fromJson(j)).toList();
    } catch (e) {
      // Handle Supabase/Network errors
      rethrow;
    }
  }
  /// Check if technician is locked (Client-side pre-check)
  /// Note: The ultimate check must happen on Backend API
  Future<bool> isTechnicianLocked() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return false;
    final response = await _supabase
        .from('jobs')
        .select('id')
        .eq('technician_id', userId)
        .in_('status', ['accepted', 'in_progress'])
        .count(CountOption.exact); // Efficient HEAD request
    return (response.count ?? 0) > 0;
  }
  
  /// Watch current active job (Realtime)
  Stream<List<Job>> watchActiveJobs() {
     final userId = _supabase.auth.currentUser?.id;
     return _supabase
        .from('jobs')
        .stream(primaryKey: ['id'])
        .eq('technician_id', userId!)
        .order('created_at')
        .map((maps) => maps.map((j) => Job.fromJson(j)).toList());
  }
}
DELIVERABLE: Model classes & Repository connected to Supabase

Step 7: State Management (Riverpod)
FLUTTER - RIVERPOD EXAMPLE:

final jobRepositoryProvider = Provider((ref) => JobRepository(
  supabase: Supabase.instance.client
));
/// Future Provider for searching
final nearbyJobsProvider = FutureProvider.autoDispose
    .family<List<Job>, ({double lat, double lng, double radius})>((ref, args) async {
  
  final repo = ref.watch(jobRepositoryProvider);
  return repo.getNearbyJobs(
    latitude: args.lat,
    longitude: args.lng,
    radiusKm: args.radius,
  );
});
/// Stream Provider for Lock Status / Active Job
final activeJobStreamProvider = StreamProvider.autoDispose<Job?>((ref) {
  final repo = ref.watch(jobRepositoryProvider);
  return repo.watchActiveJobs().map((jobs) {
    // Return the first active job if any exists
    return jobs.where((j) => ['accepted', 'in_progress'].contains(j.status)).firstOrNull;
  });
});
DELIVERABLE: State management & UI components complete

🧪 Phase 4: Testing
Step 8: Unit Tests & Integration
void main() {
  group('JobRepository Supabase Tests', () {
    test('isTechnicianLocked returns true if active job exists', () async {
      // Mock Supabase response
      // ... setup mock ...
      
      final isLocked = await repo.isTechnicianLocked();
      expect(isLocked, true);
    });
  });
}
RUN TESTS:

flutter test
DELIVERABLE: Unit tests passing

Step 9: Manual Testing Checklist (Kadmat Specific)
✅ TECHNICIAN LOCKING LOGIC:
  [ ] Accept job -> Status becomes 'accepted' -> UI blocks browsing other jobs?
  [ ] Propose price -> Status 'price_pending' -> UI UNBLOCKS browsing?
  [ ] Backend rejects Accept Job if user already has active job (403)?
✅ VISIBILITY & RLS:
  [ ] Login as Tech A. Can you read Tech B's active jobs in 'jobs' table? (Should be NO)
  [ ] Can you read jobs outside your radius? (Should be NO if RPC limits it)
  [ ] Do phone numbers appear masked/null until accepted?
✅ REALTIME UPDATES:
  [ ] Customer cancels job -> Technician screen updates instantly?
  [ ] Status change (pending -> in_progress) reflects immediately?
DELIVERABLE: Manual testing checklist complete

🚀 Phase 5: Deployment
Step 10: Pre-Deployment Checks
✅ SECURITY CHECKS:
  [ ] RLS Enabled on ALL tables?
  [ ] Service Role Key NOT used in Flutter?
  [ ] API Endpoints validate Auth Token?
  [ ] All sensitive fields (e.g. phone) protected?
✅ PERFORMANCE:
  [ ] Database Indexes created (especially on GEOGRAPHY columns)?
  [ ] Unused Supabase Realtime subscriptions cleaned up?
Step 11: Production Deployment
# 1. Apply Supabase Migrations
supabase db push
# 2. Deploy Edge Functions / Node Backend
# (If using Supabase Functions)
supabase functions deploy accepted_job
# 3. Build Flutter App
flutter build appbundle --release
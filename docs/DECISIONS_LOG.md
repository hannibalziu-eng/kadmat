# DECISIONS LOG

## 2026-02-15

### D-001 Router Source of Truth
- Decision: `router_modular.dart` is the active router.
- Reason: منع تضارب المسارات بين ملفات راوتر قديمة.

### D-002 Official Post-Accept Flow
- Decision: after customer accepts offer, canonical status target is `on_the_way`, then `arrived`, then `in_progress`.
- Reason: تحسين وضوح الرحلة للمستخدم وإتاحة تتبع "في الطريق" و"وصل" قبل بدء التنفيذ.

### D-003 Accept Offer API Compatibility
- Decision: backend accepts `offerId` + legacy keys (`offer_id`, `bidId`, `bid_id`).
- Reason: منع كسر التوافق مع مسارات UI قديمة.

### D-004 Error Contract Priority
- Decision: `INVALID_INPUT/VALIDATION_FAILED` must prefer backend message when available.
- Reason: منع رسائل عامة مبهمة للمستخدم.

### D-005 Backward Compatibility for DB Drift
- Decision: if `accepted_bid_id` column missing, retry assignment without it and add migration `22`.
- Reason: بيئات production/staging قد تكون غير متزامنة في المايجريشن.

### D-006 External Push Setup Deferred
- Decision: Firebase full setup deferred as final stage; fallback behavior remains.
- Reason: تثبيت core flow أولاً.

## Open Decisions
- O-001: Final polling cadence per screen after realtime stabilization.
- O-002: Final UX composition for technician dashboard header and request priority cards.

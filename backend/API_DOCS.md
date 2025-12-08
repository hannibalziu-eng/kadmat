# KADMAT Backend API Documentation v2.0

## Base URL
`/api`

## Authentication
All endpoints require a Bearer Token in the header:
`Authorization: Bearer <token>`

---

## Jobs

### 1. Create Job
**POST** `/jobs`

**Body:**
```json
{
  "service_id": "UUID",
  "lat": 24.7136,
  "lng": 46.6753,
  "address_text": "King Fahd Road, Riyadh",
  "description": "AC leaking water",
  "initial_price": 0,
  "images": ["url1", "url2"]
}
```

**Response:** `201 Created`
```json
{
  "success": true,
  "data": {
    "id": "job_uuid",
    "status": "pending",
    ...
  }
}
```

---

### 2. Get Job Details
**GET** `/jobs/:id`

**Response:** `200 OK`
```json
{
  "success": true,
  "data": {
    "id": "job_uuid",
    "status": "pending",
    "customer_id": "cust_uuid",
    "technician_id": null,
    "permissions": {
      "canAccept": false,
      "canCancel": true,
      ...
    },
    "timeline": {
      "createdAt": "2023-12-01T10:00:00Z",
      ...
    }
  }
}
```

---

### 3. Accept Job (Technician)
**POST** `/jobs/:id/accept`

**Response:** `200 OK`
```json
{
  "success": true,
  "data": { "status": "accepted", ... }
}
```

**Errors:**
- `409 Conflict`: Job already accepted ("Job taken")

---

### 4. My Jobs
**GET** `/jobs/my-jobs`

**Query Params:**
- `page`: 1 (default)
- `limit`: 10 (default)
- `status`: 'active' | 'history'

**Response:** `200 OK`
```json
{
  "success": true,
  "data": [ ... ],
  "meta": {
    "page": 1,
    "limit": 10,
    "total": 5
  }
}
```

---

## Enums

### Job Statuses
- `pending`: Waiting for technician
- `searching`: Smart search active
- `accepted`: Technician assigned
- `price_pending`: Technician proposed price
- `in_progress`: Price confirmed, work started
- `completed`: Work done
- `rated`: Customer rated
- `cancelled`: Job cancelled
- `no_technician_found`: Search failed (will retry)

### Error Codes
- `VALIDATION_FAILED`
- `UNAUTHORIZED`
- `JOB_NOT_FOUND`
- `JOB_ALREADY_ACCEPTED`
- `INVALID_STATUS_TRANSITION`
- `DATABASE_ERROR`

import { supabaseAdmin } from '../config/supabase.js';

const IDEMPOTENCY_TABLE = 'api_idempotency_keys';

class IdempotencyService {
  async getActiveRecord({ userId, endpoint, key, nowIso }) {
    const now = nowIso || new Date().toISOString();
    const { data, error } = await supabaseAdmin
      .from(IDEMPOTENCY_TABLE)
      .select('*')
      .eq('user_id', userId)
      .eq('endpoint', endpoint)
      .eq('idempotency_key', key)
      .gte('expires_at', now)
      .order('created_at', { ascending: false })
      .limit(1)
      .maybeSingle();

    if (error) {
      throw this._wrapError('IDEMPOTENCY_READ_FAILED', error);
    }

    return data || null;
  }

  async begin({ userId, endpoint, key, requestHash, ttlHours = 48 }) {
    const now = new Date();
    const nowIso = now.toISOString();
    const expiresAt = new Date(now.getTime() + ttlHours * 60 * 60 * 1000).toISOString();

    const existing = await this.getActiveRecord({
      userId,
      endpoint,
      key,
      nowIso,
    });

    if (existing) {
      return { kind: 'existing', record: existing };
    }

    // Remove expired rows for same tuple to avoid unique-key collisions.
    await supabaseAdmin
      .from(IDEMPOTENCY_TABLE)
      .delete()
      .eq('user_id', userId)
      .eq('endpoint', endpoint)
      .eq('idempotency_key', key)
      .lt('expires_at', nowIso);

    const payload = {
      user_id: userId,
      endpoint,
      idempotency_key: key,
      request_hash: requestHash,
      status: 'processing',
      expires_at: expiresAt,
      created_at: nowIso,
      updated_at: nowIso,
    };

    const { data, error } = await supabaseAdmin
      .from(IDEMPOTENCY_TABLE)
      .insert(payload)
      .select('*')
      .single();

    if (!error) {
      return { kind: 'new', record: data };
    }

    // Race-safe retry path.
    if (error.code === '23505') {
      const racedExisting = await this.getActiveRecord({
        userId,
        endpoint,
        key,
        nowIso,
      });
      if (racedExisting) {
        return { kind: 'existing', record: racedExisting };
      }
    }

    throw this._wrapError('IDEMPOTENCY_WRITE_FAILED', error);
  }

  async complete({ recordId, statusCode, responseBody }) {
    if (!recordId) return;
    const payload = {
      status: 'completed',
      response_status: statusCode,
      response_body: responseBody ?? null,
      completed_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    };

    const { error } = await supabaseAdmin
      .from(IDEMPOTENCY_TABLE)
      .update(payload)
      .eq('id', recordId);

    if (error) {
      throw this._wrapError('IDEMPOTENCY_COMPLETE_FAILED', error);
    }
  }

  _wrapError(code, source) {
    const error = new Error(source?.message || 'Idempotency storage error');
    error.code = code;
    error.dbCode = source?.code;
    error.dbError = source;
    return error;
  }
}

export const idempotencyService = new IdempotencyService();

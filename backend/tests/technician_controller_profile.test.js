import { beforeEach, describe, expect, it, jest } from '@jest/globals';

function buildResponseRecorder() {
  return {
    statusCode: 200,
    body: null,
    status(code) {
      this.statusCode = code;
      return this;
    },
    json(payload) {
      this.body = payload;
      return this;
    },
  };
}

const mockTechnician = {
  id: 'tech-1',
  full_name: 'فني الاختبار',
  profile_image_url: 'https://example.com/tech.png',
  rating: 4.8,
  created_at: '2026-03-07T00:00:00.000Z',
  user_type: 'technician',
  title: 'فني تكييف معتمد',
  bio: 'أصلح الأعطال المنزلية والتجارية.',
  address: 'طرابلس',
  location: 'SRID=4326;POINT(13.1873 32.8872)',
  service: { name_ar: 'صيانة تكييف' },
};

const mockPortfolio = [
  {
    id: 'portfolio-1',
    technician_id: 'tech-1',
    title: 'تنظيف وحدة خارجية',
    description: 'قبل وبعد الصيانة',
    image_url: 'https://example.com/work.png',
    project_date: '2026-03-01',
  },
];

const mockReviews = [
  {
    id: 'review-1',
    rating: 5,
    comment: 'عمل ممتاز',
    created_at: '2026-03-05T00:00:00.000Z',
    reviewer: {
      full_name: 'عميل الاختبار',
      profile_image_url: 'https://example.com/customer.png',
    },
  },
];

let failPortfolioTitleInsert = false;

function buildQuery(table) {
  const state = {
    selectClause: null,
    filters: [],
    updatePayload: null,
    insertPayload: null,
  };

  const query = {
    select: jest.fn((clause) => {
      state.selectClause = clause;
      return query;
    }),
    update: jest.fn((payload) => {
      state.updatePayload = payload;
      return query;
    }),
    insert: jest.fn((payload) => {
      state.insertPayload = payload;
      return query;
    }),
    eq: jest.fn((column, value) => {
      state.filters.push({ type: 'eq', column, value });
      return query;
    }),
    in: jest.fn((column, values) => {
      state.filters.push({ type: 'in', column, values });
      return query;
    }),
    order: jest.fn(() => query),
    limit: jest.fn(() => query),
    single: jest.fn(async () => {
      if (table === 'technician_portfolio') {
        if (state.insertPayload?.title && failPortfolioTitleInsert) {
          return {
            data: null,
            error: {
              code: 'PGRST204',
              message:
                "Could not find the 'title' column of 'technician_portfolio' in the schema cache",
            },
          };
        }

        return {
          data: {
            id: 'portfolio-new',
            technician_id: 'tech-1',
            ...state.insertPayload,
          },
          error: null,
        };
      }

      if (table !== 'users') {
        throw new Error(`single() not expected for ${table}`);
      }

      if (state.updatePayload) {
        return {
          data: {
            ...mockTechnician,
            ...state.updatePayload,
          },
          error: null,
        };
      }

      expect(state.selectClause).toContain('title');
      expect(state.selectClause).toContain('bio');
      expect(state.selectClause).toContain('location');
      expect(state.filters).toEqual(
        expect.arrayContaining([
          expect.objectContaining({ type: 'eq', column: 'id', value: 'tech-1' }),
          expect.objectContaining({
            type: 'eq',
            column: 'user_type',
            value: 'technician',
          }),
        ]),
      );

      return { data: { ...mockTechnician }, error: null };
    }),
    then(onFulfilled, onRejected) {
      let payload;
      if (table === 'jobs') {
        payload = { count: 7, error: null };
      } else if (table === 'technician_portfolio') {
        payload = { data: mockPortfolio.map((item) => ({ ...item })), error: null };
      } else if (table === 'reviews') {
        payload = { data: mockReviews.map((item) => ({ ...item })), error: null };
      } else {
        payload = { data: null, error: null };
      }
      return Promise.resolve(payload).then(onFulfilled, onRejected);
    },
  };

  return query;
}

const supabaseAdminMock = {
  from: jest.fn((table) => buildQuery(table)),
};

jest.unstable_mockModule('../src/config/supabase.js', () => ({
  supabaseAdmin: supabaseAdminMock,
}));

const { addPortfolioWork, getTechnicianProfile, updateProfile } = await import(
  '../src/controllers/technicianController.js'
);

describe('technician controller profile payload', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    failPortfolioTitleInsert = false;
  });

  it('returns title, bio, location and normalized specialization for public profile', async () => {
    const req = { params: { id: 'tech-1' } };
    const res = buildResponseRecorder();

    await getTechnicianProfile(req, res);

    expect(res.statusCode).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.data.title).toBe('فني تكييف معتمد');
    expect(res.body.data.bio).toBe('أصلح الأعطال المنزلية والتجارية.');
    expect(res.body.data.location).toBe('طرابلس');
    expect(res.body.data.specialization).toBe('صيانة تكييف');
    expect(res.body.data.portfolio).toHaveLength(1);
    expect(res.body.data.portfolio[0].title).toBe('تنظيف وحدة خارجية');
    expect(res.body.data.reviews).toHaveLength(1);
    expect(res.body.data.stats.completedJobs).toBe(7);
  });

  it('stores display location in address and returns normalized location field', async () => {
    const req = {
      user: { id: 'tech-1' },
      body: {
        full_name: 'فني اتساق البروفايل',
        title: 'خبير صيانة تكييف',
        bio: 'وصف مختصر',
        location: 'طرابلس - حي الأندلس',
      },
    };
    const res = buildResponseRecorder();

    await updateProfile(req, res);

    expect(res.statusCode).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.data.address).toBe('طرابلس - حي الأندلس');
    expect(res.body.data.location).toBe('طرابلس - حي الأندلس');
  });

  it('falls back when portfolio title column is missing and preserves title for reads', async () => {
    failPortfolioTitleInsert = true;
    const req = {
      user: { id: 'tech-1' },
      body: {
        title: 'تنظيف الوحدة الخارجية',
        description: 'تنظيف شامل مع تبديل فلاتر واختبار أداء بعد الصيانة.',
        image_url: 'https://example.com/work.png',
        completion_date: '2026-03-07',
      },
    };
    const res = buildResponseRecorder();

    await addPortfolioWork(req, res);

    expect(res.statusCode).toBe(201);
    expect(res.body.success).toBe(true);
    expect(res.body.data.image_url).toBe('https://example.com/work.png');
    expect(res.body.data.title).toBe('تنظيف الوحدة الخارجية');
    expect(res.body.data.description).toBe(
      'تنظيف شامل مع تبديل فلاتر واختبار أداء بعد الصيانة.',
    );
  });
});

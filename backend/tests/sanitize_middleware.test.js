import { describe, expect, it, jest } from '@jest/globals';
import { sanitizeInput } from '../src/middleware/sanitizeMiddleware.js';

describe('sanitizeInput', () => {
  it('trims strings without escaping URLs or nested values', () => {
    const req = {
      body: {
        title: '  عنوان  ',
        image_url: '  http://127.0.0.1:7361/icons/Icon-512.png  ',
        nested: {
          description: '  <b>وصف</b>  ',
        },
        tags: ['  one  ', ' two '],
      },
      query: {
        search: '  مرحبا  ',
        callback: '  https://example.com/a?x=1&y=2  ',
      },
    };

    const next = jest.fn();

    sanitizeInput(req, {}, next);

    expect(req.body).toEqual({
      title: 'عنوان',
      image_url: 'http://127.0.0.1:7361/icons/Icon-512.png',
      nested: {
        description: '<b>وصف</b>',
      },
      tags: ['one', 'two'],
    });
    expect(req.query).toEqual({
      search: 'مرحبا',
      callback: 'https://example.com/a?x=1&y=2',
    });
    expect(next).toHaveBeenCalledTimes(1);
  });
});

import { validateRegistration } from '../utils/registration';

describe('registration validation', () => {
  const valid = {
    username: 'listener_1',
    email: 'listener@example.com',
    password: 'password123',
  };

  it('accepts valid fields and defaults the name', () => {
    expect(validateRegistration(valid)).toEqual({
      ...valid,
      name: 'listener_1',
    });
  });

  it.each([
    { ...valid, username: 'ab' },
    { ...valid, username: 'invalid name' },
    { ...valid, email: 'invalid' },
    { ...valid, password: 'short' },
    { ...valid, password: 'x'.repeat(129) },
  ])('rejects invalid registration fields', (registration) => {
    expect(validateRegistration(registration)).toBeNull();
  });
});

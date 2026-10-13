import { validateRegistration } from '../utils/registration';

const registrationAttempts = new Map<string, number[]>();
const registrationWindowMs = 10 * 60 * 1000;

export default defineEventHandler(async (event) => {
  const registration = validateRegistration(await readBody(event));
  if (!registration) {
    throw createError({
      statusCode: 400,
      statusMessage:
        'Invalid username, email, or password. Password must be 8–128 characters.',
    });
  }

  const adminUser = process.env.NAVIDROME_ADMIN_USER;
  const adminPassword = process.env.NAVIDROME_ADMIN_PASSWORD;
  if (!adminUser || !adminPassword) {
    throw createError({
      statusCode: 500,
      statusMessage: 'registration not configured',
    });
  }

  // ponytail: This per-IP limit resets when the server restarts.
  const ip = getRequestIP(event) || 'unknown';
  const now = Date.now();
  const recent = (registrationAttempts.get(ip) || []).filter(
    (time) => now - time < registrationWindowMs,
  );
  if (recent.length >= 5) {
    throw createError({
      statusCode: 429,
      statusMessage: 'Too many registration attempts. Try again later.',
    });
  }
  recent.push(now);
  registrationAttempts.set(ip, recent);

  const navidromeUrl = (
    process.env.NAVIDROME_INTERNAL_URL || 'http://navidrome:4533'
  ).replace(/\/$/, '');
  let token: string;
  try {
    const login = await $fetch<{ token: string }>(
      `${navidromeUrl}/auth/login`,
      {
        method: 'POST',
        body: { username: adminUser, password: adminPassword },
      },
    );
    if (typeof login.token !== 'string' || !login.token)
      throw new Error('Missing Navidrome token');
    token = login.token;
  } catch {
    throw createError({
      statusCode: 502,
      statusMessage: 'Registration service unavailable',
    });
  }

  try {
    await $fetch(`${navidromeUrl}/api/user`, {
      method: 'POST',
      headers: { 'x-nd-authorization': `Bearer ${token}` },
      body: {
        userName: registration.username,
        name: registration.name,
        email: registration.email,
        password: registration.password,
        isAdmin: false,
      },
    });
  } catch (error) {
    const response = error as {
      statusCode?: number;
      statusMessage?: string;
      data?: {
        message?: string;
        error?: string;
        errors?: { userName?: string };
      };
    };
    const description = [
      response.statusMessage,
      response.data?.message,
      response.data?.error,
      response.data?.errors?.userName,
    ].join(' ');
    if (
      response.statusCode === 409 ||
      /already exists|duplicate|already taken|validation.unique/i.test(description)
    ) {
      throw createError({ statusCode: 409, statusMessage: 'username taken' });
    }
    throw createError({
      statusCode: 502,
      statusMessage: 'Registration service unavailable',
    });
  }

  setResponseStatus(event, 201);
  return { success: true };
});

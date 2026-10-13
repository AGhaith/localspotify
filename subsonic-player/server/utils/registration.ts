export interface Registration {
  username: string;
  email: string;
  password: string;
  name: string;
}

export function validateRegistration(body: unknown): Registration | null {
  if (!body || typeof body !== 'object') return null;

  const fields = body as Record<string, unknown>;
  const { username, email, password, name } = fields;
  if (typeof username !== 'string' || !/^[a-zA-Z0-9_.-]{3,32}$/.test(username))
    return null;
  if (typeof email !== 'string' || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email))
    return null;
  if (
    typeof password !== 'string' ||
    password.length < 8 ||
    password.length > 128
  )
    return null;
  if (name !== undefined && (typeof name !== 'string' || !name.trim()))
    return null;

  return {
    username,
    email,
    password,
    name: typeof name === 'string' ? name.trim() : username,
  };
}

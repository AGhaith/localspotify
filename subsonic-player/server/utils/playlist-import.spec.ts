import { matchesDeezer } from './playlist-import';

describe('playlist track matching', () => {
  const track = { title: 'Song', artist: 'Singer', durationMs: 201_000 };
  const candidate = { title: 'Song', artist: { name: 'Singer' }, duration: 201 };

  it('accepts a matching release', () => {
    expect(matchesDeezer(track, candidate)).toBe(true);
  });

  it.each([
    ['different version', { ...candidate, title: 'Song (Live)' }],
    ['different duration', { ...candidate, duration: 207 }],
    ['different artist', { ...candidate, artist: { name: 'Other Artist' } }],
  ])('rejects a %s', (_reason, other) => {
    expect(matchesDeezer(track, other)).toBe(false);
  });
});

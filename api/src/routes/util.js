import { prisma } from '../lib/db.js';
import { decrypt } from '../lib/crypto.js';
import { refreshToken } from '../lib/spotify.js';

export async function ensureAccess(userId, fastify) {
  const tok = await prisma.token.findUnique({ where: { userId } });
  if (!tok) throw fastify.httpErrors.unauthorized();

  if (tok.expiresAt.getTime() - Date.now() > 60_000) {
    return { accessToken: tok.accessToken };
  }
  const rt = decrypt(tok.refreshEnc);
  const refreshed = await refreshToken(rt);
  const next = {
    accessToken: refreshed.access_token,
    expiresAt: new Date(Date.now() + refreshed.expires_in * 1000),
    scope: refreshed.scope ?? tok.scope,
    refreshEnc: tok.refreshEnc // Spotify may omit refresh_token on refresh
  };
  await prisma.token.update({ where: { userId }, data: next });
  return { accessToken: next.accessToken };
}

import fp from "fastify-plugin";
import { ensureAccess } from "./util.js";

export default fp(async function meRoutes(fastify) {
  // Who am I
  fastify.get("/me", async (req, reply) => {
    const user = await authUser(req, fastify);
    if (!user) return reply.code(401).send({ error: "unauthorized" });
    reply.header("Vary", "Cookie");
    return {
      id: user.id,
      spotifyId: user.spotifyId,
      email: user.email,
      displayName: user.displayName,
    };
  });

  // My playlists
  fastify.get("/me/playlists", async (req, reply) => {
    const user = await authUser(req, fastify);
    if (!user) return reply.code(401).send({ error: "unauthorized" });

    const { accessToken } = await ensureAccess(user.id, fastify);
    const res = await fetch("https://api.spotify.com/v1/me/playlists?limit=50", {
      headers: { Authorization: `Bearer ${accessToken}` },
    });

    if (res.status === 429) {
      return reply.code(429).send({
        error: "rate_limited",
        retryAfter: res.headers.get("retry-after"),
      });
    }
    if (!res.ok) return reply.code(502).send({ error: "spotify_failed" });
    return res.json();
  });

  // Debug helper (remove in prod)
  fastify.get("/me/debug", async (req) => {
    const { cookies, headers } = req;
    const sid = readSid(req);
    return { cookies, sid, origin: headers.origin || headers.referer || null };
  });

  // Debug playlists response (remove in prod)
  fastify.get("/me/playlists/debug", async (req, reply) => {
    const user = await authUser(req, fastify);
    if (!user) return reply.code(401).send({ error: "unauthorized" });

    const { accessToken } = await ensureAccess(user.id, fastify);
    const res = await fetch("https://api.spotify.com/v1/me/playlists?limit=50", {
      headers: { Authorization: `Bearer ${accessToken}` },
    });

    if (res.status === 429) {
      return reply.code(429).send({
        error: "rate_limited",
        retryAfter: res.headers.get("retry-after"),
      });
    }
    if (!res.ok) {
      return reply.code(502).send({ 
        error: "spotify_failed", 
        status: res.status, 
        statusText: res.statusText,
        response: await res.text()
      });
    }
    
    const data = await res.json();
    return {
      debug: true,
      hasItems: !!data.items,
      itemsCount: data.items?.length || 0,
      totalPlaylists: data.total,
      keys: Object.keys(data),
      firstPlaylist: data.items?.[0] || null,
      fullResponse: data
    };
  });
});

// Accept unsigned or signed cookie
export async function authUser(req, fastify) {
  const sid = readSid(req);
  if (!sid) return null;
  return fastify.prisma.user.findUnique({ where: { id: sid } });
}

function readSid(req) {
  const raw = req.cookies?.sid || null;
  if (!raw) return null;
  // If fastify-cookie was configured with a secret earlier, support signed too
  if (typeof req.unsignCookie === "function") {
    const u = req.unsignCookie(raw);
    if (u?.valid && u.value) return u.value; // signed cookie path
  }
  return raw; // unsigned cookie path
}

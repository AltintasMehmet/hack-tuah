import fp from "fastify-plugin";
import { prisma } from "../lib/db.js";
import { tokenFromCode } from "../lib/spotify.js";
import { encrypt, decrypt } from "../lib/crypto.js";

const SCOPES = [
  "playlist-read-private",
  "playlist-read-collaborative",
  "user-read-email",
].join(" ");

export default fp(async function authRoutes(fastify) {
  fastify.get("/auth/login", async (req, reply) => {
    const state = cryptoRandom();
    reply.setCookie("oauth_state", state, {
      path: "/",
      httpOnly: true,
      sameSite: "lax",
      secure: fastify.config.isProd,
    });
    const p = new URLSearchParams({
      client_id: process.env.SPOTIFY_CLIENT_ID,
      response_type: "code",
      redirect_uri: process.env.SPOTIFY_REDIRECT_URI,
      scope: SCOPES,
      state,
    });
    reply.redirect("https://accounts.spotify.com/authorize?" + p.toString());
  });

  fastify.get("/auth/callback", async (req, reply) => {
    const { code, state } = req.query;
    const cookieState = req.cookies.oauth_state;
    if (!cookieState || state !== cookieState)
      return reply.code(400).send({ error: "bad_state" });

    const tok = await tokenFromCode(code);
    const meRes = await fetch("https://api.spotify.com/v1/me", {
      headers: { Authorization: `Bearer ${tok.access_token}` },
    });
    if (!meRes.ok) return reply.code(502).send({ error: "spotify_me_failed" });
    const me = await meRes.json();

    const user = await prisma.user.upsert({
      where: { spotifyId: me.id },
      create: {
        spotifyId: me.id,
        email: me.email ?? null,
        displayName: me.display_name ?? null,
      },
      update: { email: me.email ?? null, displayName: me.display_name ?? null },
    });

    await prisma.token.upsert({
      where: { userId: user.id },
      create: {
        userId: user.id,
        accessToken: tok.access_token,
        refreshEnc: encrypt(tok.refresh_token),
        scope: tok.scope,
        expiresAt: new Date(Date.now() + tok.expires_in * 1000),
      },
      update: {
        accessToken: tok.access_token,
        refreshEnc: encrypt(
          tok.refresh_token ??
            decrypt(
              (
                await prisma.token.findUnique({ where: { userId: user.id } })
              )?.refreshEnc || ""
            )
        ),
        scope: tok.scope,
        expiresAt: new Date(Date.now() + tok.expires_in * 1000),
      },
    });

    reply.setCookie("sid", user.id, {
      path: "/",
      httpOnly: true,
      sameSite: "lax",
      secure: false,
    });
    reply.redirect(process.env.FRONTEND_ORIGIN || "/");
  });

  // Logout endpoint
  fastify.post("/auth/logout", async (req, reply) => {
    const userId = req.cookies.sid;
    
    // Clear the session cookie
    reply.clearCookie("sid", {
      path: "/",
      httpOnly: true,
      sameSite: "lax",
      secure: false,
    });

    // Optionally, you could also delete the user's token from the database
    // but keeping it allows for seamless re-login without re-authorization
    
    return { success: true, message: "Logged out successfully" };
  });
});

function cryptoRandom() {
  return [...crypto.getRandomValues(new Uint8Array(16))]
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

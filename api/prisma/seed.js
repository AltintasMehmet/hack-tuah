// prisma/seed.js
import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function main() {
  // Create or update a demo user
  const user = await prisma.user.upsert({
    where: { spotifyId: 'seed_spotify_id' },
    update: { displayName: 'Seed User' },
    create: {
      spotifyId: 'seed_spotify_id',
      email: 'seed@example.com',
      displayName: 'Seed User'
    }
  });

  // Add a fake token (useful only for dev/testing)
  await prisma.token.upsert({
    where: { userId: user.id },
    update: {
      accessToken: 'fake_access',
      refreshEnc: 'fake_refresh',
      scope: 'playlist-read-private',
      expiresAt: new Date(Date.now() + 3600_000)
    },
    create: {
      userId: user.id,
      accessToken: 'fake_access',
      refreshEnc: 'fake_refresh',
      scope: 'playlist-read-private',
      expiresAt: new Date(Date.now() + 3600_000)
    }
  });
}

main()
  .catch((e) => {
    console.error('Seed error:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });

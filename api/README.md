# playlistparser-api

Backend service for the **playlistparser** coursework project.
Built with **Fastify**, **Prisma**, and **PostgreSQL**.
Integrates with the **Spotify Web API** for OAuth and playlist data.

## Environment variables

**Common**

* `NODE_ENV` — `development` or `production`
* `LOG_LEVEL` — Fastify log level (default: `info`)

**API**

* `PORT` — port to listen on (default: 3000)
* `SESSION_SECRET` — secret for signing cookies (32+ chars recommended)
* `TOKEN_ENC_KEY` — 32-byte hex key for encrypting refresh tokens
* `DATABASE_URL` — PostgreSQL connection string
* `SPOTIFY_CLIENT_ID` — from [Spotify Developer Dashboard](https://developer.spotify.com/dashboard)
* `SPOTIFY_CLIENT_SECRET` — from dashboard
* `SPOTIFY_REDIRECT_URI` — must match dashboard, e.g. `http://127.0.0.1:3000/auth/callback`
* `FRONTEND_ORIGIN` — URL of the frontend, e.g. `http://127.0.0.1:5173`

**Frontend (Vite)**

* `VITE_API_BASE_URL` — base URL of this API (Vite requires the `VITE_` prefix).

## Spotify API Setup

### Creating a Spotify Application

1. **Go to Spotify Developer Dashboard**
   * Visit [https://developer.spotify.com/dashboard](https://developer.spotify.com/dashboard)
   * Log in with your Spotify account (create one if needed)

2. **Create New App**
   * Click "Create app" button
   * Fill in the required information:
     * **App name**: `playlistparser` (or any name you prefer)
     * **App description**: `Coursework project for playlist analysis`
     * **Website**: Leave empty or use a placeholder like `https://example.com` (not critical for development)
     * **Redirect URI**: `http://127.0.0.1:3000/auth/callback` ⚠️ **CRITICAL: Must be exactly this URL**
   * Check the terms of service agreement
   * Click "Save"

3. **Configure App Settings**
   * After creating the app, click on it to open settings
   * Go to "Settings" tab
   * **Verify Redirect URI**: Ensure `http://127.0.0.1:3000/auth/callback` is listed exactly
   * **Note**: Do NOT use `localhost` - use `127.0.0.1` specifically

4. **Get Your Credentials**
   * In the app settings, you'll see:
     * **Client ID**: Copy this value
     * **Client secret**: Click "View client secret" and copy this value
   * Keep these credentials secure and never commit them to version control

### Environment Configuration

Add your Spotify credentials to your `.env` file:

```env
SPOTIFY_CLIENT_ID=your_client_id_here
SPOTIFY_CLIENT_SECRET=your_client_secret_here
SPOTIFY_REDIRECT_URI=http://127.0.0.1:3000/auth/callback
```

⚠️ **VERY Important Notes:**

* The redirect URI must match exactly what you configured in Spotify Dashboard
* Use `127.0.0.1` instead of `localhost` for consistency
* Keep your client secret private and secure

## Database Architecture

### Why PostgreSQL is Required

The application uses **PostgreSQL** as its persistent data store for several critical purposes:

#### Authentication & Session Management

* Stores user profiles and Spotify account information
* Manages OAuth tokens securely with encryption
* Enables persistent login sessions across browser restarts

#### OAuth Token Management

* **Access tokens**: Short-lived tokens (1 hour) for Spotify API calls
* **Refresh tokens**: Long-lived encrypted tokens to get new access tokens
* **Token expiration tracking**: Automatic refresh before expiration

#### Why Not Just Use Cookies/Memory?

* **Persistence**: Data survives server restarts and deployments
* **Security**: Encrypted refresh tokens are safer than browser storage
* **Scalability**: Multiple server instances can share user sessions
* **Audit trail**: Track user registration and token refresh history

### Database Schema

The application uses a minimal but effective schema with two main tables:

#### User Table

* `id`: Unique identifier (CUID)
* `spotifyId`: Spotify user ID (unique constraint)
* `email`: User's email from Spotify profile
* `displayName`: User's display name
* `createdAt`: Registration timestamp

#### Token Table

* `userId`: Foreign key to User table
* `accessToken`: Current Spotify access token
* `refreshEnc`: **Encrypted** refresh token for security
* `scope`: OAuth permissions granted
* `expiresAt`: Token expiration timestamp

### Data Flow Example

1. **User Login**: User visits `/auth/login`
2. **OAuth Flow**: Redirected to Spotify, then back with authorization code
3. **Token Exchange**: API exchanges code for access + refresh tokens
4. **Database Storage**:
   * User profile stored/updated in `User` table
   * Tokens stored in `Token` table (refresh token encrypted)
5. **API Requests**:
   * API checks token expiration before Spotify calls
   * Auto-refreshes tokens when needed using stored refresh token
   * Updates database with new tokens

### Security Features

* **Encrypted Storage**: Refresh tokens are encrypted using `TOKEN_ENC_KEY`
* **Automatic Cleanup**: Tokens are replaced on refresh (no accumulation)
* **Secure Sessions**: User sessions use signed cookies with `SESSION_SECRET`
* **No Plaintext Secrets**: Critical tokens never stored in plaintext

## OAuth and scopes

This server implements the **Authorization Code** flow.
Scopes used (read-only):

* `playlist-read-private`
* `playlist-read-collaborative`
* `user-read-email`

Server-side OAuth is strongly preferred. PKCE is not required unless starting the flow in the SPA.

## Spotify API notes

* **No write endpoints** are exposed. The project never creates, modifies, or deletes playlists.
* Rate limits: Spotify may respond with HTTP 429 and a `Retry-After` header (sliding 30-second window).
* Always inspect headers before retrying.

## Export functionality

### Individual playlist export

* Export any playlist to CSV format
* Includes track metadata: name, artists, album, release date, popularity, duration
* Includes playlist metadata: owner, description, track count
* Smart filename generation with user ID, playlist name, and timestamp

### Bulk export (all playlists)

* Asynchronous job processing for large libraries
* Real-time progress tracking with current playlist information
* Combined CSV output with all playlists in a single file
* In-memory job tracking with automatic cleanup

### Export data structure

* Position, Track Name, Artists, Album, Release Date
* Duration (ms and mm:ss format), Popularity, Track ID
* Album ID, Artist IDs, Added At, Added By
* Is Local, Preview URL, External URLs
* CSV-safe formatting with proper escaping

## Features (coursework focus)

* Login with Spotify (OAuth)
* Persist user profile + tokens in Postgres (via Prisma)
* Report on playlists the user owns or follows
* Inspect playlist contents (tracks, artists, albums)
* Stats: counts, unique artists, top artists, release date ranges, average popularity
* Export individual playlists to CSV with comprehensive track metadata
* Export all playlists to a single CSV file with progress tracking
* Simulate deduplication (report duplicate tracks, but don't delete)
* Simulate merge (compare two playlists, report union/intersection sizes)
* Admin metrics:

  * `/metrics` → Prometheus format
  * `/healthz` and `/readyz` → liveness/readiness

## API surface

```http
GET  /auth/login                 # start OAuth with Spotify
GET  /auth/callback              # handle OAuth redirect
POST /auth/logout                # clear user session

GET  /me                         # current user profile
GET  /me/playlists               # list user playlists

GET  /playlists/:id/contents     # playlist tracks (compact)
GET  /playlists/:id/stats        # playlist statistics
GET  /playlists/:id/export       # export playlist as CSV
GET  /playlists/:id/simulate-dedupe
                                 # detect duplicates (non-destructive)

POST /playlists/export-all       # start bulk export job
GET  /playlists/export-progress/:jobId
                                 # check export progress
GET  /playlists/download/:jobId  # download completed export

GET  /simulate-merge?a=PL1&b=PL2 # compare two playlists

GET  /healthz | /readyz | /metrics
```

## Data model (Prisma)

```prisma
model User {
  id           String   @id @default(cuid())
  spotifyId    String   @unique
  email        String?
  displayName  String?
  createdAt    DateTime @default(now())
  tokens       Token?
}

model Token {
  userId      String   @id
  accessToken String
  refreshEnc  String
  scope       String
  expiresAt   DateTime
  user        User @relation(fields: [userId], references: [id], onDelete: Cascade)
}
```

## Frontend

* Vue 3 + Vite (separate `/frontend` project)
* Login button → `/auth/login`
* Views:

  * **Dashboard**: list playlists
  * **Playlist detail**: view contents, run dedupe/merge simulations
* Use `fetch` against `VITE_API_BASE_URL`
* Follow [Vite env conventions](https://vitejs.dev/guide/env-and-mode.html)

## Development

### Local development

```bash
# Start database and API
docker compose up -d

# View logs
docker compose logs -f api

# Run migrations manually
docker compose exec api npx prisma migrate deploy

# Seed database
docker compose exec api npx prisma db seed

# Access database
docker compose exec db psql -U playlistparser -d playlistparser
```

### Environment setup

1. Copy `.env.example` to `.env` in the `/api` directory
2. Configure Spotify API credentials from [Developer Dashboard](https://developer.spotify.com/dashboard)
3. Generate secure keys for `TOKEN_ENC_KEY` and `SESSION_SECRET`
4. Update `FRONTEND_ORIGIN` to match your frontend URL

### Database management

The API uses Prisma for database operations:

* Schema defined in `prisma/schema.prisma`
* Migrations in `prisma/migrations/`
* Seed data in `prisma/seed.js`

Development workflow:

```bash
# Generate Prisma client after schema changes
npx prisma generate

# Create new migration
npx prisma migrate dev --name migration_name

# Deploy migrations (production)
npx prisma migrate deploy

# View database in Prisma Studio
npx prisma studio
```

---

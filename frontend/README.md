# playlistparser-frontend

Vue 3 + Vite client for playlistparser.

Connects to the [playlistparser-api](../api).

## Prerequisites

Before running the frontend, you need to set up the backend API with Spotify credentials:

1. **Spotify Developer Account Setup** (required for API)
   * Create a Spotify app at [developer.spotify.com/dashboard](https://developer.spotify.com/dashboard)
   * Configure redirect URI as: `http://127.0.0.1:3000/auth/callback`
   * Get your Client ID and Client Secret
   * See detailed instructions in [../api/README.md](../api/README.md#spotify-api-setup)

2. **Backend API Running**
   * The frontend requires the API server to be running on port 3000
   * Start the API with: `cd ../api && docker compose up -d`
   * Verify API is running: `curl http://127.0.0.1:3000/healthz`

## Environment variables

Create `.env` in the frontend root:

```env
VITE_API_BASE_URL=http://127.0.0.1:3000
```

Notes:

* All frontend env vars must be prefixed with `VITE_`.
* Use the API service URL in Docker/Kubernetes when deployed.

## Development

```bash
npm install
npm run dev
```

Default dev server: [http://127.0.0.1:5173](http://127.0.0.1:5173)
The app proxies API requests to `VITE_API_BASE_URL`.

## Features

* **Login with Spotify** → redirect to `/auth/login` on the API
* **Dashboard** → list user playlists with "Export All Playlists" functionality
* **Playlist detail view** →

  * Show playlist tracks (artists, albums, popularity, added date)
  * Show statistics (track count, unique artists, release date range, top artists)
  * Export individual playlist to CSV with comprehensive track metadata
  * Run **simulate dedup** (report duplicate tracks without modifying anything)
  * Run **simulate merge** (compare two playlists, show overlap and union sizes)

* **Export functionality** →

  * Individual playlist export with detailed track information
  * Bulk export of all playlists with real-time progress tracking
  * Visual progress indicators showing current playlist being processed
  * Automatic file download when export completes

## Technical Implementation

### Vue 3 Features

* **Composition API** → `<script setup>` syntax for cleaner component logic
* **Vue Router** → Single Page Application routing between views
* **Reactive state** → Real-time updates for export progress and playlist data
* **Component-based** → Modular UI components for reusability

### API Integration

* **Fetch API** → HTTP client for backend communication
* **Credentials included** → Cookie-based authentication with CORS support
* **Error handling** → Comprehensive error states and user feedback
* **Progress polling** → Real-time updates for long-running export operations

### User Interface

* **Responsive design** → Mobile-friendly layout with CSS Grid and Flexbox
* **Loading states** → Visual feedback during data fetching and processing
* **Progress indicators** → Real-time export progress with spinner animations
* **Accessible navigation** → Clear routing and user-friendly URLs

### Build & Deployment

* **Vite bundler** → Fast development server and optimized production builds
* **Docker support** → Multi-stage builds with Nginx for static file serving
* **Environment configuration** → Separate configs for development and production

## Integration with API

Expected API endpoints:

```http
GET  /auth/login
GET  /auth/callback
POST /auth/logout
GET  /me
GET  /me/playlists
GET  /playlists/:id/contents
GET  /playlists/:id/stats
GET  /playlists/:id/export
GET  /playlists/:id/simulate-dedupe
POST /playlists/export-all
GET  /playlists/export-progress/:jobId
GET  /playlists/download/:jobId
GET  /simulate-merge?a=PL1&b=PL2
GET  /healthz | /readyz | /metrics
```

## Build

```bash
npm run build
```

The build output is in `dist/`, ready to be served by Nginx or another static server.

## Docker (local)

```bash
docker build -t playlistparser-frontend .
docker run --rm -p 5173:80 playlistparser-frontend
```

---

## Development Setup

1. Copy `.env.example` to `.env` and set:

```env
VITE_API_BASE_URL=http://127.0.0.1:3000
```

1. Install and run:

```bash
npm install
npm run dev
```

Open [http://127.0.0.1:5173](http://127.0.0.1:5173). Click **Login with Spotify**.

## Production Build

```bash
npm run build
```

The build output is in `dist/`, ready to be served by Nginx or another static server.

## Docker Deployment

```bash
docker build -t playlistparser-frontend .
docker run --rm -p 5173:80 playlistparser-frontend
```

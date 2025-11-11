import fp from 'fastify-plugin';
import { ensureAccess } from './util.js';

// In-memory store for export progress tracking
const exportProgress = new Map();

export default fp(async function playlistReadRoutes(fastify) {
  // List a playlist's raw contents (paged fetch, returned compact)
  fastify.get('/playlists/:id/contents', async (req, reply) => {
    const user = await fastify.authUser(req);
    if (!user) return reply.code(401).send({ error: 'unauthorized' });

    const { accessToken } = await ensureAccess(user.id, fastify);
    const items = await collectAll(`/playlists/${req.params.id}/tracks`, accessToken);

    // Compact projection
    const tracks = items.map((it, idx) => ({
      position: idx,
      id: it.track?.id ?? null,
      name: it.track?.name ?? null,
      artists: (it.track?.artists || []).map(a => ({ id: a.id, name: a.name })),
      album: it.track?.album ? { id: it.track.album.id, name: it.track.album.name, release_date: it.track.album.release_date } : null,
      popularity: it.track?.popularity ?? null,
      duration_ms: it.track?.duration_ms ?? null,
      added_at: it.added_at ?? null
    }));

    return { count: tracks.length, tracks };
  });

  // Stats for a playlist
  fastify.get('/playlists/:id/stats', async (req, reply) => {
    const user = await fastify.authUser(req);
    if (!user) return reply.code(401).send({ error: 'unauthorized' });

    const { accessToken } = await ensureAccess(user.id, fastify);
    
    // Fetch both playlist info and tracks
    const [playlistInfo, items] = await Promise.all([
      fetch(`https://api.spotify.com/v1/playlists/${req.params.id}`, {
        headers: { Authorization: `Bearer ${accessToken}` }
      }).then(res => res.json()),
      collectAll(`/playlists/${req.params.id}/tracks`, accessToken)
    ]);

    const seenTrack = new Set();
    const artistFreq = new Map();
    let minDate = null, maxDate = null, popularitySum = 0, popCount = 0;

    items.forEach(it => {
      const t = it.track;
      if (!t) return;
      seenTrack.add(t.id);

      (t.artists || []).forEach(a => {
        artistFreq.set(a.name, (artistFreq.get(a.name) || 0) + 1);
      });

      const d = t.album?.release_date;
      if (d) {
        const dt = new Date(d.length === 4 ? `${d}-01-01` : d);
        if (!minDate || dt < minDate) minDate = dt;
        if (!maxDate || dt > maxDate) maxDate = dt;
      }

      if (typeof t.popularity === 'number') {
        popularitySum += t.popularity;
        popCount += 1;
      }
    });

    const topArtists = [...artistFreq.entries()]
      .sort((a,b) => b[1]-a[1])
      .slice(0, 10)
      .map(([name,count]) => ({ name, count }));

    return {
      playlist: {
        id: playlistInfo.id,
        name: playlistInfo.name,
        description: playlistInfo.description,
        owner: playlistInfo.owner?.display_name,
        public: playlistInfo.public,
        collaborative: playlistInfo.collaborative
      },
      tracks_total: items.length,
      tracks_unique: seenTrack.size,
      artists_unique: artistFreq.size,
      top_artists: topArtists,
      release_range: {
        oldest: minDate ? minDate.toISOString().slice(0,10) : null,
        newest: maxDate ? maxDate.toISOString().slice(0,10) : null
      },
      avg_popularity: popCount ? Math.round((popularitySum / popCount) * 10) / 10 : null
    };
  });

  // Simulate dedupe (no writes)
  fastify.get('/playlists/:id/simulate-dedupe', async (req, reply) => {
    const user = await fastify.authUser(req);
    if (!user) return reply.code(401).send({ error: 'unauthorized' });

    const { accessToken } = await ensureAccess(user.id, fastify);
    const items = await collectAll(`/playlists/${req.params.id}/tracks`, accessToken);

    const seen = new Set();
    const dupes = [];
    items.forEach((it, idx) => {
      const tid = it.track?.id;
      if (!tid) return;
      if (seen.has(tid)) dupes.push({ position: idx, track: pickTrack(it.track) });
      else seen.add(tid);
    });

    return { total: items.length, duplicates: dupes.length, sample: dupes.slice(0, 20) };
  });

  // Simulate merge result between two playlists
  fastify.get('/simulate-merge', async (req, reply) => {
    const user = await fastify.authUser(req);
    if (!user) return reply.code(401).send({ error: 'unauthorized' });

    const { a, b } = req.query; // playlist IDs
    if (!a || !b) return reply.code(400).send({ error: 'query_required', example: '/simulate-merge?a=PL1&b=PL2' });

    const { accessToken } = await ensureAccess(user.id, fastify);
    const [A, B] = await Promise.all([
      collectAll(`/playlists/${a}/tracks`, accessToken),
      collectAll(`/playlists/${b}/tracks`, accessToken)
    ]);

    const idsA = new Set(A.map(it => it.track?.id).filter(Boolean));
    const idsB = new Set(B.map(it => it.track?.id).filter(Boolean));

    const union = new Set([...idsA, ...idsB]);
    const intersection = new Set([...idsA].filter(x => idsB.has(x)));

    return {
      playlist_a: { id: a, tracks: idsA.size },
      playlist_b: { id: b, tracks: idsB.size },
      union_count: union.size,
      intersection_count: intersection.size,
      would_add_from_b_to_a: [...idsB].filter(x => !idsA.has(x)).length
    };
  });

  async function collectAll(path, accessToken) {
    let url = `https://api.spotify.com/v1${path}?limit=100`;
    const out = [];
    while (url) {
      const r = await fetch(url, { headers: { Authorization: `Bearer ${accessToken}` } });
      if (r.status === 429) throw fastify.httpErrors.tooManyRequests(`retry-after=${r.headers.get('retry-after')}`);
      if (!r.ok) throw fastify.httpErrors.badGateway('spotify_failed');
      const j = await r.json();
      out.push(...j.items);
      url = j.next;
    }
    return out;
  }

  // Export playlist as CSV
  fastify.get('/playlists/:id/export', async (req, reply) => {
    const user = await fastify.authUser(req);
    if (!user) return reply.code(401).send({ error: 'unauthorized' });

    const { accessToken } = await ensureAccess(user.id, fastify);
    
    // Fetch both playlist info and tracks
    const [playlistInfo, items] = await Promise.all([
      fetch(`https://api.spotify.com/v1/playlists/${req.params.id}`, {
        headers: { Authorization: `Bearer ${accessToken}` }
      }).then(res => res.json()),
      collectAll(`/playlists/${req.params.id}/tracks`, accessToken)
    ]);

    // Get user info for filename
    const userRes = await fetch("https://api.spotify.com/v1/me", {
      headers: { Authorization: `Bearer ${accessToken}` }
    });
    const userInfo = await userRes.json();

    // Generate CSV content
    const csvHeaders = [
      'Position',
      'Track Name',
      'Artists',
      'Album',
      'Release Date',
      'Duration (ms)',
      'Duration (mm:ss)',
      'Popularity',
      'Track ID',
      'Album ID',
      'Artist IDs',
      'Added At',
      'Added By',
      'Is Local',
      'Preview URL',
      'External URLs'
    ];

    const csvRows = items.map((item, index) => {
      const track = item.track;
      const artists = (track?.artists || []).map(a => a.name).join('; ');
      const artistIds = (track?.artists || []).map(a => a.id).join('; ');
      const duration = track?.duration_ms;
      const durationFormatted = duration ? 
        `${Math.floor(duration / 60000)}:${String(Math.floor((duration % 60000) / 1000)).padStart(2, '0')}` : 
        '';

      return [
        index + 1,
        track?.name || '',
        artists,
        track?.album?.name || '',
        track?.album?.release_date || '',
        duration || '',
        durationFormatted,
        track?.popularity || '',
        track?.id || '',
        track?.album?.id || '',
        artistIds,
        item.added_at || '',
        item.added_by?.id || '',
        track?.is_local || false,
        track?.preview_url || '',
        track?.external_urls?.spotify || ''
      ].map(field => {
        // Escape CSV fields that contain commas, quotes, or newlines
        const stringField = String(field);
        if (stringField.includes(',') || stringField.includes('"') || stringField.includes('\n')) {
          return `"${stringField.replace(/"/g, '""')}"`;
        }
        return stringField;
      }).join(',');
    });

    const csvContent = [csvHeaders.join(','), ...csvRows].join('\n');

    // Generate filename with timestamp and clean playlist name
    const timestamp = new Date().toISOString().slice(0, 19).replace(/[:\-]/g, '').replace('T', '_');
    const spotifyId = userInfo.id || 'unknown';
    const cleanPlaylistName = (playlistInfo.name || 'playlist')
      .replace(/[^a-zA-Z0-9\s\-_]/g, '') // Remove special characters
      .replace(/\s+/g, '_') // Replace spaces with underscores
      .slice(0, 50); // Limit length

    const filename = `${spotifyId}_${cleanPlaylistName}_${timestamp}.csv`;

    reply
      .header('Content-Type', 'text/csv; charset=utf-8')
      .header('Content-Disposition', `attachment; filename="${filename}"`)
      .send(csvContent);
  });

  // Get export progress
  fastify.get('/playlists/export-progress/:jobId', async (req, reply) => {
    const user = await fastify.authUser(req);
    if (!user) return reply.code(401).send({ error: 'unauthorized' });

    const { jobId } = req.params;
    const progress = exportProgress.get(jobId);
    
    if (!progress) {
      return reply.code(404).send({ error: 'job_not_found' });
    }

    return progress;
  });

  // Start export all playlists process
  fastify.post('/playlists/export-all', async (req, reply) => {
    const user = await fastify.authUser(req);
    if (!user) return reply.code(401).send({ error: 'unauthorized' });

    // Generate a unique job ID
    const jobId = `export_${user.id}_${Date.now()}`;
    
    // Initialize progress tracking
    exportProgress.set(jobId, {
      status: 'starting',
      current: 0,
      total: 0,
      currentPlaylist: null,
      downloadUrl: null,
      error: null
    });

    // Start the export process asynchronously
    processExportAll(jobId, user.id, fastify).catch(error => {
      console.error('Export process error:', error);
      const progress = exportProgress.get(jobId);
      if (progress) {
        progress.status = 'error';
        progress.error = error.message;
      }
    });

    return { jobId };
  });

  // Export all playlists as CSV
  fastify.get('/playlists/export-all', async (req, reply) => {
    const user = await fastify.authUser(req);
    if (!user) return reply.code(401).send({ error: 'unauthorized' });

    const { accessToken } = await ensureAccess(user.id, fastify);
    
    // Get user info for filename
    const userRes = await fetch("https://api.spotify.com/v1/me", {
      headers: { Authorization: `Bearer ${accessToken}` }
    });
    const userInfo = await userRes.json();

    // Get all playlists
    const playlistsRes = await fetch("https://api.spotify.com/v1/me/playlists?limit=50", {
      headers: { Authorization: `Bearer ${accessToken}` }
    });
    const playlistsData = await playlistsRes.json();
    const playlists = playlistsData.items || [];

    // Generate CSV content for all playlists
    const csvHeaders = [
      'Playlist Name',
      'Playlist ID',
      'Playlist Description',
      'Owner',
      'Public',
      'Collaborative',
      'Total Tracks',
      'Position',
      'Track Name',
      'Artists',
      'Album',
      'Release Date',
      'Duration (ms)',
      'Duration (mm:ss)',
      'Popularity',
      'Track ID',
      'Album ID',
      'Artist IDs',
      'Added At',
      'Added By',
      'Is Local',
      'Preview URL',
      'External URLs'
    ];

    const csvRows = [];

    // Process each playlist
    for (const playlist of playlists) {
      try {
        // Get tracks for this playlist
        const items = await collectAll(`/playlists/${playlist.id}/tracks`, accessToken);
        
        // Add each track as a row
        items.forEach((item, index) => {
          const track = item.track;
          const artists = (track?.artists || []).map(a => a.name).join('; ');
          const artistIds = (track?.artists || []).map(a => a.id).join('; ');
          const duration = track?.duration_ms;
          const durationFormatted = duration ? 
            `${Math.floor(duration / 60000)}:${String(Math.floor((duration % 60000) / 1000)).padStart(2, '0')}` : 
            '';

          const row = [
            playlist.name || '',
            playlist.id || '',
            playlist.description || '',
            playlist.owner?.display_name || '',
            playlist.public || false,
            playlist.collaborative || false,
            playlist.tracks?.total || items.length,
            index + 1,
            track?.name || '',
            artists,
            track?.album?.name || '',
            track?.album?.release_date || '',
            duration || '',
            durationFormatted,
            track?.popularity || '',
            track?.id || '',
            track?.album?.id || '',
            artistIds,
            item.added_at || '',
            item.added_by?.id || '',
            track?.is_local || false,
            track?.preview_url || '',
            track?.external_urls?.spotify || ''
          ].map(field => {
            // Escape CSV fields that contain commas, quotes, or newlines
            const stringField = String(field);
            if (stringField.includes(',') || stringField.includes('"') || stringField.includes('\n')) {
              return `"${stringField.replace(/"/g, '""')}"`;
            }
            return stringField;
          }).join(',');

          csvRows.push(row);
        });
      } catch (error) {
        console.error(`Error processing playlist ${playlist.id}:`, error);
        // Continue with other playlists
      }
    }

    const csvContent = [csvHeaders.join(','), ...csvRows].join('\n');

    // Generate filename with timestamp
    const timestamp = new Date().toISOString().slice(0, 19).replace(/[:\-]/g, '').replace('T', '_');
    const spotifyId = userInfo.id || 'unknown';
    const filename = `${spotifyId}_all_playlists_${timestamp}.csv`;

    reply
      .header('Content-Type', 'text/csv; charset=utf-8')
      .header('Content-Disposition', `attachment; filename="${filename}"`)
      .send(csvContent);
  });

  async function processExportAll(jobId, userId, fastify) {
    const progress = exportProgress.get(jobId);
    if (!progress) return;

    try {
      progress.status = 'fetching_playlists';
      
      const { accessToken } = await ensureAccess(userId, fastify);
      
      // Get user info for filename
      const userRes = await fetch("https://api.spotify.com/v1/me", {
        headers: { Authorization: `Bearer ${accessToken}` }
      });
      const userInfo = await userRes.json();

      // Get all playlists
      const playlistsRes = await fetch("https://api.spotify.com/v1/me/playlists?limit=50", {
        headers: { Authorization: `Bearer ${accessToken}` }
      });
      const playlistsData = await playlistsRes.json();
      const playlists = playlistsData.items || [];

      progress.total = playlists.length;
      progress.status = 'processing';

      // Generate CSV content for all playlists
      const csvHeaders = [
        'Playlist Name',
        'Playlist ID',
        'Playlist Description',
        'Owner',
        'Public',
        'Collaborative',
        'Total Tracks',
        'Position',
        'Track Name',
        'Artists',
        'Album',
        'Release Date',
        'Duration (ms)',
        'Duration (mm:ss)',
        'Popularity',
        'Track ID',
        'Album ID',
        'Artist IDs',
        'Added At',
        'Added By',
        'Is Local',
        'Preview URL',
        'External URLs'
      ];

      const csvRows = [];

      // Process each playlist
      for (let i = 0; i < playlists.length; i++) {
        const playlist = playlists[i];
        progress.current = i + 1;
        progress.currentPlaylist = playlist.name;

        try {
          // Get tracks for this playlist
          const items = await collectAll(`/playlists/${playlist.id}/tracks`, accessToken);
          
          // Add each track as a row
          items.forEach((item, index) => {
            const track = item.track;
            const artists = (track?.artists || []).map(a => a.name).join('; ');
            const artistIds = (track?.artists || []).map(a => a.id).join('; ');
            const duration = track?.duration_ms;
            const durationFormatted = duration ? 
              `${Math.floor(duration / 60000)}:${String(Math.floor((duration % 60000) / 1000)).padStart(2, '0')}` : 
              '';

            const row = [
              playlist.name || '',
              playlist.id || '',
              playlist.description || '',
              playlist.owner?.display_name || '',
              playlist.public || false,
              playlist.collaborative || false,
              playlist.tracks?.total || items.length,
              index + 1,
              track?.name || '',
              artists,
              track?.album?.name || '',
              track?.album?.release_date || '',
              duration || '',
              durationFormatted,
              track?.popularity || '',
              track?.id || '',
              track?.album?.id || '',
              artistIds,
              item.added_at || '',
              item.added_by?.id || '',
              track?.is_local || false,
              track?.preview_url || '',
              track?.external_urls?.spotify || ''
            ].map(field => {
              // Escape CSV fields that contain commas, quotes, or newlines
              const stringField = String(field);
              if (stringField.includes(',') || stringField.includes('"') || stringField.includes('\n')) {
                return `"${stringField.replace(/"/g, '""')}"`;
              }
              return stringField;
            }).join(',');

            csvRows.push(row);
          });
        } catch (error) {
          console.error(`Error processing playlist ${playlist.id}:`, error);
          // Continue with other playlists
        }
      }

      const csvContent = [csvHeaders.join(','), ...csvRows].join('\n');

      // Generate filename with timestamp
      const timestamp = new Date().toISOString().slice(0, 19).replace(/[:\-]/g, '').replace('T', '_');
      const spotifyId = userInfo.id || 'unknown';
      const filename = `${spotifyId}_all_playlists_${timestamp}.csv`;

      // In a real app, you'd save this to a file storage service
      // For now, we'll store it in memory temporarily
      progress.status = 'completed';
      progress.downloadUrl = `/playlists/download/${jobId}`;
      progress.csvContent = csvContent;
      progress.filename = filename;

      // Clean up after 10 minutes
      setTimeout(() => {
        exportProgress.delete(jobId);
      }, 10 * 60 * 1000);

    } catch (error) {
      console.error('Export processing error:', error);
      progress.status = 'error';
      progress.error = error.message;
    }
  }

  // Download completed export
  fastify.get('/playlists/download/:jobId', async (req, reply) => {
    const user = await fastify.authUser(req);
    if (!user) return reply.code(401).send({ error: 'unauthorized' });

    const { jobId } = req.params;
    const progress = exportProgress.get(jobId);
    
    if (!progress || progress.status !== 'completed') {
      return reply.code(404).send({ error: 'file_not_ready' });
    }

    reply
      .header('Content-Type', 'text/csv; charset=utf-8')
      .header('Content-Disposition', `attachment; filename="${progress.filename}"`)
      .send(progress.csvContent);
  });

  function pickTrack(t) {
    return {
      id: t.id,
      name: t.name,
      artists: (t.artists||[]).map(a => ({ id:a.id, name:a.name })),
      album: t.album ? { id:t.album.id, name:t.album.name, release_date:t.album.release_date } : null,
      popularity: t.popularity ?? null,
      duration_ms: t.duration_ms ?? null
    };
  }
});

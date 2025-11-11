<script setup>
import { ref, onMounted, watch } from 'vue';
import { endpoints } from '../api.js';
import { useRouter } from 'vue-router';

// Single props definition. `id` comes from the route because router uses `props: true`.
const props = defineProps({ me: Object, id: String });
const router = useRouter();

const playlistId = props.id;
const contents = ref(null);
const stats = ref(null);
const dedupe = ref(null);
const loading = ref(false);
const error = ref(null);

// Debug mode from URL params or environment
const showDebug = ref(new URLSearchParams(window.location.search).has('debug'));

async function loadAll() {
  if (!props.me) return;
  loading.value = true;
  error.value = null;
  try {
    const [c, s, d] = await Promise.all([
      endpoints.playlistContents(playlistId),
      endpoints.playlistStats(playlistId),
      endpoints.simulateDedupe(playlistId)
    ]);
    contents.value = c;
    stats.value = s;
    dedupe.value = d;
  } catch (e) {
    error.value = e.message;
  } finally {
    loading.value = false;
  }
}

function goBack() {
  router.push('/');
}

function exportToCsv() {
  const exportUrl = endpoints.exportPlaylist(playlistId);
  // Create a temporary link element and trigger download
  const link = document.createElement('a');
  link.href = exportUrl;
  link.download = ''; // Let the server set the filename
  document.body.appendChild(link);
  link.click();
  document.body.removeChild(link);
}

function sanitizeDescription(description) {
  if (!description) return '';
  
  // Create a temporary div to parse the HTML
  const tempDiv = document.createElement('div');
  tempDiv.innerHTML = description;
  
  // Allow only safe tags and attributes
  const allowedTags = ['a', 'b', 'i', 'em', 'strong', 'br', 'p'];
  const allowedAttributes = {
    'a': ['href', 'target', 'rel']
  };
  
  // Get all elements
  const elements = tempDiv.querySelectorAll('*');
  
  // Process each element
  elements.forEach(el => {
    const tagName = el.tagName.toLowerCase();
    
    // Remove disallowed tags
    if (!allowedTags.includes(tagName)) {
      el.replaceWith(...el.childNodes);
      return;
    }
    
    // Clean attributes
    const allowedAttrs = allowedAttributes[tagName] || [];
    Array.from(el.attributes).forEach(attr => {
      if (!allowedAttrs.includes(attr.name)) {
        el.removeAttribute(attr.name);
      }
    });
    
    // Add security attributes to links
    if (tagName === 'a') {
      el.setAttribute('target', '_blank');
      el.setAttribute('rel', 'noopener noreferrer');
    }
  });
  
  return tempDiv.innerHTML;
}

onMounted(loadAll);
watch(() => props.id, loadAll);
</script>

<template>
  <section v-if="!me" class="auth-prompt">
    <p>Authenticate to view playlist details.</p>
  </section>

  <section v-else class="playlist-view">
    <!-- Navigation -->
    <div class="nav-header">
      <button @click="goBack" class="back-btn">
        ← Back to Playlists
      </button>
      <button @click="exportToCsv" class="export-btn" :disabled="!stats">
        📄 Export to CSV
      </button>
    </div>

    <!-- Playlist Header -->
    <div class="playlist-header">
      <h1>{{ stats?.playlist?.name || `Loading...` }}</h1>
      <div class="playlist-meta">
        <span class="spotify-id">Spotify ID: {{ playlistId }}</span>
        <span v-if="stats?.playlist?.owner" class="owner">
          by {{ stats.playlist.owner }}
        </span>
      </div>
      <p v-if="stats?.playlist?.description" 
         class="description" 
         v-html="sanitizeDescription(stats.playlist.description)">
      </p>
    </div>

    <div v-if="loading" class="loading">Loading playlist data...</div>
    <div v-if="error" class="error">Error: {{ error }}</div>

    <!-- Debug Info (only when ?debug is in URL) -->
    <div v-if="showDebug" class="debug-info">
      <strong>Debug Info:</strong><br>
      Loading: {{ loading }}<br>
      Error: {{ error }}<br>
      Stats loaded: {{ !!stats }}<br>
      Contents loaded: {{ !!contents }}<br>
      Dedupe loaded: {{ !!dedupe }}
    </div>

    <div v-if="stats" style="display:grid;grid-template-columns:repeat(auto-fit,minmax(220px,1fr));gap:12px;margin-bottom:16px">
      <div style="border:1px solid #eee;border-radius:8px;padding:12px">
        <div>Total tracks</div><strong>{{ stats.tracks_total }}</strong>
      </div>
      <div style="border:1px solid #eee;border-radius:8px;padding:12px">
        <div>Unique tracks</div><strong>{{ stats.tracks_unique }}</strong>
      </div>
      <div style="border:1px solid #eee;border-radius:8px;padding:12px">
        <div>Unique artists</div><strong>{{ stats.artists_unique }}</strong>
      </div>
      <div style="border:1px solid #eee;border-radius:8px;padding:12px">
        <div>Avg popularity</div><strong>{{ stats.avg_popularity ?? '—' }}</strong>
      </div>
      <div style="border:1px solid #eee;border-radius:8px;padding:12px">
        <div>Oldest → Newest</div>
        <strong>{{ stats.release_range?.oldest || '—' }}</strong> →
        <strong>{{ stats.release_range?.newest || '—' }}</strong>
      </div>
    </div>

    <div v-if="stats?.top_artists?.length">
      <h3>Top artists</h3>
      <ol>
        <li v-for="a in stats.top_artists" :key="a.name">{{ a.name }} — {{ a.count }}</li>
      </ol>
    </div>

    <div v-if="dedupe">
      <h3>Simulated dedupe</h3>
      <p>Duplicates: <strong>{{ dedupe.duplicates }}</strong> of {{ dedupe.total }}</p>
      <details>
        <summary>Show sample</summary>
        <ul>
          <li v-for="d in dedupe.sample" :key="d.position">
            #{{ d.position }} — {{ d.track.name }} ·
            <span v-for="(ar, i) in d.track.artists" :key="ar.id">
              {{ ar.name }}<span v-if="i<d.track.artists.length-1">, </span>
            </span>
          </li>
        </ul>
      </details>
    </div>

    <div v-if="contents">
      <h3>Tracks</h3>
      <table style="width:100%;border-collapse:collapse">
        <thead>
          <tr>
            <th style="text-align:left;border-bottom:1px solid #eee;padding:6px">#</th>
            <th style="text-align:left;border-bottom:1px solid #eee;padding:6px">Title</th>
            <th style="text-align:left;border-bottom:1px solid #eee;padding:6px">Artist</th>
            <th style="text-align:left;border-bottom:1px solid #eee;padding:6px">Album</th>
            <th style="text-align:left;border-bottom:1px solid #eee;padding:6px">Popularity</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="t in contents.tracks" :key="t.position">
            <td style="padding:6px">{{ t.position + 1 }}</td>
            <td style="padding:6px">{{ t.name }}</td>
            <td style="padding:6px">
              <span v-for="(a,i) in t.artists" :key="a.id">
                {{ a.name }}<span v-if="i<t.artists.length-1">, </span>
              </span>
            </td>
            <td style="padding:6px">{{ t.album?.name || '—' }}</td>
            <td style="padding:6px">{{ t.popularity ?? '—' }}</td>
          </tr>
        </tbody>
      </table>
    </div>
  </section>
</template>

<style scoped>
.playlist-view {
  max-width: 1200px;
  margin: 0 auto;
  padding: 20px;
}

.nav-header {
  margin-bottom: 20px;
  display: flex;
  gap: 12px;
  align-items: center;
}

.back-btn, .export-btn {
  background: #f8f9fa;
  border: 1px solid #dee2e6;
  border-radius: 8px;
  padding: 8px 16px;
  color: #495057;
  cursor: pointer;
  transition: all 0.2s;
  font-size: 14px;
}

.back-btn:hover, .export-btn:hover:not(:disabled) {
  background: #e9ecef;
  border-color: #adb5bd;
}

.export-btn {
  background: #28a745;
  color: white;
  border-color: #28a745;
}

.export-btn:hover:not(:disabled) {
  background: #218838;
  border-color: #1e7e34;
}

.export-btn:disabled {
  background: #6c757d;
  border-color: #6c757d;
  cursor: not-allowed;
  opacity: 0.6;
}

.playlist-header {
  margin-bottom: 32px;
  padding-bottom: 20px;
  border-bottom: 1px solid #dee2e6;
}

.playlist-header h1 {
  margin: 0 0 12px 0;
  font-size: 2.5rem;
  font-weight: 700;
  color: #212529;
}

.playlist-meta {
  display: flex;
  gap: 16px;
  margin-bottom: 12px;
  flex-wrap: wrap;
}

.spotify-id {
  font-family: 'Monaco', 'Menlo', 'Ubuntu Mono', monospace;
  background: #f8f9fa;
  padding: 4px 8px;
  border-radius: 4px;
  font-size: 12px;
  color: #6c757d;
}

.owner {
  color: #6c757d;
  font-size: 14px;
}

.debug-info {
  background: #fff3cd;
  border: 1px solid #ffeaa7;
  padding: 12px;
  border-radius: 6px;
  margin-bottom: 20px;
  font-size: 12px;
  font-family: monospace;
}

.description {
  color: #495057;
  font-style: italic;
  margin: 8px 0 0 0;
}

.description a {
  color: #0d6efd;
  text-decoration: none;
}

.description a:hover {
  text-decoration: underline;
}
</style>

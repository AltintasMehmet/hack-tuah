<script setup>
import { ref, onMounted, watch } from 'vue';
import { endpoints } from '../api.js';
const props = defineProps({ me: Object });

const playlists = ref([]);
const loading = ref(false);
const error = ref(null);
const exportLoading = ref(false);
const exportProgress = ref(null);
const showDebug = ref(new URLSearchParams(window.location.search).has('debug'));

async function load() {
  console.log('load() called, props.me:', props.me);
  if (!props.me) {
    console.log('No me prop, returning early');
    return;
  }
  loading.value = true;
  error.value = null;
  try {
    console.log('Loading playlists...');
    const data = await endpoints.playlists();
    console.log('Playlists API response:', data);
    console.log('Items array:', data.items);
    console.log('Items count:', data.items?.length);
    playlists.value = data.items || [];
    console.log('Final playlists value:', playlists.value);
  } catch (e) {
    console.error('Error loading playlists:', e);
    error.value = e.message;
  } finally {
    loading.value = false;
  }
}
onMounted(load);
watch(() => props.me, (newMe) => {
  console.log('me prop changed:', newMe);
  if (newMe) load();
});

function sanitizeDescription(description) {
  if (!description) return '';
  
  // Create a temporary div to parse the HTML
  const tempDiv = document.createElement('div');
  tempDiv.innerHTML = description;
  
  // Allow only safe tags and attributes
  const allowedTags = ['a', 'b', 'i', 'em', 'strong', 'br'];
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

async function exportAllPlaylists() {
  console.log('Export all playlists button clicked!');
  
  if (exportLoading.value) {
    console.log('Export already in progress, ignoring click');
    return;
  }
  
  try {
    exportLoading.value = true;
    exportProgress.value = { status: 'starting', current: 0, total: 0 };
    
    // Start the export process
    const result = await endpoints.startExportAll();
    const jobId = result.jobId;
    console.log('Export job started with ID:', jobId);
    
    // Poll for progress
    const pollProgress = async () => {
      try {
        const progress = await endpoints.getExportProgress(jobId);
        exportProgress.value = progress;
        console.log('Progress update:', progress);
        
        if (progress.status === 'completed') {
          // Download the file
          console.log('Export completed, starting download...');
          const downloadUrl = endpoints.downloadExport(jobId);
          window.open(downloadUrl, '_blank');
          
          // Clean up
          exportLoading.value = false;
          exportProgress.value = null;
        } else if (progress.status === 'error') {
          console.error('Export failed:', progress.error);
          exportLoading.value = false;
          exportProgress.value = null;
          error.value = `Export failed: ${progress.error}`;
        } else {
          // Continue polling
          setTimeout(pollProgress, 1000);
        }
      } catch (pollError) {
        console.error('Error polling progress:', pollError);
        exportLoading.value = false;
        exportProgress.value = null;
        error.value = 'Failed to check export progress';
      }
    };
    
    // Start polling after a short delay
    setTimeout(pollProgress, 500);
    
  } catch (exportError) {
    console.error('Error starting export:', exportError);
    exportLoading.value = false;
    exportProgress.value = null;
    error.value = `Failed to start export: ${exportError.message}`;
  }
}
</script>

<template>
  <section v-if="!me" class="auth-section">
    <div class="auth-card">
      <h2>Welcome to the<br>PXL Playlist Parser</h2>
      <p>Authenticate with Spotify to analyze and manage your playlists.</p>
    </div>
  </section>

  <section v-else class="playlists-section">
    <div class="section-header">
      <div class="header-content">
        <h2>Your Playlists</h2>
        <div class="export-section">
          <button 
            v-if="!loading && !error && playlists.length > 0" 
            @click="exportAllPlaylists" 
            :disabled="exportLoading"
            class="export-all-btn"
            :class="{ 'loading': exportLoading }"
          >
            <span v-if="!exportLoading">📁 Export All Playlists</span>
            <span v-else class="loading-content">
              <span class="spinner"></span>
              <span v-if="exportProgress">
                <span v-if="exportProgress.status === 'starting'">Starting...</span>
                <span v-else-if="exportProgress.status === 'fetching_playlists'">Getting playlists...</span>
                <span v-else-if="exportProgress.status === 'processing'">
                  Processing {{ exportProgress.current }}/{{ exportProgress.total }}
                </span>
                <span v-else>Exporting...</span>
              </span>
              <span v-else>Exporting...</span>
            </span>
          </button>
          <div v-if="exportLoading && exportProgress" class="export-progress">
            <div class="progress-info">
              <div v-if="exportProgress.status === 'processing' && exportProgress.currentPlaylist" class="current-playlist">
                📀 {{ exportProgress.currentPlaylist }}
              </div>
              <div v-if="exportProgress.total > 0" class="progress-bar-container">
                <div class="progress-bar">
                  <div 
                    class="progress-fill" 
                    :style="{ width: `${(exportProgress.current / exportProgress.total) * 100}%` }"
                  ></div>
                </div>
                <div class="progress-text">
                  {{ exportProgress.current }} / {{ exportProgress.total }} playlists
                </div>
              </div>
            </div>
          </div>
          <div v-else-if="exportLoading" class="export-warning">
            ⏳ Processing all playlists - this may take 1-2 minutes depending on your library size
          </div>
        </div>
      </div>
      <div v-if="loading" class="loading">Loading your playlists...</div>
      <div v-if="error" class="error">Error: {{ error }}</div>
    </div>
    
    <!-- Debug info (only when ?debug is in URL) -->
    <div v-if="showDebug" class="debug-info">
      <strong>Debug Info:</strong><br>
      Loading: {{ loading }}<br>
      Error: {{ error }}<br>
      Playlists array length: {{ playlists.length }}<br>
      Me object: {{ me ? 'Present' : 'Missing' }}<br>
      First playlist: {{ playlists[0]?.name || 'None' }}
    </div>
    
    <div v-if="!loading && !error" class="playlists-grid">
      <div v-for="p in playlists" :key="p.id" class="playlist-card">
        <div class="playlist-info">
          <h3 class="playlist-name">{{ p.name }}</h3>
          <div class="playlist-meta">
            <span class="track-count">{{ p.tracks?.total ?? 0 }} tracks</span>
            <span v-if="p.owner?.display_name" class="owner">by {{ p.owner.display_name }}</span>
          </div>
          <p v-if="p.description" 
             class="playlist-description" 
             v-html="sanitizeDescription(p.description)">
          </p>
        </div>
        <div class="playlist-actions">
          <router-link :to="`/playlist/${p.id}`" class="analyze-btn">
            Analyze Playlist
          </router-link>
        </div>
      </div>
    </div>
    
    <!-- Show message if no playlists but not loading -->
    <div v-if="!loading && !error && playlists.length === 0" class="empty-state">
      <h3>No playlists found</h3>
      <p>It looks like you don't have any playlists on Spotify, or they're not accessible to this app.</p>
    </div>
  </section>
</template>

<style scoped>
.auth-section {
  display: flex;
  justify-content: center;
  align-items: center;
  min-height: 400px;
  padding: 40px 20px;
}

.auth-card {
  text-align: center;
  max-width: 500px;
  padding: 40px;
  background: white;
  border-radius: 16px;
  box-shadow: 0 4px 20px rgba(0,0,0,0.1);
}

.auth-card h2 {
  margin: 0 0 16px 0;
  font-size: 2rem;
  font-weight: 700;
  color: #212529;
}

.auth-card p {
  color: #6c757d;
  font-size: 16px;
  line-height: 1.5;
}

.playlists-section {
  max-width: 1200px;
  margin: 0 auto;
  padding: 20px;
}

.section-header {
  margin-bottom: 32px;
}

.header-content {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  flex-wrap: wrap;
  gap: 16px;
}

.export-section {
  display: flex;
  flex-direction: column;
  align-items: flex-end;
  gap: 8px;
}

.section-header h2 {
  margin: 0;
  font-size: 2.5rem;
  font-weight: 700;
  color: #212529;
}

.export-all-btn {
  background: #1db954;
  color: white;
  border: none;
  padding: 12px 24px;
  border-radius: 24px;
  font-weight: 600;
  font-size: 14px;
  cursor: pointer;
  transition: background 0.2s, transform 0.1s, opacity 0.2s;
  display: flex;
  align-items: center;
  gap: 8px;
  min-width: 200px;
  justify-content: center;
}

.export-all-btn:hover:not(:disabled) {
  background: #1ed760;
  transform: translateY(-1px);
}

.export-all-btn:active:not(:disabled) {
  transform: translateY(0);
}

.export-all-btn:disabled {
  opacity: 0.7;
  cursor: not-allowed;
  transform: none;
}

.export-all-btn.loading {
  background: #1db954;
}

.loading-content {
  display: flex;
  align-items: center;
  gap: 8px;
}

.spinner {
  width: 16px;
  height: 16px;
  border: 2px solid rgba(255, 255, 255, 0.3);
  border-top: 2px solid white;
  border-radius: 50%;
  animation: spin 1s linear infinite;
}

@keyframes spin {
  0% { transform: rotate(0deg); }
  100% { transform: rotate(360deg); }
}

.export-warning {
  background: #fff3cd;
  color: #856404;
  padding: 8px 12px;
  border-radius: 6px;
  font-size: 12px;
  border: 1px solid #ffeaa7;
  max-width: 250px;
  text-align: center;
  box-shadow: 0 2px 4px rgba(0,0,0,0.1);
}

.export-progress {
  background: #e8f5e8;
  border: 1px solid #c3e6c3;
  border-radius: 8px;
  padding: 12px;
  max-width: 300px;
  box-shadow: 0 2px 4px rgba(0,0,0,0.1);
}

.progress-info {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.current-playlist {
  font-size: 12px;
  color: #2d5a2d;
  font-weight: 500;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.progress-bar-container {
  display: flex;
  flex-direction: column;
  gap: 4px;
}

.progress-bar {
  width: 100%;
  height: 8px;
  background: #d4edda;
  border-radius: 4px;
  overflow: hidden;
}

.progress-fill {
  height: 100%;
  background: #28a745;
  border-radius: 4px;
  transition: width 0.3s ease;
}

.progress-text {
  font-size: 11px;
  color: #2d5a2d;
  text-align: center;
  font-weight: 500;
}

.loading {
  color: #6c757d;
  font-size: 16px;
}

.error {
  background: #f8d7da;
  color: #721c24;
  padding: 16px;
  border-radius: 8px;
  margin-top: 16px;
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

.playlists-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(320px, 1fr));
  gap: 20px;
}

.playlist-card {
  background: white;
  border: 1px solid #dee2e6;
  border-radius: 16px;
  padding: 24px;
  transition: transform 0.2s, box-shadow 0.2s;
  display: flex;
  flex-direction: column;
  justify-content: space-between;
  min-height: 160px;
}

.playlist-card:hover {
  transform: translateY(-4px);
  box-shadow: 0 8px 25px rgba(0,0,0,0.15);
}

.playlist-info {
  flex-grow: 1;
}

.playlist-name {
  margin: 0 0 12px 0;
  font-size: 1.25rem;
  font-weight: 600;
  color: #212529;
  line-height: 1.3;
}

.playlist-meta {
  display: flex;
  gap: 12px;
  margin-bottom: 12px;
  flex-wrap: wrap;
}

.track-count {
  color: #6c757d;
  font-size: 14px;
  font-weight: 500;
}

.owner {
  color: #6c757d;
  font-size: 14px;
}

.playlist-description {
  color: #495057;
  font-size: 14px;
  line-height: 1.4;
  margin: 0;
  display: -webkit-box;
  -webkit-line-clamp: 2;
  line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
}

.playlist-actions {
  margin-top: 16px;
}

.analyze-btn {
  display: inline-block;
  background: #0d6efd;
  color: white;
  padding: 10px 20px;
  border-radius: 8px;
  text-decoration: none;
  font-weight: 500;
  transition: background 0.2s;
  border: none;
  cursor: pointer;
}

.analyze-btn:hover {
  background: #0b5ed7;
  text-decoration: none;
  color: white;
}

.empty-state {
  text-align: center;
  padding: 60px 20px;
  color: #6c757d;
}

.empty-state h3 {
  margin: 0 0 12px 0;
  font-size: 1.5rem;
  font-weight: 600;
  color: #495057;
}

.empty-state p {
  font-size: 16px;
  line-height: 1.5;
  max-width: 500px;
  margin: 0 auto;
}

.playlist-description a {
  color: #0d6efd;
  text-decoration: none;
}

.playlist-description a:hover {
  text-decoration: underline;
}

@media (max-width: 768px) {
  .playlists-section {
    padding: 16px;
  }
  
  .header-content {
    flex-direction: column;
    align-items: flex-start;
  }
  
  .export-section {
    align-items: stretch;
    width: 100%;
  }
  
  .section-header h2 {
    font-size: 2rem;
  }
  
  .export-all-btn {
    align-self: stretch;
    justify-content: center;
  }
  
  .export-warning {
    max-width: none;
    text-align: left;
  }
  
  .export-progress {
    max-width: none;
  }
  
  .playlists-grid {
    grid-template-columns: 1fr;
    gap: 16px;
  }
  
  .playlist-card {
    padding: 20px;
  }
  
  .auth-card {
    padding: 32px 24px;
  }
}
</style>

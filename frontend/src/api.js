const BASE = import.meta.env.VITE_API_BASE_URL;

export async function apiGet(path) {
  const res = await fetch(`${BASE}${path}`, { credentials: 'include' });
  console.log(`API call to ${path}:`, {
    url: `${BASE}${path}`,
    status: res.status,
    ok: res.ok,
    headers: Object.fromEntries(res.headers.entries())
  });
  if (!res.ok) throw new Error(`${res.status} ${res.statusText}`);
  const data = await res.json();
  console.log(`API response for ${path}:`, data);
  return data;
}

export async function apiPost(path, data = {}) {
  const res = await fetch(`${BASE}${path}`, { 
    method: 'POST',
    credentials: 'include',
    headers: {
      'Content-Type': 'application/json'
    },
    body: JSON.stringify(data)
  });
  console.log(`API POST to ${path}:`, {
    url: `${BASE}${path}`,
    status: res.status,
    ok: res.ok,
    headers: Object.fromEntries(res.headers.entries())
  });
  if (!res.ok) throw new Error(`${res.status} ${res.statusText}`);
  const responseData = await res.json();
  console.log(`API response for POST ${path}:`, responseData);
  return responseData;
}

export const endpoints = {
  login: () => `${BASE}/auth/login`,
  logout: () => apiPost('/auth/logout'),
  me: () => apiGet('/me'),
  playlists: () => apiGet('/me/playlists'),
  playlistContents: (id) => apiGet(`/playlists/${id}/contents`),
  playlistStats: (id) => apiGet(`/playlists/${id}/stats`),
  simulateDedupe: (id) => apiGet(`/playlists/${id}/simulate-dedupe`),
  simulateMerge: (a, b) => apiGet(`/simulate-merge?a=${encodeURIComponent(a)}&b=${encodeURIComponent(b)}`),
  exportPlaylist: (id) => `${BASE}/playlists/${id}/export`,
  exportAllPlaylists: () => `${BASE}/playlists/export-all`,
  startExportAll: () => apiPost('/playlists/export-all'),
  getExportProgress: (jobId) => apiGet(`/playlists/export-progress/${jobId}`),
  downloadExport: (jobId) => `${BASE}/playlists/download/${jobId}`
};

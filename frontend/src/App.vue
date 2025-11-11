<script setup>
import { ref, onMounted } from 'vue';
import { endpoints } from './api.js';

const me = ref(null);
const loading = ref(true);
const LOGIN_URL = `${import.meta.env.VITE_API_BASE_URL}/auth/login`;

async function loadMe() {
  loading.value = true;
  try { me.value = await endpoints.me(); } catch { me.value = null; }
  loading.value = false;
}

async function logout() {
  try {
    await endpoints.logout();
    me.value = null;
    // Optionally redirect to home or show a message
  } catch (error) {
    console.error('Logout failed:', error);
    // Even if logout fails on server, clear local state
    me.value = null;
  }
}
onMounted(loadMe);
</script>

<template>
  <header class="app-header">
    <div class="logo">
      <strong>PXL Playlist Parser</strong>
    </div>
    <div class="user-section">
      <div v-if="loading" class="loading-indicator">…</div>
      <div v-else-if="me" class="user-info">
        <span>Hello, <strong>{{ me.displayName || me.email || me.spotifyId }}</strong></span>
        <button @click="logout" class="logout-btn" title="Logout">
          ×
        </button>
      </div>
      <div v-else>
        <a :href="LOGIN_URL" class="login-btn">
          <svg width="20" height="20" viewBox="0 0 24 24" fill="currentColor">
            <path d="M12 0C5.4 0 0 5.4 0 12s5.4 12 12 12 12-5.4 12-12S18.66 0 12 0zm5.521 17.34c-.24.359-.66.48-1.021.24-2.82-1.74-6.36-2.101-10.561-1.141-.418.122-.84-.179-.959-.539-.12-.421.18-.78.54-.9 4.56-1.021 8.52-.6 11.64 1.32.42.18.479.659.361 1.02zm1.44-3.3c-.301.42-.841.6-1.262.3-3.239-1.98-8.159-2.58-11.939-1.38-.479.12-1.02-.12-1.14-.6-.12-.48.12-1.021.6-1.141C9.6 9.9 15 10.561 18.72 12.84c.361.181.54.78.241 1.2zm.12-3.36C15.24 8.4 8.82 8.16 5.16 9.301c-.6.179-1.2-.181-1.38-.721-.18-.601.18-1.2.72-1.381 4.26-1.26 11.28-1.02 15.721 1.621.539.3.719 1.02.42 1.56-.299.421-1.02.599-1.559.3z"/>
          </svg>
          Login with Spotify
        </a>
      </div>
    </div>
  </header>
  <main class="main-content">
    <router-view :me="me" />
  </main>
</template>

<style>
body {
  font-family: ui-sans-serif, system-ui, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
  margin: 0;
  padding: 0;
  background-color: #f8f9fa;
  color: #212529;
}

a {
  color: #2563eb;
  text-decoration: none;
}

a:hover {
  text-decoration: underline;
}

code {
  background: #f6f8fa;
  padding: 2px 4px;
  border-radius: 4px;
}

.app-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 16px 24px;
  background: white;
  border-bottom: 1px solid #dee2e6;
  box-shadow: 0 1px 3px rgba(0,0,0,0.1);
}

.logo {
  font-size: 1.5rem;
  font-weight: 700;
  color: #212529;
}

.user-section {
  display: flex;
  align-items: center;
}

.loading-indicator {
  color: #6c757d;
  font-size: 14px;
}

.user-info {
  color: #495057;
  font-size: 14px;
  display: flex;
  align-items: center;
  gap: 12px;
}

.logout-btn {
  background: none;
  border: none;
  color: #6c757d;
  font-size: 20px;
  line-height: 1;
  cursor: pointer;
  padding: 4px 8px;
  border-radius: 4px;
  transition: all 0.2s;
  display: flex;
  align-items: center;
  justify-content: center;
  width: 24px;
  height: 24px;
}

.logout-btn:hover {
  background: #f8f9fa;
  color: #dc3545;
  transform: scale(1.1);
}

.login-btn {
  display: inline-flex;
  align-items: center;
  gap: 8px;
  background: #1db954;
  color: white;
  padding: 10px 20px;
  border-radius: 50px;
  text-decoration: none;
  font-weight: 500;
  transition: all 0.2s;
  border: none;
  cursor: pointer;
  font-size: 14px;
}

.login-btn:hover {
  background: #1ed760;
  text-decoration: none;
  color: white;
  transform: translateY(-1px);
  box-shadow: 0 4px 12px rgba(29, 185, 84, 0.3);
}

.main-content {
  min-height: calc(100vh - 70px);
}

@media (max-width: 768px) {
  .app-header {
    padding: 12px 16px;
  }
  
  .logo {
    font-size: 1.25rem;
  }
  
  .login-btn {
    padding: 8px 16px;
    font-size: 13px;
  }
}
</style>

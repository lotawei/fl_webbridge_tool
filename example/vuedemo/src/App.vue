<script setup lang="ts">
import { useBridge, getBRData } from 'br-web-bridge-vue'
import { computed } from 'vue'

const { bridgeReady, isInWebView } = useBridge()
const brData = computed(() => getBRData())
const isLoggedIn = computed(() => !!brData.value.accessToken)
const userName = computed(() => brData.value.user?.name as string ?? '')
</script>

<template>
  <div class="app">
    <header class="header" v-if="isLoggedIn || !isInWebView">
      <h1>fl_webbridge_tool</h1>
      <div class="user-info" v-if="userName">👤 {{ userName }}</div>
    </header>

    <nav class="tabs">
      <router-link to="/" class="tab" exact-active-class="active">🏠 主页</router-link>
      <router-link to="/orders" class="tab" active-class="active">📋 工单</router-link>
      <router-link to="/resource" class="tab" active-class="active">📦 资源</router-link>
      <router-link to="/nav" class="tab" active-class="active">🧭 导航</router-link>
      <router-link to="/profile" class="tab" active-class="active">👤 我的</router-link>
    </nav>

    <main>
      <router-view />
    </main>
  </div>
</template>

<style scoped>
* { box-sizing: border-box; margin: 0; padding: 0; }
.app {
  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
  color: #172033; background: #f7f8fb; min-height: 100vh; padding-bottom: 40px;
}
.header { padding: 20px 18px 12px; background: #ffffff; border-bottom: 1px solid #e7e9ef; }
h1 { font-size: 22px; margin-bottom: 6px; }
.user-info { color: #667085; line-height: 1.5; font-size: 13px; }
.tabs { display: flex; background: #fff; border-bottom: 1px solid #e7e9ef; overflow-x: auto; }
.tab { flex: 1; text-align: center; padding: 12px 0; color: #667085; font-size: 13px; font-weight: 600; text-decoration: none; border-bottom: 2px solid transparent; white-space: nowrap; }
.tab.active { color: #2563eb; border-bottom-color: #2563eb; }
main { padding: 16px; }
</style>

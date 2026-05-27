<template>
  <div class="view">
    <h2>👤 注入数据 (__BR_Data__)</h2>

    <div class="card" v-if="brData.accessToken">
      <div class="row"><span class="label">Token</span><span class="value">{{ maskedToken }}</span></div>
      <div class="row"><span class="label">用户</span><span class="value">{{ brData.user?.name || 'N/A' }}</span></div>
      <div class="row"><span class="label">UserID</span><span class="value">{{ brData.user?.id || 'N/A' }}</span></div>
      <div class="row"><span class="label">语言</span><span class="value">{{ brData.lang || 'N/A' }}</span></div>
      <div class="row"><span class="label">App版本</span><span class="value">{{ brData.appVersion || 'N/A' }}</span></div>
      <div class="row"><span class="label">系统版本</span><span class="value">{{ brData.systemVersion || 'N/A' }}</span></div>
    </div>
    <div class="card" v-else>
      <p class="dim">⚠️ 未收到 Native 注入数据（可能不在 WebView 中）</p>
    </div>

    <pre class="log">完整数据:\n{{ JSON.stringify(brData, null, 2) }}</pre>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue'

const brData = computed(() => (window as any).__BR_Data__ || {})

const maskedToken = computed(() => {
  const t = brData.value.accessToken
  return t ? t.slice(0, 12) + '****' + t.slice(-4) : 'N/A'
})
</script>

<style scoped>
h2 { margin-bottom: 16px; }
.card { padding: 16px; background: #fff; border-radius: 8px; border: 1px solid #e7e9ef; }
.row { display: flex; justify-content: space-between; padding: 8px 0; border-bottom: 1px solid #f0f1f5; font-size: 14px; }
.row:last-child { border-bottom: none; }
.label { color: #667085; }
.value { font-weight: 600; }
.dim { color: #98a2b3; text-align: center; }
pre.log { margin-top: 14px; padding: 12px; border: 1px solid #e7e9ef; border-radius: 8px; background: #fff; white-space: pre-wrap; font-size: 12px; }
</style>

<script setup lang="ts">
import { ref, computed } from 'vue'
import { useBridge } from 'br-web-bridge-vue'
const { call, appendLog, logs } = useBridge()

async function setTitle() {
  const t = prompt('新标题', document.title)
  if (t) { document.title = t; appendLog(await call('navigation.setTitle', { title: t })) }
}
async function navigateTo() { appendLog(await call('navigation.navigateTo', { route: '/h2' })) }
async function goBack() { appendLog(await call('navigation.goBack')) }
const tabVisible = ref(true)
async function toggleTabBar() {
  tabVisible.value = !tabVisible.value
  appendLog(await call(tabVisible.value ? 'ui.showTabBar' : 'ui.hideTabBar'))
}
</script>

<template>
  <h2>🧭 导航 & UI 控制</h2>
  <button @click="setTitle">✏️ 设置页面标题</button>
  <button @click="navigateTo">➡️ 跳转到 H2</button>
  <button @click="goBack">⬅️ 返回上一页</button>
  <button @click="toggleTabBar">👁️ {{ tabVisible ? '隐藏' : '显示' }} TabBar</button>
  <pre class="log"><div v-for="(l, i) in logs" :key="i">{{ l.time }}  {{ l.text }}</div></pre>
</template>

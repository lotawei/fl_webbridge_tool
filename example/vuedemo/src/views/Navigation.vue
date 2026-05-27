<template>
  <div class="view">
    <h2 class="title">🧭 导航 & UI 控制</h2>

    <button class="btn" @click="setTitle">✏️ 设置页面标题</button>
    <button class="btn" @click="navigateTo">➡️ 跳转到 H2</button>
    <button class="btn" @click="goBack">⬅️ 返回上一页</button>
    <button class="btn" @click="toggleTabBar">👁️ {{ tabVisible ? '隐藏' : '显示' }} TabBar</button>

    <pre class="log">{{ log }}</pre>
  </div>
</template>

<script setup>
import { ref } from 'vue'
import { call } from '../utils/bridge.js'

const log = ref('')
const tabVisible = ref(true)

function append(value) {
  const text = typeof value === 'string' ? value : JSON.stringify(value, null, 2)
  const time = new Date().toLocaleTimeString()
  log.value = `${time}  ${text}\n\n${log.value}`
}

async function setTitle() {
  const t = prompt('新标题', document.title)
  if (t) {
    document.title = t
    append(await call('navigation.setTitle', { title: t }))
  }
}

async function navigateTo() {
  append(await call('navigation.navigateTo', { route: '/h2' }))
}

async function goBack() {
  append(await call('navigation.goBack'))
}

async function toggleTabBar() {
  tabVisible.value = !tabVisible.value
  append(await call(tabVisible.value ? 'ui.showTabBar' : 'ui.hideTabBar'))
}
</script>

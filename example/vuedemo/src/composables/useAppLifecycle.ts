import { ref, readonly, onUnmounted } from 'vue'
import { addNativeListener, removeNativeListener } from 'br-web-bridge-vue'
import type { NativeCallHandler } from 'br-web-bridge-vue'

export type AppLifecycleState =
  | 'foreground'
  | 'background'
  | 'inactive'
  | 'hidden'
  | 'detached'
  | 'disposed'

export type LifecycleEntry = {
  state: string
  timestamp: number
  source: 'app' | 'page'
}

/**
 * App 生命周期感知 — 接收 Flutter 侧通过 bridge 推送的事件
 *
 * Flutter 侧发送：
 *   _bridge.callWeb('app.lifecycle', { state: 'foreground', timestamp: ... })
 *   _bridge.callWeb('page.visibility', { visible: true, timestamp: ... })
 */
export function useAppLifecycle() {
  const appState = ref<AppLifecycleState>('foreground')
  const pageVisible = ref(true)
  const history = ref<LifecycleEntry[]>([])

  const handler: NativeCallHandler = (msg) => {
    if (msg.action === 'app.lifecycle') {
      appState.value = msg.params.state as AppLifecycleState
      history.value.unshift({ state: msg.params.state as string, timestamp: msg.params.timestamp as number, source: 'app' })
      if (history.value.length > 20) history.value.pop()
    } else if (msg.action === 'page.visibility') {
      pageVisible.value = msg.params.visible as boolean
      history.value.unshift({ state: msg.params.visible ? 'visible' : 'hidden', timestamp: msg.params.timestamp as number, source: 'page' })
      if (history.value.length > 20) history.value.pop()
    }
  }

  // 注册到 SDK 全局多监听器（不会覆盖其他 listener）
  addNativeListener(handler)

  // 组件卸载时自动清理
  if (typeof onUnmounted === 'function') {
    onUnmounted(() => {
      removeNativeListener(handler)
    })
  }

  const label = () => {
    const emoji = appState.value === 'foreground' ? '🟢' : appState.value === 'background' ? '🔴' : '🟡'
    return `${emoji} ${appState.value}${pageVisible.value ? ' · 可见' : ' · 隐藏'}`
  }

  return {
    appState: readonly(appState),
    pageVisible: readonly(pageVisible),
    history: readonly(history),
    label,
  }
}

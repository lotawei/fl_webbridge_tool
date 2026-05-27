import { ref, readonly } from 'vue'

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

  function handleNativeCall(payload: { method: string; params: Record<string, any> }) {
    const { method, params } = payload
    if (method === 'app.lifecycle') {
      appState.value = params.state as AppLifecycleState
      history.value.unshift({ state: params.state, timestamp: params.timestamp, source: 'app' })
      if (history.value.length > 20) history.value.pop()
    } else if (method === 'page.visibility') {
      pageVisible.value = params.visible as boolean
      history.value.unshift({ state: params.visible ? 'visible' : 'hidden', timestamp: params.timestamp, source: 'page' })
      if (history.value.length > 20) history.value.pop()
    }
  }

  // 注入到全局 bridge 接收管道
  if (typeof window !== 'undefined') {
    const existing = (window as any).BR_WebContainer ?? {}
    const prevHandler = existing.__nativeCall
    ;(window as any).BR_WebContainer = {
      ...existing,
      __nativeCall(payload: any) {
        // 先处理生命周期事件
        if (payload?.method && (payload.method === 'app.lifecycle' || payload.method === 'page.visibility')) {
          handleNativeCall(payload)
        }
        // 再转发给上一个处理器（如果有 useBridge 注册的）
        if (typeof prevHandler === 'function') {
          return prevHandler(payload)
        }
        return { received: true }
      },
    }
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

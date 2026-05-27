import { ref } from 'vue'

type LogEntry = {
  time: string
  text: string
}

/**
 * BR_Web Bridge 通信封装
 *
 * 开发时（浏览器而非 WebView）：自动降级为 mock 模式
 * 运行时（Flutter WebView 内）：通过 flutter_inappwebview 通信
 */
export function useBridge() {
  const logs = ref<LogEntry[]>([])
  const bridgeReady = ref(false)
  const isInWebView = ref(typeof (window as any).flutter_inappwebview !== 'undefined')

  function appendLog(value: unknown) {
    const text = typeof value === 'string' ? value : JSON.stringify(value, null, 2)
    const time = new Date().toLocaleTimeString()
    logs.value.unshift({ time, text })
    if (logs.value.length > 100) logs.value.pop()
  }

  function generateId(): string {
    return `${Date.now()}_${Math.random().toString(16).slice(2)}`
  }

  async function call(
    action: string,
    params: Record<string, unknown> = {}
  ): Promise<Record<string, unknown>> {
    const message: BRWebBridgeMessage = {
      id: generateId(),
      action,
      params,
    }

    // 开发模式：mock 返回
    if (!isInWebView.value || !window.flutter_inappwebview) {
      appendLog({ mock: true, action, params, note: '未在 WebView 中运行' })
      return { id: message.id, ok: true, data: { mock: true } }
    }

    try {
      const result = await window.flutter_inappwebview.callHandler(
        'BR_WebNativeBridge',
        message
      )
      appendLog(result)
      return result as Record<string, unknown>
    } catch (err) {
      const error = err instanceof Error ? err.message : String(err)
      appendLog({ id: message.id, ok: false, error })
      return { id: message.id, ok: false, error }
    }
  }

  // 注册 bridge 就绪事件
  function onReady() {
    bridgeReady.value = true
    appendLog('bridge ready in BR_Web')
  }

  // 原生主动调用 H5（链式挂载，与其他 composable 共存）
  if (typeof window !== 'undefined') {
    const existing = (window as any).BR_WebContainer ?? {}
    const prevHandler = existing.__nativeCall
    ;(window as any).BR_WebContainer = {
      ...existing,
      call: (action: string, params: Record<string, unknown> = {}) => call(action, params),
      __nativeCall(payload: unknown) {
        appendLog({ fromNative: payload })
        if (typeof prevHandler === 'function') prevHandler(payload)
        return { received: true }
      },
    }
    window.addEventListener('flutterInAppWebViewPlatformReady', onReady)
  }

  return {
    logs,
    bridgeReady,
    isInWebView,
    call,
    appendLog,
  }
}

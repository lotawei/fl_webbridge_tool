import type {
  BRWebBridgeMessage,
  BRWebBridgeResponse,
  BRWebInitialData,
  NativeCallHandler,
} from './types'

/** 获取全局 token 注入（比 bridge 调用更快，同步读取） */
export function getBRData(): BRWebInitialData {
  return ((window as any).__BR_Data__ || {}) as BRWebInitialData
}

/** 生成唯一请求 ID */
let _seq = 0
function uid(): string {
  return `${Date.now()}_${(++_seq).toString(36)}_${Math.random().toString(16).slice(2, 7)}`
}

// ═════════════════════════════════════════
// 元信息（每次请求自动携带）
// ═════════════════════════════════════════
let _extraMeta: Record<string, unknown> = {}

/** 设置附加元信息（业务方可随时调用追加，如登录后设 userId） */
export function setBridgeMeta(meta: Record<string, unknown>): void {
  _extraMeta = { ..._extraMeta, ...meta }
}

function buildMeta(): Record<string, unknown> {
  const br = getBRData()
  const ua = navigator.userAgent
  const isIOS = /iPhone|iPad|iPod/i.test(ua)
  const isAndroid = /Android/i.test(ua)
  return {
    h5Version: br.extra?.['h5Version'] ?? br.resourceVersion ?? 'unknown',
    h5Branch: br.extra?.['h5Branch'] ?? 'unknown',
    platform: isIOS ? 'ios' : isAndroid ? 'android' : 'web',
    appVersion: br.appVersion,
    lang: br.lang,
    ..._extraMeta,
  }
}

/**
 * 等待 Bridge 就绪
 */
export function waitForBridge(): Promise<void> {
  return new Promise((resolve) => {
    if ((window as any).flutter_inappwebview) return resolve()
    const handler = () => {
      window.removeEventListener('flutterInAppWebViewPlatformReady', handler)
      resolve()
    }
    window.addEventListener('flutterInAppWebViewPlatformReady', handler)
  })
}

/**
 * 调用原生能力
 *
 * @param action - 能力名，如 'device.camera.takePhoto'
 * @param params - 参数
 * @returns 原生返回的 data 字段
 */
export async function brCall<T = Record<string, unknown>>(
  action: string,
  params: Record<string, unknown> = {}
): Promise<T> {
  const message: BRWebBridgeMessage = {
    id: uid(),
    action,
    params,
    meta: buildMeta(),
  }

  if (!(window as any).flutter_inappwebview) {
    console.warn(`[BR_Web] bridge not available: ${action}`)
    return { mocked: true } as unknown as T
  }

  try {
    const result: BRWebBridgeResponse =
      await (window as any).flutter_inappwebview.callHandler(
        'BR_WebNativeBridge',
        message
      )
    if (result && result.ok === false) {
      throw new Error(result.error || 'Bridge call failed')
    }
    return (result?.data ?? result) as T
  } catch (err) {
    console.error(`[BR_Web] call failed: ${action}`, err)
    throw err
  }
}

// ═════════════════════════════════════════
// Native → H5 多监听机制
// ═════════════════════════════════════════

const _nativeListeners: NativeCallHandler[] = []

/**
 * 初始化 window.BR_WebContainer（模块加载时立即执行）
 *
 * Flutter 侧通过 evaluateJavascript 直接调用：
 *   window.BR_WebContainer.__nativeCall({ action: '...', params: {...} })
 *
 * 此处遍历所有已注册的 listener，逐个调用。
 * 返回值取最后一个 listener 的结果；无 listener 时返回默认 {ok:true}。
 *
 * 提前初始化确保 Flutter 在任何时机调用都不会报 "undefined is not a function"。
 */
function _ensureContainer(): void {
  if ((window as any).BR_WebContainer?.__nativeCall) return

  ;(window as any).BR_WebContainer = {
    __nativeCall(raw: any): BRWebBridgeResponse {
      const msg: BRWebBridgeMessage = {
        id: raw.id || '',
        action: raw.action || raw.method || '',
        params: raw.params || {},
        meta: raw.meta,
      }
      let lastResult: BRWebBridgeResponse | undefined
      for (const fn of _nativeListeners) {
        const r = fn(msg)
        if (r) lastResult = r
      }
      return lastResult ?? { id: msg.id, ok: true, data: { received: true } }
    },
  }
}

// 模块加载时立即初始化——防止 Flutter 在 listener 注册前 push 事件导致报错
_ensureContainer()

/**
 * 添加 Native → H5 消息监听
 *
 * 与 flush 覆盖的旧版 onNativeCall 不同，此方法是 append 语义：
 * 多次调用添加多个 handler，Flutter push 过来时全部调用。
 *
 * @example
 * addNativeListener((msg) => { console.log(msg.action) })
 */
export function addNativeListener(fn: NativeCallHandler): void {
  _nativeListeners.push(fn)
}

/**
 * 移除 Native → H5 消息监听
 *
 * @example
 * const handler = (msg) => { ... }
 * addNativeListener(handler)
 * // ... later
 * removeNativeListener(handler)
 */
export function removeNativeListener(fn: NativeCallHandler): void {
  const idx = _nativeListeners.indexOf(fn)
  if (idx >= 0) _nativeListeners.splice(idx, 1)
}

/**
 * @deprecated 使用 addNativeListener 代替。
 *
 * 保留此别名以兼容旧代码，但不再覆盖 window.BR_WebContainer。
 * 多次调用 onNativeCall 现在等价于多次 addNativeListener（追加而非覆盖）。
 */
export function onNativeCall(fn: NativeCallHandler): void {
  addNativeListener(fn)
}

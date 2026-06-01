import type { BRWebBridgeMessage, BRWebBridgeResponse } from './types'

/** 获取全局 token 注入（比 bridge 调用更快，同步读取） */
export function getBRData(): Record<string, unknown> {
  return (window as any).__BR_Data__ || {}
}

/** 生成唯一请求 ID */
let _seq = 0
function uid(): string {
  return `${Date.now()}_${(++_seq).toString(36)}_${Math.random().toString(16).slice(2, 7)}`
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
 * 注册 Native → H5 的消息处理
 */
export function onNativeCall(fn: (payload: unknown) => void): void {
  ;(window as any).BR_WebContainer = {
    __nativeCall(payload: unknown) {
      fn(payload)
      return { received: true }
    },
  }
}

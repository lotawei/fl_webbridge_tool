/// <reference types="vite/client" />
declare module '*.vue' {
  import type { DefineComponent } from 'vue'
  const component: DefineComponent<{}, {}, unknown>
  export default component
}

// 全局 BR_Web 类型声明
interface BRWebBridgeMessage {
  id: string
  action: string
  params: Record<string, unknown>
  meta?: Record<string, unknown>
}

interface BRWebBridgeResponse {
  id: string
  ok: boolean
  data?: Record<string, unknown>
  error?: string
}

interface BRWebData {
  accessToken?: string
  user?: Record<string, unknown>
  lang?: string
  appVersion?: string
  resourceVersion?: string
  extra?: Record<string, unknown>
  [key: string]: unknown
}

interface Window {
  __BR_Data__?: BRWebData
  BR_WebContainer: {
    /** Flutter 侧通过 evaluateJavascript 调用，SDK 内部遍历所有 listener */
    __nativeCall: (payload: any) => BRWebBridgeResponse
  }
  flutter_inappwebview?: {
    callHandler: (name: string, ...args: unknown[]) => Promise<unknown>
  }
}

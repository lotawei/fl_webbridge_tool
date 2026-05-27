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
}

interface BRWebResponse {
  id: string
  ok: boolean
  data?: unknown
  error?: string
  cancelled?: boolean
  path?: string
}

interface BRWebData {
  accessToken?: string
  user?: Record<string, unknown>
  lang?: string
  [key: string]: unknown
}

interface Window {
  __BR_Data__?: BRWebData
  BR_WebContainer: {
    call: (action: string, params?: Record<string, unknown>) => Promise<BRWebResponse>
    __nativeCall: (payload: unknown) => { received: boolean }
  }
  flutter_inappwebview?: {
    callHandler: (name: string, ...args: unknown[]) => Promise<unknown>
  }
}

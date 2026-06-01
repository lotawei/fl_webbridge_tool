import type { App } from 'vue'

/**
 * Vue 3 插件：自动注册 BR_Web Bridge 全局属性
 *
 * 安装后所有组件可通过 `inject` 或 setup 中使用 useBridge()
 */
export const BRWebBridgePlugin = {
  install(_app: App) {
    // 注册原生→H5 消息接收者
    ;(window as any).BR_WebContainer = {
      __nativeCall(payload: unknown) {
        return { received: true }
      },
    }
  },
}

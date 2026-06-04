import type { App } from 'vue'

/**
 * Vue 3 插件
 *
 * 安装后注册全局 bridge 设施。
 * SDK 内部在 bridge.ts 模块加载时已初始化 window.BR_WebContainer，
 * 插件层面无需再手动创建，只需保证 bridge 模块已加载即可。
 */
export const BRWebBridgePlugin = {
  install(_app: App) {
    // bridge.ts 模块加载时已执行 _ensureContainer()
    // 此插件作为显式的 Vue 集成入口，未来可在此注册全局 mixin / provide 等
  },
}

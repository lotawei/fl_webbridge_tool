/** 全局注入数据 */
export interface BRWebInitialData {
  accessToken?: string
  user?: Record<string, unknown>
  lang?: string
  appVersion?: string
  resourceVersion?: string
  extra?: Record<string, unknown>
  [key: string]: unknown
}

/** Bridge 请求消息（H5 ↔ Native 双向统一，唯一消息格式） */
export interface BRWebBridgeMessage {
  id: string
  action: string
  params: Record<string, unknown>
  meta?: Record<string, unknown>
}

/** Bridge 响应（Native → H5 或 H5 → Native，统一响应格式） */
export interface BRWebBridgeResponse {
  id: string
  ok: boolean
  data?: Record<string, unknown>
  error?: string
}

/** Native → H5 消息处理器（addNativeListener 注册的回调签名） */
export type NativeCallHandler = (msg: BRWebBridgeMessage) => BRWebBridgeResponse | void

/** 设备能力: 拍照响应 */
export interface PhotoResult {
  cancelled: boolean
  path?: string
  name?: string
  mimeType?: string
  savedToGallery?: boolean
  galleryPath?: string
}

/** 设备能力: 录像响应 */
export interface VideoResult {
  cancelled: boolean
  path?: string
  name?: string
  mimeType?: string
  savedToGallery?: boolean
  galleryPath?: string
}

/** 设备能力: 录音响应 */
export interface RecordResult {
  recording: boolean
  path?: string
}

/** 设备能力: 文件选择结果 */
export interface PickedFile {
  name: string
  path: string
  size: number
  extension?: string
}

export interface FilePickResult {
  cancelled: boolean
  files: PickedFile[]
}

/** 设备能力: 预览参数 */
export interface PreviewParams {
  path: string
  type?: 'image' | 'video' | 'audio'
  title?: string
  size?: number
  mimeType?: string
}

/** 导航参数 */
export interface NavigateParams {
  route: string
  params?: Record<string, unknown>
}

/** 系统信息 */
export interface SystemInfo {
  deviceModel: string
  os: string
  osVersion: string
  appVersion: string
  buildNumber: string
  deviceId?: string
  isEmulator?: boolean
  locale?: string
}

/** 日志条目 */
export interface BridgeLogEntry {
  type: string
  timestamp: string
  message?: string
  action?: string
  detail?: string
}

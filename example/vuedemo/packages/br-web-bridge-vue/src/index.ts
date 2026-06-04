export {
  brCall,
  getBRData,
  waitForBridge,
  onNativeCall,           // ← deprecated 别名，保留兼容
  addNativeListener,
  removeNativeListener,
  setBridgeMeta,
} from './bridge'
export { useBridge } from './useBridge'
export { BRWebBridgePlugin } from './plugin'
export type * from './types'

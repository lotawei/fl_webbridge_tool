/**
 * BR_Web Bridge 封装
 *
 * 封装 window.flutter_inappwebview.callHandler，
 * 所有 H5 ↔ Flutter 通信统一走这里。
 */

let _bridgeReady = false
let _readyCallbacks = []

/**
 * 调用原生能力
 * @param {string} action - 能力名，如 'device.camera.takePhoto'
 * @param {object} [params={}] - 参数
 * @returns {Promise<any>} 原生返回的数据
 */
export function call(action, params = {}) {
  return new Promise((resolve, reject) => {
    const message = {
      id: `${Date.now()}_${Math.random().toString(16).slice(2)}`,
      action,
      params,
    }

    if (!window.flutter_inappwebview) {
      reject(new Error('Bridge not available (not in WebView)'))
      return
    }

    window.flutter_inappwebview
      .callHandler('BR_WebNativeBridge', message)
      .then((result) => {
        if (result && result.ok === false) {
          reject(new Error(result.error || 'Unknown error'))
        } else {
          resolve(result?.data ?? result)
        }
      })
      .catch(reject)
  })
}

/**
 * 监听 Native 发来的消息
 * @param {function} fn - 回调
 */
export function onNativeCall(fn) {
  window.BR_WebContainer = window.BR_WebContainer || {}
  window.BR_WebContainer.__nativeCall = (payload) => {
    fn(payload)
    return { received: true }
  }
}

/**
 * 等待 Bridge 就绪
 */
export function waitForBridge() {
  return new Promise((resolve) => {
    if (_bridgeReady) return resolve()
    _readyCallbacks.push(resolve)
  })
}

// 监听 flutter_inappwebview 的 platform ready 事件
window.addEventListener('flutterInAppWebViewPlatformReady', () => {
  _bridgeReady = true
  _readyCallbacks.forEach((fn) => fn())
  _readyCallbacks = []
})

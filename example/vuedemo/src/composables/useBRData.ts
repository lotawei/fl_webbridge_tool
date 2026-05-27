import { computed, readonly, ref } from 'vue'

interface BRUserData {
  id: string
  name?: string
  [key: string]: unknown
}

interface BRData {
  accessToken?: string
  user?: BRUserData
  lang?: string
  [key: string]: unknown
}

/**
 * BR_Web 初始化数据（由 Flutter 通过 window.__BR_Data__ 注入）
 *
 * 浏览器模式时使用默认 mock 数据，方便本地开发调试。
 */
export function useBRData() {
  const raw = (typeof window !== 'undefined'
    ? (window as any).__BR_Data__
    : {}) as BRData | undefined

  const brData = ref<BRData>(
    raw && Object.keys(raw).length > 0
      ? raw
      : {
          accessToken: 'dev_mock_token',
          user: { id: '1001', name: '开发者' },
          lang: 'zh',
        }
  )

  const isLoggedIn = () =>
    !!(brData.value.accessToken && brData.value.user)

  const userName = () =>
    brData.value.user?.name ?? brData.value.user?.id ?? '未知'

  const lang = () => brData.value.lang ?? 'zh'

  return {
    brData: readonly(brData),
    isLoggedIn,
    userName,
    lang,
  }
}

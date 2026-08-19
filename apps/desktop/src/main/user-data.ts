/**
 * userData 경로 결정 (BRU-28).
 *
 * `productName`은 사람이 보는 표시 이름이라 자유롭게 바꿀 수 있어야 하지만,
 * Electron은 그 이름으로 `userData`(= appData/<app name>) 경로를 정한다.
 * 표시 이름을 DROP → Braindump로 바꾼 순간 기존 설치본의 저장 경로가 통째로
 * 갈아엎히고 Supabase 세션(localStorage)·설정 파일이 사라진다 — 전원 강제 로그아웃이다.
 *
 * 그래서 경로 이름은 표시 이름과 분리해 여기서 고정한다. 이 값은 식별자다. 바꾸지 마라.
 */
import { join } from 'path'

/** 기존 설치본이 이미 쓰고 있는 디렉터리 이름. 표시 이름과 무관하게 고정이다. */
export const USER_DATA_DIR_NAME = 'DROP'

/** dev 실행이 설치본과 세션·캐시를 공유하지 않도록 접미사를 붙인다. */
export function resolveUserDataDir(appDataDir: string, isPackaged: boolean): string {
  return join(appDataDir, isPackaged ? USER_DATA_DIR_NAME : `${USER_DATA_DIR_NAME}-dev`)
}

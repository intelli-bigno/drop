# DROP 배포 가이드

## 개요

- **Mac (Electron)**: Notarization을 통한 DMG 직접 배포
- **iOS (SwiftUI 네이티브)**: TestFlight를 통한 배포

---

## 사전 요구사항

### 인증서 및 자격 증명

1. **Developer ID Application 인증서** (Mac Notarization용)
   - Keychain에 설치 필요
   - 확인: `security find-identity -v -p codesigning | grep "Developer ID"`

2. **Apple Distribution 인증서** (iOS App Store용)
   - Keychain에 설치 필요
   - 확인: `security find-identity -v -p codesigning | grep "Distribution"`

3. **환경 변수** (빌드 시 필요)
   ```
   APPLE_ID=<your-apple-id>
   APPLE_APP_SPECIFIC_PASSWORD=<앱 전용 비밀번호>
   APPLE_TEAM_ID=<your-team-id>
   ```

### Bundle ID 및 App ID

| 플랫폼 | Bundle ID |
|--------|-----------|
| Mac Desktop | `com.intellieffect.drop.desktop` |
| iOS Mobile | `com.intellieffect.drop.mobile` |
| iOS Share Extension | `com.intellieffect.drop.mobile.share` |

### App Groups

- Group ID: `group.com.intellieffect.drop.shared`
- 메인 앱과 Share Extension이 공유 (세션 Keychain · 공유 자산 인계)

---

## Mac (Electron) 배포

### 빌드 및 Notarization

```bash
cd apps/desktop

# 환경 변수 설정 후 빌드
APPLE_ID=<your-apple-id> \
APPLE_APP_SPECIFIC_PASSWORD=<비밀번호> \
APPLE_TEAM_ID=<your-team-id> \
pnpm dist:remote
```

### 출력물

- DMG 파일: `apps/desktop/release/DROP-<version>-arm64.dmg`
- Notarization 자동 완료

### electron-builder 설정 (package.json)

```json
{
  "build": {
    "appId": "com.intellieffect.drop.desktop",
    "mac": {
      "target": "dmg",
      "identity": "<Your Name> (<your-team-id>)",
      "hardenedRuntime": true,
      "notarize": true
    }
  }
}
```

---

## iOS (SwiftUI 네이티브) 배포

**표준 경로는 CI다.** 서명 자산이 GitHub Secrets에만 있으므로 로컬 아카이브는 권장하지 않는다.

### 검증 빌드만 TestFlight로 (태그 없이)

```bash
gh workflow run release.yml -f target=ios
gh run watch
```

### 정식 릴리스 (데스크톱 DMG까지 함께)

```bash
make release   # 버전 범프 → 태그 push → mac + iOS 동시 배포
```

### CI가 하는 일 (`.github/workflows/release.yml` / `release-ios`)

1. XcodeGen으로 `Drop.xcodeproj` 생성 (`.xcodeproj`는 커밋되지 않는다)
2. 인증서 + 프로비저닝 프로파일 2종(app / share)을 임시 키체인에 주입
3. 빌드 번호를 `date -u +%y%m%d%H%M`로 산출 — 과거 Flutter 빌드(최대 38)보다 항상 크다
4. `Drop-remote` 스킴 / `Release-remote` 구성으로 archive → export → `altool` 업로드

### 출력물

- IPA: 워크플로우 아티팩트 `DROP-ios-ipa`

> Android는 현재 배포 대상이 아니다. Flutter 앱 제거(BRU-22)와 함께 빌드 경로가 사라졌고, 재개 여부는 BRU-33에서 결정한다.

---

## Apple Developer 설정 체크리스트

### App Store Connect

- [ ] iOS 앱 등록 (`com.intellieffect.drop.mobile`)
- [ ] Mac 앱 등록 (필요 시)

### Certificates, Identifiers & Profiles

- [ ] Developer ID Application 인증서 (Mac)
- [ ] Apple Distribution 인증서 (iOS)
- [ ] App ID: `com.intellieffect.drop.mobile` (App Groups 활성화)
- [ ] App ID: `com.intellieffect.drop.mobile.share` (Share Extension, 같은 App Group)
- [ ] App ID: `com.intellieffect.drop.mobile.widget` (App Groups 활성화)
- [ ] App Group: `group.com.intellieffect.drop.widget`

---

## GitHub Actions CI/CD

### 워크플로우

| 워크플로우 | 트리거 | 설명 |
|-----------|--------|------|
| `ci.yml` | Push/PR to main | 테스트, 린트, 빌드 검증 |
| `release.yml` | Tag push (v*) | Mac DMG + iOS TestFlight 배포 |

### 필요한 GitHub Secrets

| Secret | 설명 |
|--------|------|
| `APPLE_ID` | Apple Developer 이메일 |
| `APPLE_APP_SPECIFIC_PASSWORD` | 앱 전용 비밀번호 |
| `APPLE_TEAM_ID` | Apple Developer Team ID |
| `CSC_NAME` | Code Signing Identity (예: "Developer ID Application: Name (TEAM_ID)") |
| `CERTIFICATES_P12` | 인증서 파일 (base64 인코딩) |
| `CSC_KEY_PASSWORD` | P12 파일 비밀번호 |
| `SUPABASE_URL` | Supabase 프로젝트 URL |
| `SUPABASE_ANON_KEY` | Supabase Anonymous Key |

### Secrets 설정 방법

**1. P12 파일 Base64 인코딩:**
```bash
base64 -i Certificates.p12 | pbcopy
# 클립보드에 복사된 값을 CERTIFICATES_P12 시크릿에 저장
```

**2. GitHub에서 Secrets 추가:**
- Repository → Settings → Secrets and variables → Actions
- "New repository secret" 클릭
- 위 테이블의 각 시크릿 추가

### 릴리스 방법

```bash
# 버전 태그 생성 및 푸시
git tag v1.0.0
git push origin v1.0.0
```

태그 푸시 시 자동으로:
1. Mac DMG 빌드 + Notarization
2. iOS IPA 빌드 + TestFlight 업로드
3. GitHub Release에 DMG 첨부

---

## 문제 해결

### Notarization 실패

1. Developer ID Application 인증서 확인
2. 환경 변수 (APPLE_ID, APPLE_APP_SPECIFIC_PASSWORD, APPLE_TEAM_ID) 확인
3. `hardenedRuntime: true` 설정 확인

### iOS 서명 오류

1. Team ID 일치 확인 (Xcode 프로젝트 vs 인증서)
2. App Groups capability 설정 확인
3. Provisioning Profile 재생성

### App Group 등록 실패

- 이미 사용 중인 ID인 경우 다른 이름 사용
- 예: `group.com.yourcompany.drop.widget`

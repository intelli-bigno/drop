# Supabase Development Workflow

> **CRITICAL**: 이 문서는 Supabase 관련 모든 작업의 필수 지침입니다.
> LLM/AI 어시스턴트는 이 워크플로우를 **절대로 생략하거나 건너뛸 수 없습니다**.

---

## MANDATORY RULES (필수 규칙)

### STOP - 작업 전 반드시 확인

```
┌─────────────────────────────────────────────────────────────────┐
│  SUPABASE 스키마 변경 시 반드시 다음을 수행해야 합니다:         │
│                                                                 │
│  1. Dashboard에서 직접 수정 ❌ PROHIBITED                       │
│  2. 마이그레이션 파일 생성 ✅ REQUIRED                          │
│  3. 로컬에서 먼저 테스트 ✅ REQUIRED                            │
│  4. 테스트 통과 후 커밋 ✅ REQUIRED                             │
└─────────────────────────────────────────────────────────────────┘
```

---

## 1. 로컬 개발 환경

### 1.1 시작하기

```bash
# Supabase 로컬 서비스 시작
supabase start

# 상태 확인
supabase status
```

### 1.2 로컬 서비스 포트 (config.toml 기준)

| 서비스 | 포트 | URL |
|--------|------|-----|
| API | 58321 | http://127.0.0.1:58321 |
| DB | 58322 | postgresql://postgres:postgres@127.0.0.1:58322/postgres |
| Studio | 58323 | http://127.0.0.1:58323 |
| Inbucket | 58324 | http://127.0.0.1:58324 |

---

## 2. 마이그레이션 워크플로우

### MANDATORY: 스키마 변경 절차

> **NEVER** skip any of these steps.
> **NEVER** modify the production database directly.

#### Step 1: 마이그레이션 파일 생성

```bash
# 새 마이그레이션 생성
supabase migration new <migration_name>
# 예: supabase migration new add_users_table
```

**Naming Convention (필수)**:
- `add_<entity>` - 새 테이블/컬럼 추가
- `update_<entity>` - 기존 구조 수정
- `remove_<entity>` - 삭제
- `add_<entity>_rls` - RLS 정책 추가

#### Step 2: SQL 작성

`supabase/migrations/<timestamp>_<name>.sql`:

```sql
-- 예시: 테이블 생성
create table public.users (
  id uuid primary key default gen_random_uuid(),
  email text unique not null,
  created_at timestamptz default now()
);

-- RLS 활성화 (REQUIRED for all tables)
alter table public.users enable row level security;

-- RLS 정책 (REQUIRED)
create policy "Users can view own data"
  on public.users for select
  using (auth.uid() = id);
```

#### Step 3: 로컬 적용 및 테스트

```bash
# 데이터베이스 리셋 (모든 마이그레이션 재적용)
supabase db reset

# 또는 새 마이그레이션만 적용
supabase migration up
```

#### Step 4: 검증

```bash
# 마이그레이션 상태 확인
supabase migration list

# 타입 생성 (TypeScript 프로젝트)
supabase gen types typescript --local > packages/shared/src/database.types.ts
```

#### Step 5: 커밋

```bash
git add supabase/migrations/
git commit -m "feat(db): add users table with RLS policies"
```

---

## 3. 스키마 변경 방법

### 3.1 수동 마이그레이션 (RECOMMENDED)

직접 SQL을 작성하여 마이그레이션 파일 생성.

### 3.2 자동 스키마 Diff

로컬 Studio에서 변경 후 diff 생성:

```bash
# Studio에서 변경 후
supabase db diff -f <migration_name>

# 또는 migra 사용 (더 간결한 출력)
supabase db diff --use-migra -f <migration_name>
```

**WARNING**: 자동 생성된 SQL은 반드시 검토 후 커밋할 것.

---

## 4. 시드 데이터

### 4.1 시드 파일 위치

`supabase/seed.sql`

### 4.2 시드 데이터 작성

```sql
-- 테스트용 데이터만 포함
-- 절대로 실제 사용자 데이터나 민감 정보 포함 금지

insert into public.users (email)
values
  ('test@example.com'),
  ('demo@example.com');
```

### 4.3 시드 적용

```bash
# db reset 시 자동 적용
supabase db reset

# 또는 수동 적용
psql postgresql://postgres:postgres@127.0.0.1:58322/postgres -f supabase/seed.sql
```

---

## 5. 배포 워크플로우

### 5.1 환경 구조

```
Local (로컬)     → 개발/테스트
     ↓
Production      → 실 서비스
```

### 5.2 Production 배포

#### MANDATORY: 배포 전 체크리스트

```
□ 모든 마이그레이션이 로컬에서 테스트됨
□ supabase db reset이 오류 없이 완료됨
□ RLS 정책이 모든 테이블에 적용됨
□ 타입이 최신 상태로 생성됨
□ 코드가 main 브랜치에 머지됨
```

#### 배포 명령

```bash
# 프로젝트 연결 확인
supabase link --project-ref <project-id>

# 마이그레이션 배포
supabase db push
```

---

## 6. 보안 체크리스트

### MANDATORY: 모든 테이블에 적용

```
□ RLS 활성화: alter table <table> enable row level security;
□ RLS 정책 정의: 최소 SELECT 정책 필수
□ 민감 컬럼 접근 제한
□ 서비스 롤 사용 최소화
```

### 보안 검사 실행

```bash
# 보안 어드바이저 확인 (MCP 도구 사용)
# mcp__supabase__get_advisors --type security
```

---

## 7. 트러블슈팅

### 7.1 마이그레이션 롤백

```bash
# 로컬: 완전 리셋
supabase db reset

# 특정 버전으로 리셋 (주의: 데이터 손실)
supabase migration repair --status reverted <version>
```

### 7.2 스키마 충돌

```bash
# 원격 스키마 가져오기
supabase db pull

# 차이점 확인
supabase db diff
```

### 7.3 권한 오류

```sql
-- 테이블 소유자 변경
ALTER TABLE <table_name> OWNER TO postgres;
```

---

## 8. 명령어 요약

| 명령어 | 설명 |
|--------|------|
| `supabase start` | 로컬 서비스 시작 |
| `supabase stop` | 로컬 서비스 중지 |
| `supabase status` | 상태 확인 |
| `supabase migration new <name>` | 새 마이그레이션 생성 |
| `supabase db reset` | DB 리셋 + 모든 마이그레이션 적용 |
| `supabase db diff -f <name>` | 스키마 차이 추출 |
| `supabase db push` | 원격 DB에 마이그레이션 적용 |
| `supabase db pull` | 원격 스키마 가져오기 |
| `supabase gen types typescript --local` | 타입 생성 |
| `supabase migration list` | 마이그레이션 상태 확인 |

---

## FINAL REMINDER

```
┌─────────────────────────────────────────────────────────────────┐
│                         CRITICAL                                │
│                                                                 │
│  1. Dashboard 직접 수정 → PROHIBITED (금지)                     │
│  2. 마이그레이션 없는 스키마 변경 → PROHIBITED (금지)           │
│  3. RLS 없는 테이블 → PROHIBITED (금지)                         │
│  4. 로컬 테스트 없는 배포 → PROHIBITED (금지)                   │
│                                                                 │
│  이 규칙을 어기면 데이터 유실 및 보안 취약점이 발생합니다.      │
└─────────────────────────────────────────────────────────────────┘
```

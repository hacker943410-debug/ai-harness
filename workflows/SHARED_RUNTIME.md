# 공용 런타임 수명주기

대상: 이 하네스로 MCP 공용 런타임을 다루는 사람 / AI
읽는 순서: 이 문서 → `runtimes/<id>.runtime.json` → 필요한 스크립트

---

## 0. 공용 런타임이란

**PC 에 하나만 두고 모든 프로젝트가 함께 쓰는 MCP 서버**다.
프로젝트별 MCP(`.ai/mcp/desired.json`)와는 다른 물건이고, 섞으면 안 된다.

| | 프로젝트 MCP | 공용 런타임 |
|---|---|---|
| 설치 위치 | 프로젝트 `node_modules` | `%LOCALAPPDATA%\AI-Tools\<id>\<version>` |
| 개수 | 프로젝트마다 | PC 당 1개 |
| 버전 정본 | 프로젝트 lock | `runtimes/<id>.runtime.json` 의 `install.version` |
| 인증 | 보통 없음(또는 프로젝트 토큰) | 계정 단위 OAuth. **모든 프로젝트가 같은 계정으로 동작한다** |
| 설치 명령 | `Install-ProjectMcp.ps1` | `Install-HarnessRuntime.ps1` |

카탈로그에서 `install.kind` 가 `shared_runtime` 인 항목이 여기 해당한다.
`Install-ProjectMcp.ps1` 은 그런 항목을 **거부한다**. 프로젝트마다 설치하면
버전이 프로젝트 수만큼 갈라지고, 각 사본이 같은 OAuth 토큰을 쓰게 되며,
정본이 매니페스트인지 프로젝트 lock 인지 아무도 모르게 된다.

---

## 1. 세 계층 — 무엇이 어디에 있는가

| 계층 | 위치 | 담는 것 | git |
|---|---|---|---|
| A 하네스 | `runtimes/<id>.runtime.json` | **무엇을, 어떤 버전으로**. 절대경로 금지 | ✅ |
| B 머신 | `<tools_root>/runtimes.json`, `clients.json` | **어디에 설치했고 누구로 인증했는가** | ❌ |
| C 프로젝트 | `<proj>/.ai/capability-lock.json` | **capability ID 만** | ✅ |

Layer A 에 절대경로를 쓰면 다른 모든 PC 에서 틀린 값이 된다.
경로는 `${HOME}` `${CONFIG_HOME}` `${TOOLS_ROOT}` `${RUNTIME_DIR}` 와
매니페스트가 선언한 `parameters` 키로만 표현한다.
`Test-HarnessRepo.ps1` 이 이 규칙을 강제한다.

---

## 2. 순서 — install → auth → verify → sync

이 순서여야 하는 이유가 각각 있다. 건너뛰면 조용히 잘못된 상태가 남는다.

```
  1. install   Install-HarnessRuntime.ps1        실체를 만든다
       ↓
  2. auth      Connect-HarnessRuntimeAuth.ps1    누구로 동작할지 정한다
       ↓
  3. verify    Test-HarnessRuntime.ps1           실제로 되는지 증명한다
       ↓
  4. sync      Sync-HarnessClients.ps1           클라이언트에 올린다
                 └─ 계획 파일 → Install-Harness.ps1 이 확인 후 적용
       ↓
  5. restart   해당 CLI 를 재시작한다
```

### 왜 이 순서인가

- **auth 가 install 뒤인 이유**: 인증 실행 파일이 설치 디렉터리 안에 있다.
- **verify 가 auth 뒤인 이유**: 인증 없이 전송만 확인하면 "도구 목록은 보이는데
  모든 호출이 실패하는" 상태를 verified 로 기록하게 된다.
- **sync 가 verify 뒤인 이유**: 되지도 않는 것을 3개 CLI 에 뿌리면
  고쳐야 할 곳이 1곳에서 3곳으로 늘어난다.
- **restart 가 필요한 이유**: 이미 떠 있는 CLI 세션은 옛 등록을 물고 있다.
  등록을 바꿔도 그 세션에는 반영되지 않는다.
  `Install-Harness.ps1` 은 적용 직전에 실행 중인 세션을 확인하고 기본적으로 거부한다.

### 상태는 네 가지다

`installed ≠ registered ≠ authenticated ≠ verified`

| 상태 | 무엇이 증명됐나 | 증명한 것 |
|---|---|---|
| installed | 파일이 있다 | `Install-HarnessRuntime.ps1` |
| authenticated | 토큰 파일이 생겼다 | `Connect-HarnessRuntimeAuth.ps1` |
| registered | CLI 가 이 서버를 안다 | `Register-HarnessRuntimeClient.ps1` (되읽어 확인) |
| verified | **실제 API 호출이 성공했다** | `Test-HarnessRuntime.ps1` |

`Connect-HarnessRuntimeAuth.ps1` 은 절대로 `verified` 를 쓰지 않는다.
토큰 파일이 생겼다는 것은 실제 호출을 증명하지 않는다.
이 런타임의 `get_status` 는 **오류 상황도 성공한 도구 호출로 반환**하므로
exit code 로 판정하면 인증 안 된 런타임을 인증됐다고 기록하게 된다.
그래서 매니페스트의 `verify` 블록은 실제 데이터를 반환하는 도구를 지정한다.

---

## 3. 명령

### 설치

```powershell
.\scripts\Get-HarnessEnvironment.ps1                          # 먼저 이 PC 를 본다 (읽기 전용)
.\scripts\Install-HarnessRuntime.ps1 -RuntimeId google-workspace
.\scripts\Install-HarnessRuntime.ps1 -RuntimeId google-workspace -Adopt      # 기존 설치 채택
```

설치 경로는 `<tools_root>/<runtime_id>/<version>` 이다.
버전별로 분리되므로 롤백은 재다운로드 없이 포인터 전환으로 끝난다.

### 인증

```powershell
.\scripts\Connect-HarnessRuntimeAuth.ps1 -RuntimeId google-workspace -CredentialSource <다운로드한 client_secret.json> -DryRun
.\scripts\Connect-HarnessRuntimeAuth.ps1 -RuntimeId google-workspace -CredentialSource <...>
```

자격증명 원본은 다음 위치에서 오면 **거부된다**. 셋 다 실제로 비밀값이 새는 경로다.

- git 워크트리 안 → 커밋된다
- 도구 루트 안 → 공용 실행 경로에 비밀값을 두는 것
- 다른 주체가 쓸 수 있는 곳 → 우리가 읽기 전에 바꿔치기된다

**활성 서비스가 곧 요청되는 OAuth 스코프다.** 매니페스트의 `parameters.services` 에
없는 서비스의 권한은 인증 시 요청되지 않는다. 나중에 서비스를 늘리면 **재인증해야 한다**.

토큰 저장소는 도구 루트 **밖**(`${HOME}/.config/...`)에 있다.
따라서 도구 루트를 옮겨도 재로그인이 필요 없다.

### 검증

```powershell
.\scripts\Test-HarnessRuntime.ps1 -RuntimeId google-workspace
```

전송 검증(도구 목록이 오는가)과 인증 검증(실제 호출이 되는가)은 별개로 판정된다.

### 클라이언트 정합

```powershell
.\scripts\Sync-HarnessClients.ps1                             # 행렬 보기 (읽기 전용)
.\scripts\Sync-HarnessClients.ps1 -SavePlan .\sync.json       # 계획 만들기
.\scripts\Install-Harness.ps1 -Plan .\sync.json -DryRun       # 실행될 명령 확인
.\scripts\Install-Harness.ps1 -Plan .\sync.json               # 확인 후 적용
```

정합 스크립트는 **아무것도 바꾸지 않는다**. 계획만 만든다.
살아있는 설정을 바꾸는 경로는 `Install-Harness.ps1` 하나여야 한다.
경로가 둘이면 확인 절차를 우회하는 길이 생긴다.

행렬의 상태:

| 상태 | 뜻 |
|---|---|
| `ok` | 선언과 실제가 일치 |
| `drift` | 등록은 있으나 내용이 선언과 다름 |
| `unregistered` | 클라이언트에 없음 |
| `unknown` | probe 로 실제 값을 읽을 수 없음. **OK 가 아니다** |
| `client_absent` | 그 CLI 가 이 PC 에 없음 |
| `runtime_absent` | 런타임 미설치 |
| `orphan` | 원장에는 있으나 더 이상 선언되지 않은 런타임 |
| `foreign_root` | 다른 도구 루트에서 등록된 기록 |

### 해제

```powershell
.\scripts\Disconnect-HarnessRuntime.ps1 -RuntimeId google-workspace -DryRun
.\scripts\Disconnect-HarnessRuntime.ps1 -RuntimeId google-workspace
```

순서: **권한 취소 → 토큰 삭제 → 등록 제거 → state 되돌림.**

토큰을 먼저 지우면 취소할 수단이 사라진다.
**토큰 파일 삭제는 "이 PC 가 잊는 것"이지 "끊는 것"이 아니다.**
Google 쪽 부여(grant)는 그대로 남는다. 취소에 실패하면 스크립트는 멈춘다.
사람이 직접 취소한 뒤 `-ForceWithoutRevoke` 로 다시 실행한다.

설치 자체는 지우지 않는다. 재로그인만 하면 다시 쓸 수 있다.

---

## 4. 새 공용 런타임 추가하기

**스크립트를 고쳐야 한다면 설계가 틀린 것이다.** 데이터만 추가한다.

1. `runtimes/<id>.runtime.json` 을 만든다 (`runtimes/_TEMPLATE.runtime.json` 복사)
2. `catalogs/mcp-catalog.json` 에 항목을 넣는다
   - `install.kind` = `shared_runtime`
   - `install.runtime_id` = 매니페스트의 `runtime_id`
   - `install.manifest` = 매니페스트 경로
   - **`package` / `version` 은 쓰지 않는다.** 정본은 매니페스트다
   - 카탈로그 `id` = 매니페스트의 `capability_id`
3. `.\scripts\Test-HarnessRepo.ps1` 로 계약을 확인한다

새 AI 클라이언트를 추가할 때도 마찬가지로 `settings/clients/<id>.client.json` 하나면 된다.

### 매니페스트에서 지켜야 할 것

- 버전은 **정확히** 고정한다. `latest` / `^` / `~` / `*` 는 검사기가 막는다
- 절대경로 금지. 보간 토큰만 쓴다
- `credentials.never_sync` 는 `required_files` 와 `auth_state_files` 를 모두 포함해야 한다.
  동기화 스크립트가 제외 목록을 따로 하드코딩하면 두 목록이 갈라지고,
  갈라지는 순간 비밀값이 올라간다. 검사기가 이것도 막는다
- `verify` 는 **실제 데이터를 반환하는 도구**를 지정한다.
  상태 조회 도구는 오류 상황도 성공으로 반환할 수 있다
- `platforms` 에는 **실제로 검증한 플랫폼만** 적는다.
  검증하지 않은 곳에서 시도하려면 `-AllowUnverifiedPlatform` 을 쓰고,
  성공하면 `platforms` 와 `platforms_verified_on` 을 갱신한다

---

## 5. 자주 나오는 함정

| 증상 | 원인 |
|---|---|
| 등록을 바꿨는데 CLI 가 옛 동작을 한다 | 세션 재시작을 안 했다 |
| `mcp get` 은 성공하는데 도구 호출이 전부 실패 | 인증이 안 됐다. `installed ≠ authenticated` |
| 새로 켠 서비스만 권한 오류 | 인증 시 그 스코프를 요청하지 않았다. 재인증 필요 |
| 등록이 며칠 뒤 사라져 있다 | 제3의 도구가 CLI 설정 파일을 소유한다. `Get-HarnessEnvironment.ps1` 이 관리형 설정 홈을 경고한다 |
| 진단이 `unknown` 을 낸다 | probe 로 실제 값을 못 읽는 것이다. 통과가 아니다. 재등록해서 아는 상태로 만든다 |
| `Restricted` 인 PC 에서 스크립트가 죽는다 | `npm` / `claude` / `codex` 가 `.ps1` 로 해석된다. 모든 호출은 `Get-HarnessNativeCommand` 를 거쳐야 한다 |

---

## 6. 관련 문서

- `workflows/HARNESS_INSTALL.md` — PC 환경별 최초 설치
- `workflows/GOOGLE_WORKSPACE_SETUP.md` — Google OAuth 클라이언트 발급
- `proposals/HARNESS_V3_PROPOSAL.md` — 설계 근거
- `runtimes/_TEMPLATE.runtime.json` — 매니페스트 템플릿

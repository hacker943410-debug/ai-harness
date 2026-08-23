# AI Harness v3 마이그레이션 — 인수인계

작성: 2026-08-23
용도: 세션이 끊긴 뒤 **다음 세션이 이 문서만 읽고 이어서 작업**할 수 있게 한다.
읽는 순서: 이 문서 → `proposals/HARNESS_V3_PROPOSAL.md`(설계 근거) → 필요한 코드

---

## 0. 한 문장 요약

`C:\AI-Harness`(AI Harness 2.2)를 **GitHub에서 받아 어느 PC에서든 설치·사용할 수 있는 3계층 구조**로 재편하는 중이다.
**M0~M7b 구현 완료. M8 도 대부분 끝났다.**
이 PC 적용 완료: 하네스 저장소 ACL 제한 / 카탈로그 레지스트리 좌표 확정(조회 대상 0건) /
claude·agy 등록 드리프트 해소 / AGY 노출 완화(`mcp disable`) /
**v2.2 레거시 경로 은퇴 + 래퍼 삭제 (2026-08-23)**.

**2026-08-23 추가 완료:** v2.2 레거시 경로 은퇴 + 래퍼 삭제 / `schemas/` / 미해결 좌표 5건 확정 /
Codex 등록(세 클라이언트 `IN_SYNC`) / Drive 스냅샷 `v3.0.0` 발행.

**미결 항목 0건.** 마지막 2건은 2026-08-23 사용자 결정으로 종결됐다.

- 레거시 `C:\AI-Tools`(224MB) — **지우지 않는다.** 사용 중이다(§5-45).
  ACL 은 잠겨 있고 비밀값도 없으므로 남아 있어도 위험하지 않다
- 중복 claude.ai Google 커넥터 — **그대로 둔다**(§9.1-6)

**둘 다 다시 제안하지 않는다.** 진단이 여전히 `legacy.cleanup:C:\AI-Tools` 를
`수동/선택` 단계로 내지만, 그것은 **이미 거절된 제안**이므로 그대로 넘긴다.

**즉 지금 해야 할 일이 없다.** 다음 세션은 §9 의 진단 3개를 돌려 상태만 확인하면 된다.

---

## 1. 좌표

| 항목 | 값 |
|---|---|
| 하네스 로컬 | `C:\AI-Harness` |
| 원격 | `https://github.com/hacker943410-debug/ai-harness` (**Private**) |
| 현재 HEAD | `6d56aba` + 이 커밋 (working tree clean, origin/main 동기) |
| 기준점 태그 | `v2.2.0` = `9e142bf` (롤백 지점) |
| 도구 루트 (Layer B) | `%LOCALAPPDATA%\AI-Tools` = `C:\Users\hacke\AppData\Local\AI-Tools` |
| 레거시 도구 루트 | `C:\AI-Tools` (**남겨 두기로 결정됨**, ACL 제한 완료, 비밀값 없음) |
| OAuth 프로필 | `%USERPROFILE%\.config\google-workspace-mcp\profiles\default` (도구 루트 **밖**) |

### 커밋 이력

```
6d56aba feat: 미해결 좌표 5건 확정 — 레지스트리 밖 출처를 발행자 대조로 확인
e739374 feat: schemas/ — 기계가 읽는 계약을 추가하고 매 검사에서 실제로 돌린다
b88f96c docs: HANDOFF — 레거시 경로 은퇴·래퍼 삭제 완료, 실측 사실 4건 추가
6bd881c refactor: v2.2 레거시 경로를 은퇴시킨다 — 새 경로를 만들고 옛 경로를 남기면 남은 쪽이 이긴다
1fc2961 docs: HANDOFF 를 세션 종료 상태로 정리
d5ce48d docs: HANDOFF — 레지스트리 해석 완료(조회 대상 0건)와 실측 사실 4건 추가
30f64a6 feat: 원격 서버를 좌표 확정으로 인정한다 — 미해석 조회 대상 0건
7cb95bd fix: 레지스트리 해석 — 검색 결과의 isLatest 를 믿지 않는다
b33cbf4 feat: 등록됨과 켜짐을 구분한다 — AGY 권장 완화 적용 후 판정이 실제로 바뀌게
80b1fb8 docs: HANDOFF — 제약 고지 설계 규칙과 스냅샷 스크립트 반영
4d9238c feat: 제약 고지 — 기술적으로 불가능한 것을 설치 시점에 선택지와 함께 제시
8c13719 docs: HANDOFF 자기모순 2건 수정 (결정 건수, clients.json 상태)
909c12f docs: HANDOFF — AGY 도구 통제 부재 확정, Drive 스냅샷 강등 반영
48df5dd M8: AGY 도구 통제 조사 완료(부재 확인), Drive 를 불변 스냅샷으로 강등
c299c13 docs: HANDOFF — 드리프트 해소 완료, 등록 경로 실측 사실 5건 추가
```

---

## 2. 설계 (변경 금지 — 이미 합의됨)

**3계층 분리.** 무엇을 / 어디에 / 어떤 ID를 절대 섞지 않는다.

| 계층 | 위치 | 담는 것 | git |
|---|---|---|---|
| A 하네스 | GitHub | 정책·카탈로그·**레시피**(무엇을, 어떤 버전) | ✅ |
| B 머신 | `AI-Tools` | **실체**(어디에 설치, 누구로 인증), 토큰 | ❌ |
| C 프로젝트 | `<proj>/.ai/` | **capability ID만** | ✅ |

**확장은 코드가 아니라 데이터.** 새 정책/MCP/런타임/클라이언트/플러그인 추가 시 스크립트를 고쳐야 하면 설계 실패.

**상태는 주장하지 않고 증명한다.** `installed ≠ registered ≠ authenticated ≠ verified`.

### Codex 교차검증에서 뒤집힌 결정 (그대로 유지)

- **D7**: Google MCP는 **user(공용) 등록 유지**. project scope 전환 안 함 → "어느 프로젝트에서든 바로 사용"이 원래 목표
- **D8**: **`read_only: false` 유지**(쓰기 필요). 위험은 범위가 아니라 `tool_policy`로 통제
- **D6**: GitHub 정본 + Drive는 스냅샷으로 강등

---

## 3. 완료된 것

| 단계 | 내용 |
|---|---|
| M0 | 중복 `client_secret*.json` 삭제 (해시 일치 확인 후) |
| M1 | `Initialize-GoogleWorkspaceMcp.ps1:56` 파스 오류 수정 |
| M2 | Codex 등록 (**나중에 외부 요인으로 소실됨** — §5 참고) |
| M3 | `git init` + `.gitignore`/`.gitattributes`/`.editorconfig`/`.githooks/pre-commit` + Private 원격 |
| M4 | `v2.2.0` 태그 |
| M5 | 도구 루트를 `%LOCALAPPDATA%\AI-Tools`로 이전 + ACL 제한, 3개 CLI 재등록, 실제 API로 검증 |
| M6 | `_Harness.Common.ps1`, 경로/인코딩 결함 일괄 수정, `Test-HarnessRepo.ps1`(7개 lint 규칙) |
| M7a | 런타임 매니페스트·클라이언트 디스크립터·5개 런타임 스크립트·환경 진단·설치 가이드 |
| M7b | 통합 적용(계획 파일 + 3-way diff + 롤백 저널), 클라이언트 정합, 인증 연결/해제, 카탈로그 `shared_runtime` 통합, 레지스트리 해석기, 검사기 확장, 수명주기 문서 |

### 지금 존재하는 파일 (Layer A)

```
runtimes/google-workspace.runtime.json   ← 버전 핀의 유일한 소스 (3.4.4). credentials.revoke 포함
runtimes/_TEMPLATE.runtime.json
settings/clients/{claude,codex,agy}.client.json

scripts/_Harness.Common.ps1              경로·인코딩·네이티브명령·ACL 헬퍼
scripts/_Harness.Runtime.ps1             매니페스트/인덱스/지문/argv + probe·3-way diff·
                                         실행중 세션·계획 단계 팩토리
scripts/Get-HarnessEnvironment.ps1       환경 진단 (읽기 전용). -SavePlan 으로 계획 파일 생성
scripts/Install-Harness.ps1              ★ 유일한 적용 경로. 계획 소비 + 확인 + 롤백 저널
scripts/Sync-HarnessClients.ps1          (런타임 x 클라이언트) 행렬. 읽기 전용 + 계획 생성
scripts/Resolve-HarnessRuntime.ps1       읽기 전용 해석
scripts/Install-HarnessRuntime.ps1       설치 / -Adopt 채택
scripts/Connect-HarnessRuntimeAuth.ps1   인증 연결 (자격증명 원본 위치 검사 포함)
scripts/Disconnect-HarnessRuntime.ps1    권한취소 -> 토큰삭제 -> 등록제거 -> state 되돌림
scripts/Register-HarnessRuntimeClient.ps1 등록 (되읽어 확인)
scripts/Test-HarnessRuntime.ps1          전송 검증 + 인증 검증 분리
scripts/Test-HarnessRepo.ps1             저장소 자체 검사 (11개 규칙군)
scripts/Resolve-HarnessMcpRegistry.ps1   registry_lookup 해석 (발행자 일치 강제)
scripts/Publish-HarnessSnapshot.ps1      Drive 불변 스냅샷 (추적 파일만, 라벨 1회)
scripts/harness-mcp-probe.mjs            MCP 프로브
scripts/harness-drive-snapshot.mjs       스냅샷 업로드 (런타임 디렉터리로 복사해 실행)

workflows/SHARED_RUNTIME.md              ★ 런타임 수명주기 (install->auth->verify->sync->restart)
workflows/HARNESS_INSTALL.md             PC 환경별 최초 설치 가이드
workflows/GOOGLE_WORKSPACE_SETUP.md      새 사용자 Google 로그인 가이드
proposals/HARNESS_V3_PROPOSAL.md         설계 근거 (v1.1)
```

### 변경 적용 경로 (이 구조를 깨지 말 것)

```
  Get-HarnessEnvironment.ps1  ─┐
                               ├─> 계획 파일(harness-change-plan v1.0) ─> Install-Harness.ps1
  Sync-HarnessClients.ps1     ─┘        (사용자가 enabled 편집 가능)          확인 -> 적용 -> 저널
```

계획을 만드는 스크립트는 여럿이어도 **적용하는 스크립트는 하나**다.
둘이 되는 순간 확인 절차를 우회하는 길이 생긴다.
단계의 스키마는 `_Harness.Runtime.ps1` 의 `New-HarnessPlanStep` 이 유일하게 정의한다.

### 제약 고지 (설계 규칙 — 사용자가 명시적으로 요구한 것)

**하네스가 강제할 수 없는 것은 최초 설치 시점에 선택지와 함께 제시한다.**
등록한 뒤에 뜨는 경고는 사용자가 *이미 노출된 상태에서* 읽는다. 그건 정보이지 선택이 아니다.

- 제약은 `settings/clients/<id>.client.json` 의 `limitations` 에 **데이터로** 선언한다.
  새 제약 추가에 스크립트를 고쳐야 하면 설계 실패다
- 각 제약은 `what` / `why`(확인된 근거) / `consequence` / `options` 를 갖는다
- **선택지 없는 고지는 통보다.** `options` 는 2개 이상, 각각 `how`(실행할 명령)와 `effect`,
  `recommended` 는 정확히 1개 — `Test-HarnessRepo.ps1` 이 강제한다
- `severity: high` 는 `Install-Harness.ps1` 이 `APPLY` 전에 `LIMITS` 동의를 따로 받는다.
  거부하면 아무것도 적용되지 않는다

---

## 4. 지금 이 PC의 실제 상태

```
runtimes.json : state=verified  installed=3.4.4  install_dir=google-workspace-mcp
                (레거시 디렉터리명을 -Adopt 로 채택한 상태)
clients.json  : agy / claude 2건 (tool_policy_enforceable 포함)

Sync-HarnessClients.ps1 결과 (2026-08-23 적용 후):
  google-workspace x agy     ok    꺼져 있음 (mcp disable — 권장 완화 적용)
  google-workspace x claude  ok
  google-workspace x codex   ok             (2026-08-23 등록. 이후 IN_SYNC)

Test-HarnessRuntime: transport_ok / tool_count=82 / auth_state=authorized / verified
clients.json 원장 생성됨 (agy, claude 2건)
```

**§4 드리프트 — 2026-08-23 해소.**
래퍼 `.cmd` 가 매니페스트에 없는 `contacts` 를 켜고 있었고 claude·agy 등록이 그것을 가리켰다.
지금은 둘 다 `.bin` shim + 명시적 env 를 가리키며 도구 수가 82개(6종)로 확인됐다.

**래퍼 삭제 — 2026-08-23 완료.** `google-workspace-mcp.cmd` / `google-workspace-auth.cmd` /
`sync-harness-to-drive.mjs` 삭제. 사본은 `<tools_root>\journal\retired-20260823\` 에 있다
(스크래치패드가 아니라 도구 루트에 둔다. 유일한 사본이 세션과 함께 사라지면 안 된다).
삭제 후 `Test-HarnessRuntime` 재실행: transport_ok / 82개 / authorized / verified.

**단, 그냥 지울 수 있는 상태가 아니었다.** 세 곳이 아직 래퍼를 가리키고 있었다
(§5-37). 그래서 레거시 경로를 먼저 은퇴시켰다:

- 삭제: `scripts/Initialize-GoogleWorkspaceMcp.ps1`, `scripts/Resolve-GoogleWorkspaceMcp.ps1`,
  `settings/google-workspace/{manifest.json,mcp-server.template.json}`
- 사용자 환경변수 `AI_HARNESS_GOOGLE_MCP_COMMAND` 삭제 (계획 → 확인 → 적용.
  저널 `<tools_root>\journal\install-20260823-104829Z.jsonl` 에 이전 값)
- 매니페스트에 `retired_locators` 를 추가해 **은퇴한 변수 이름을 데이터로 선언**한다.
  진단이 값이 남아 있으면 WARN 과 삭제 계획 단계를 낸다
- 옛 경로를 안내하던 문서 5곳(PROJECT_INIT §17.1 / GOOGLE_WORKSPACE_MCP /
  HARNESS_DOCTOR 38 / README / HARNESS_INSTALL §0·§8) 수정

적용은 순탄하지 않았다. 그 과정에서 등록 경로의 결함 4건이 드러났고(§5-24~27)
`87372cc` 에서 고쳤다. **claude 등록이 한 번 사라졌다가 복구됐다.**

**하네스 저장소 권한 (신규 발견, 2026-08-23 해결):**
`C:\AI-Harness` 자체가 `Authenticated Users [Modify]` 를 허용하고 있었다.
M5 에서 도구 루트 양쪽은 잠갔지만 정작 실행되는 `.ps1` 과 정책이 있는 곳은 열려 있었다.
지금은 `SYSTEM / Administrators / 소유자` FullControl 만 남았다.
이전 SDDL: `D:PAI(A;OICIIO;SDGXGWGR;;;AU)(A;;0x1301bf;;;AU)(A;OICI;FA;;;SY)(A;OICI;FA;;;BA)(A;OICI;0x1200a9;;;BU)`
(저널 `<tools_root>\journal\install-20260823-085210Z.jsonl`)

---

## 5. 재검증 없이 믿어도 되는 실측 사실

다음은 이 세션에서 **직접 실행해 확인**한 것이다. 다시 조사하지 말 것.

| # | 사실 |
|---|---|
| 1 | `npm`·`npx`·`claude`·`codex`는 PATH에서 **`.ps1`로 해석**된다. `.ps1`은 ExecutionPolicy 지배를 받아 Restricted에서 `PSSecurityException`. `npm.cmd`는 정상. → `Get-HarnessNativeCommand` 사용 |
| 2 | `[CmdletBinding()]`이 있으면 PS 5.1은 **param 기본값 평가 시 `$PSScriptRoot`가 빈 문자열**. 본문에서 기본값을 정해야 한다 |
| 3 | `Join-Path`는 2번째 인자를 재정규화하지 않고 **PSDrive를 해석**해 없는 드라이브에서 예외를 던진다. → `[IO.Path]::Combine` |
| 4 | PS 5.1의 `Set-Content -Encoding utf8`은 **BOM을 붙인다**. npm/`JSON.parse`가 거부 |
| 5 | PS 5.1은 BOM 없는 `.ps1`을 **ANSI(949)로 디코딩**한다. → 모든 `.ps1`은 UTF-8 BOM |
| 6 | `New-Item`은 **MAX_PATH 초과에도 성공한 것처럼 보인다**. `Test-Path`로 실제 확인 필요 |
| 7 | MCP SDK 1.26은 `listTools()` 후 `callTool()`에서 **outputSchema 검증**을 한다. 이 서버(3.4.4)는 텍스트만 반환 → 호출 순서를 바꿔 우회 |
| 8 | `get_status`는 **오류 상황도 성공한 도구 호출(`isError:false`)로 반환**한다. 검증 근거로 쓸 수 없다 |
| 9 | `CODEX_HOME`이 프로세스 범위로 재정의돼 있다 (orca 다계정 래퍼). **설정 파일 경로를 가정하면 안 된다** |
| 10 | **orca 래퍼가 `config.toml`을 재작성하며 `[mcp_servers]` 블록을 지웠다.** 14:54 등록 확인 → 16:15 소실. `.orca-managed-home` 마커 존재 |
| 11 | `C:\` 바로 아래 폴더는 `Authenticated Users: Modify`를 상속받는다 (M5에서 양쪽 다 제한 완료) |
| 12 | 토큰은 도구 루트 **밖**(`%USERPROFILE%\.config\`)에 있어 **루트 이동 시 재로그인 불필요** |
| 13 | `-WhatIf`는 `[IO.File]::WriteAllText`·`[Environment]::SetEnvironmentVariable`·네이티브 exe 호출을 **잡지 못한다** |
| 14 | Claude Code: bare deny(`mcp__srv`)만 컨텍스트를 줄인다. scoped deny는 실행만 차단. 프로젝트별 on/off는 `disabledMcpServers` |
| 15 | Codex: `disabled_tools`/`enabled_tools`는 **모델용 목록 생성 전에** 제거(컨텍스트 감소). `default_tools_approval_mode = "writes"` = 읽기 자유/쓰기 승인 |
| 16 | Gemini CLI: `excludeTools`/`includeTools`는 discovery 단계 제거. **AGY와는 별개 제품이고 설정 비호환**(`serverUrl` vs `httpUrl`) |
| 17 | 도구 수: services 7종 = 88개 → 6종(contacts 제외) = **82개** |
| 18 | claude.ai 내장 Gmail/Drive/Calendar 커넥터와 `google-workspace`가 **동시 연결** 중이며 이름이 같은 도구 15개가 서로 다른 계정으로 공존 |
| 19 | **MCP 공식 레지스트리 검색은 타이포스쿼트를 먼저 준다.** `search=chrome-devtools` 결과 1등이 `io.github.Async23/chrome-devtools-mcp@1.7.0`(2026-08-16 등록), 진짜 `io.github.ChromeDevTools/chrome-devtools-mcp` 는 2등. **검색 1등을 그대로 핀하면 안 된다.** 레지스트리 이름의 소유자 구간이 카탈로그 `publisher` 와 일치할 때만 인정한다 |
| 20 | `C:\AI-Harness` 자체가 `Authenticated Users [Modify]` 를 상속받고 있다 (§5-11 과 같은 원인, 하네스 루트는 M5 에서 빠졌음) |
| 21 | 카탈로그 `registry_lookup` 53건 중 **34건은 `discovery_only` 이고 `publisher` 가 비어 있다.** 정책상 설치 불가 항목이므로 좌표 확정 대상이 아니다. 실제 대상은 19건 |
| 22 | `tokens.json` 은 평면 Google OAuth 토큰 객체다 (`access_token` / `refresh_token` / `expiry_date` / `token_type` / `scope` / `created_at` / `refresh_token_expires_in`). `refresh_token` 을 `https://oauth2.googleapis.com/revoke` 로 취소하면 부여 전체가 취소된다 |
| 23 | `[Environment]::UserInteractive` 로 비대화형을 감지할 수 있다. 대화형 확인을 받을 수 없는 세션에서 조용히 적용하는 것을 막는 데 쓴다 |
| 24 | **claude 의 `-e` 는 commander 가변 인자(`<env...>`)다.** 뒤따르는 토큰을 계속 먹어서 `-e A=1 <이름> --` 순서면 이름까지 환경변수로 삼킨다(`Invalid environment variable format: google-workspace`). **`{server_name}` 이 `{env_flags}` 앞에 와야 하고 `--` 로 끊어야 한다.** codex 의 `--env <KEY=VALUE>` 는 값 1개만 받아 해당 없음(help 확인) |
| 25 | **네이티브 명령의 stderr 를 `2>&1` 로 합치면 PS 5.1 은 각 줄을 ErrorRecord 로 감싼다.** 호출자의 `ErrorActionPreference='Stop'` 이면 그 자리에서 죽는다. "그런 서버 없다"는 조회의 정상 답인데 예외가 됐고, 그래서 **이미 등록된 경우에만 동작하는 등록 스크립트**였다. 네이티브 호출을 감싸는 함수에서 함수 스코프로 `Continue` 를 건다 |
| 26 | claude 는 환경변수를 `Environment:` **다음 줄들에 들여쓰기로** 출력한다. 그 줄의 꼬리만 읽으면 항상 비어 보여 선언한 키가 전부 ADD 로 나오고, **올바르게 등록해도 드리프트가 사라지지 않는다** |
| 27 | agy 의 `mcp list` 는 명령과 인자를 **한 칸에 붙여서** 준다(`...\x.cmd start`). 마지막 칸을 통째로 command 로 쓰면 영원히 CHANGE 다. 경로에 공백이 있을 수 있으므로 **"실제로 존재하는 가장 긴 접두사"** 를 명령으로 본다 |
| 28 | upsert 가 아닌 클라이언트의 재등록은 remove -> add 다. **add 가 실패하면 고치려던 등록이 아예 없어진다.** 실제로 claude 에서 일어났다. 지금은 실패 시 이전 등록을 복원하고 `restored` / `restore_failed` 를 보고한다 |
| 29 | **AGY 는 도구 단위 통제 수단이 없다** (2026-08-23 확인). `agy --help` 의 도구 관련 플래그는 `--dangerously-skip-permissions`(전부 자동 승인) 하나뿐, `mcp_config.json` 은 서버별 `command/args/env/disabled` 만, `antigravity-cli/settings.json` 에는 도구 정책 키가 없다(`trustedWorkspaces` 뿐). 통제 단위는 `agy mcp disable <name>` 뿐. **risk=high 런타임의 deny 목록이 AGY 에서는 강제되지 않는다** |
| 30 | Drive `create_file` 은 **이름으로 형식을 추론한다**. `type` 을 안 주면 `.md` 가 Google Docs 로 변환되어 원본이 아니게 된다. 스냅샷은 항상 `type: "text"` 로 올린다. `parentPath` 는 필요한 폴더를 알아서 만든다 |
| 31 | Drive 는 **한 폴더에 동명 파일을 허용한다.** update 실패 시 create 로 폴백하는 코드는 일시적 실패 한 번에 조용히 중복 파일을 만든다 |
| 32 | **등록돼 있다 ≠ 켜져 있다.** `agy mcp disable` 로 끈 서버도 `mcp list` 에는 남고 `STATUS` 칸만 `disabled` 가 된다. 이 구분을 안 보면 완화를 적용해도 진단이 같은 경고를 계속 내고, 사용자는 경고를 무시하도록 훈련된다. 상태 칸은 **위치가 아니라 선언된 표식(`disabled_markers`)으로 찾는다** — 열 순서가 바뀌면 조용히 틀리기 때문 |
| 33 | **레지스트리 검색의 `isLatest` 는 사실이 아니다.** 페이지가 잘리고 정렬도 보장되지 않는다. 실측: `search=chrome-devtools&limit=20` 결과 20건 중 19건이 ChromeDevTools 항목인데 `isLatest=true` 가 하나도 없었다(진짜 최신은 1.7.0). **검색은 이름만 고르는 데 쓰고, 버전·패키지는 `GET /v0/servers/{name}/versions/latest` 정본에서 받는다** (이름의 `/` 는 `%2F`) |
| 34 | 레지스트리 검색은 **표시 이름과 매칭되지 않는다.** `"Chrome DevTools MCP"` → 0건, `"chrome-devtools"` → 5건. 카탈로그의 `query` 는 사람이 읽는 이름이므로 `id` / `id-mcp` / 슬러그도 함께 던져야 한다 |
| 35 | 사칭 항목이 **진짜와 같은 버전 번호를 쓴다.** `io.github.Async23/chrome-devtools-mcp` 와 진짜가 둘 다 `1.7.0`. 버전·이름·최신 여부 무엇으로도 구분할 수 없고 **발행자 대조만이 방어다** |
| 36 | 원격 서버는 `packages` 가 비어 있고 `remotes` 에 URL 이 있다. `packages` 배열이 존재해도 `identifier` 가 비어 있을 수 있으므로 **존재가 아니라 값으로 판정한다.** 패키지 없음은 결함이 아니라 원격 서버의 정상 형태다 |
| 37 | **"아무도 안 가리킨다"는 등록만 본 판정이었다.** 래퍼 `.cmd` 를 지우기 직전에 확인해 보니 셋이 가리키고 있었다. ① 사용자 환경변수 `AI_HARNESS_GOOGLE_MCP_COMMAND` ② `Initialize-GoogleWorkspaceMcp.ps1` — 래퍼가 없으면 **다시 만들고**, 그 내용이 `GOOGLE_WORKSPACE_SERVICES=...,contacts` 이며, 만든 뒤 ①을 거기로 다시 박는다 ③ `Resolve-GoogleWorkspaceMcp.ps1` + `settings/google-workspace/manifest.json`. **새 경로를 만들고 옛 경로를 남기면 남은 쪽이 조용히 이긴다.** 대체됐다고 판단한 파일은 그때 지운다 |
| 38 | **v3 진단은 은퇴한 환경변수를 보지 않았다.** 아무도 읽지 않는 값이라 무해해 보이지만, 남아 있으면 사람과 되살아난 옛 스크립트가 그것을 정답으로 믿는다. 지금은 매니페스트 `retired_locators.environment_variables` 가 이름을 선언하고 진단이 찾아 삭제를 제안한다. **스크립트에 변수 이름을 박지 않는다** — 박으면 런타임 추가가 코드 수정이 된다 |
| 39 | `Install-Harness.ps1` 의 `env-set` 은 `payload.value = null` 로 **삭제**를 표현할 수 있다. JSON 왕복·사후 확인·롤백(이전 값 복원)이 모두 그대로 동작한다. 새 단계 종류를 만들 필요가 없었다 |
| 40 | **PS 5.1 의 `Get-Content -Raw` 는 BOM 없는 UTF-8 을 ANSI(949)로 읽는다.** 계획 파일(BOM 없는 UTF-8)을 그렇게 읽으면 한글이 깨지면서 따옴표까지 망가져 `ConvertFrom-Json` 이 실패한다. 파일은 멀쩡한데 읽기가 틀린 것이다. `-Encoding UTF8` 을 주거나 하네스의 `Read-HarnessJson` 을 쓴다 |
| 41 | **계획 파일 생산자가 둘인데 모양이 달랐다.** 스키마를 쓰다 발견했다. `Get-HarnessEnvironment` 는 계획 객체를 손으로 조립하며 `limitations` 를 넣었고, 팩토리 `New-HarnessChangePlan`(Sync 가 쓰는 것)에는 그 필드가 없었다. `overall` 어휘도 달랐다(READY/… vs IN_SYNC/…). 소비자가 `overall` 을 읽지 않아서 아무도 몰랐다. 지금은 팩토리가 유일한 정의이고 둘 다 그것을 쓴다. **적용자가 하나여도 생산자가 여럿이면 형식은 갈라진다** |
| 42 | **레지스트리 밖 좌표는 발행자 대조로만 확정할 수 있다.** npm 패키지가 선언한 `repository`, PyPI 의 `project_urls.Source`, OpenUPM 의 저장소가 각각 근거가 된다. `unity` 를 찾다가 PyPI 에서 `unity-mcp-server` 를 만났는데 **발행자가 다르다(mzbswh vs CoplayDev)**. 이름만 보고 골랐으면 그것을 집었을 것이다 |
| 43 | **codex 의 `--env`-먼저 argv 순서가 실제로 통했다.** §5-24 는 help 로만 확인한 상태였다. 실제 등록 후 되읽어 확인했고, 세 클라이언트가 처음으로 `IN_SYNC` 가 됐다. 다만 orca 가 설정을 소유하므로 지워질 수 있다(§5-10) — 작업 시작 시 정합 확인이 필요하다 |
| 44 | **프리릴리스 판정이 SemVer 하이픈만 봤다.** PEP 440 은 하이픈 없이 붙여 쓴다(`0.0.1a4`, `1.0b2`, `2.0rc1`). `markitdown` 의 알파가 실제로 조용히 통과했다. 규칙을 넓혔다 |
| 45 | **`agy mcp disable` 는 이미 떠 있는 세션에 아무 영향이 없다.** 레거시 경로 `C:\AI-Tools` 에서 **옛 래퍼(=`contacts` 포함 7종)로 뜬 MCP 서버가 아직 살아 있다** (cmd pid 24412 -> node pid 24112). 부모는 `--dangerously-skip-permissions` 로 뜬 agy 세션(pid 5996, Orca 터미널). 즉 "꺼 뒀다"는 **새 세션에 대한 이야기**이며, 그 세션이 살아 있는 동안 도구 통제 없는 노출이 계속된다. 이것 때문에 레거시 루트를 지울 수도 없다. **완화를 적용했으면 이미 떠 있는 세션도 세어야 한다** |

---

## 6. 남은 작업 (우선순위 순)

### M7b — 완료 (2026-08-23)

1~6 모두 구현·검증됨. 요약은 §3, 파일 목록은 §3 하단, 구조는 "변경 적용 경로" 참고.
남은 것은 **적용 결정**이지 구현이 아니다 (§7).

### M8 이후 (우선순위 순)

1. ~~§4 드리프트 적용~~ — 2026-08-23 완료. agy·claude 모두 `ok`
2. ~~하네스 저장소 ACL 제한~~ — 2026-08-23 적용 완료
3. ~~레지스트리 확정 8건 반영~~ — 2026-08-23 반영 완료. `registry_lookup` 53 → 45 건
3b. ~~래퍼 `.cmd` 삭제~~ — **2026-08-23 완료.** 다만 그냥 지울 수 없었다.
   레거시 경로(스크립트 2개 + settings + 환경변수)를 먼저 은퇴시켜야 했다. §4 와 §5-37 참고
4. ~~카탈로그 registry_lookup 해석~~ — **완료. 조회할 것이 0건이다.**
   `registry_lookup` 53 → 39 이고 그 39건은 전부 조회 대상이 아니다
   (35건 `discovery_only`, 4건 `registry_absent` 기록됨).
   확정된 좌표: npm 13 / remote 4 / oci 1 / pypi 1 / nuget 1, 모두 provenance 포함.
   **판단도 2026-08-23 끝났다:**
   - `azure` — 프리릴리스 `3.0.0-beta.37` 대신 NuGet 의 최신 **안정** 버전 `2.0.5` 로 내렸다
   - `notion` / `azure-devops` / `markitdown` / `unity` — 레지스트리 밖 출처에서 찾아 넣었다.
     근거는 각 항목의 `provenance` 에 있다 (npm `repository` / PyPI `project_urls.Source` / OpenUPM)
   - `markitdown` 은 상류에 정식 릴리스가 없어 알파(`0.0.1a4`)를 쓴다. 검사기가 WARN 을 내는 것이 맞다
   - `searxng` 는 발행자를 특정할 수 없어 `discovery_only` 로 내렸다
   - 남은 `registry_lookup` 35건은 전부 `discovery_only` 다. **미해결 좌표 0건.**
5. 중복 claude.ai Google 커넥터 정리 (D11) — **조사 완료.** 겹치는 도구 15개 확정, 선택만 남음 (§9.1)
6. ~~Drive 스냅샷 강등~~ — **완료. 2026-08-23 첫 발행까지 끝났다.**
   `/AI-Harness-snapshots/v3.0.0` 에 79개 + `SNAPSHOT.json`, never_sync 위반 0.
   폴더는 **불변**이며 갱신되지 않는다. 다음 스냅샷은 새 라벨로 만든다.
   구 `sync-harness-to-drive.mjs` 는 **삭제됐다** (2026-08-23, §M8-3b)
7. ~~`schemas/` 추가~~ — **2026-08-23 완료.** runtime-manifest / runtime-index /
   client-descriptor / client-index / change-plan (+ 기존 capability-lock).
   `scripts/harness-schema-validate.mjs` 는 **의존성 0** 이다(ajv 를 넣으면 "먼저 npm install"
   이 되고 아무도 안 돌린다). `Test-HarnessRepo.ps1` 이 Layer A 를 매번 검증하고,
   node 가 없으면 통과가 아니라 `SCHEMA_UNCHECKED`(UNENFORCED) 로 보고한다.
   Layer B·계획 파일은 저장소 밖이라 손으로 돌린다 — 방법은 `schemas/README.md`
8. ~~레거시 `C:\AI-Tools` 삭제~~ — **2026-08-23 결정: 지우지 않는다.** 사용 중이다.
   진단은 계속 `manual/선택` 단계로 제시하지만 이미 거절된 제안이다
9. `POLICY_INDEX.compat.json` (기계가 읽는 계약은 YAML 금지 — PS 5.1에 파서 없음)
10. ~~AGY 도구 통제 메커니즘 검증~~ — **조사 완료. 수단이 없다**(§5-29). 남은 것은 조사가 아니라 결정(§7-7)
11. (선택) `.claude-plugin/marketplace.json`

---

## 7. 사용자 확인이 필요한 미결 사항

| # | 내용 | 준비 상태 |
|---|---|---|
| ~~1~~ | ~~claude / agy 등록 드리프트~~ | **2026-08-23 적용 완료.** 둘 다 `ok`. 재시작 반영도 확인됨(claude 에 `contacts` 없음, 82개) |
| ~~2~~ | ~~Codex 등록~~ | **2026-08-23 완료.** argv 순서가 실제로 통했다(§5-43). `codex mcp get` 으로 되읽어 확인. **orca 가 설정을 소유하므로 지워질 수 있다 — 작업 시작 시 `Sync-HarnessClients.ps1` 로 확인할 것** |
| ~~3~~ | ~~하네스 저장소 ACL 제한~~ | **2026-08-23 적용 완료.** 저널 `install-20260823-085210Z.jsonl` 에 이전 SDDL |
| ~~4~~ | ~~레지스트리 확정 8건 카탈로그 반영~~ | **2026-08-23 반영 완료** (`f775743`) |
| ~~5~~ | ~~AGY 도구 통제 메커니즘 검증~~ | **2026-08-23 조사 완료. 수단 없음**(§5-29) |
| ~~6~~ | ~~레거시 `C:\AI-Tools` 삭제 시점~~ | **2026-08-23 결정: 지우지 않는다.** 사용 중이다 |
| ~~7~~ | ~~AGY 에 google-workspace 를 계속 둘 것인가~~ | **2026-08-23 권장안 적용.** `agy mcp disable google-workspace` 실행 완료(`mcp list` STATUS=disabled, `mcp_config.json` disabled=true 로 되읽어 확인). 진단이 `OK 차단 불가 — 꺼 둠` 으로 바뀌었다. **쓸 때만 `agy mcp enable google-workspace`, 끝나면 다시 끈다** |
| ~~8~~ | ~~Drive 스냅샷 첫 발행~~ | **2026-08-23 완료.** `/AI-Harness-snapshots/v3.0.0` 에 80개. 되읽어 확인. 불변이라 다음은 새 라벨 |

---

## 8. 작업 규칙 (이 사용자에게 확인된 것)

1. **살아있는 도구 설정(AI CLI MCP 등록, 사용자 환경변수, 공용 도구 루트)은 확인 없이 바꾸지 않는다.**
   진단(읽기 전용) → 무엇이 어떻게 바뀌는지 제시 → 확인 → 적용.
   실제로 한 번 거부당한 적이 있다. 문제는 명령이 아니라 *확인 없이 건드린 것*이었다.
2. 검증은 **파일 존재나 exit code가 아니라 실제 동작**으로 한다.
3. 실행하지 않은 것을 "완료"라고 보고하지 않는다. AST 파싱은 실행이 아니다.
4. 커밋 메시지는 **파일로 넘긴다** (`git commit -F`). PS 5.1은 큰따옴표가 든 인자를 네이티브 명령에 넘길 때 깨진다.
   **그 파일을 `Out-File -Encoding utf8` 로 쓰지 말 것.** 5.1 은 BOM 을 붙이고(§5-4),
   git 은 그것을 제목 첫 글자로 삼는다. 실제로 커밋 `de69893` 의 제목이 그렇게 됐다.
   BOM 없이 쓰는 수단(에디터·`[IO.File]::WriteAllText`·`Write-HarnessText`)을 쓴다.
5. 새 `.ps1`을 추가하면 **UTF-8 BOM 적용 후** `Test-HarnessRepo.ps1`을 돌린다.

---

## 9. 이어서 시작하는 법

```powershell
# 1. 저장소 계약 (11개 규칙군)
powershell -NoProfile -ExecutionPolicy Bypass -File 'C:\AI-Harness\scripts\Test-HarnessRepo.ps1'

# 2. 이 PC 상태 — 읽기 전용. 아무것도 바꾸지 않는다
powershell -NoProfile -ExecutionPolicy Bypass -File 'C:\AI-Harness\scripts\Get-HarnessEnvironment.ps1'
powershell -NoProfile -ExecutionPolicy Bypass -File 'C:\AI-Harness\scripts\Sync-HarnessClients.ps1'
powershell -NoProfile -ExecutionPolicy Bypass -File 'C:\AI-Harness\scripts\Resolve-HarnessRuntime.ps1' -All

# 3. git 상태
git -C C:\AI-Harness log --oneline -5
git -C C:\AI-Harness status --short
```

**바꾸기 전에는 반드시 계획 파일을 거친다.** 위 진단 명령 중 어느 것도 아무것도 바꾸지 않는다.

```powershell
powershell ... -File '...\Sync-HarnessClients.ps1'  -SavePlan .\plan.json    # 1) 계획
notepad .\plan.json                                                          # 2) enabled 편집
powershell ... -File '...\Install-Harness.ps1' -Plan .\plan.json -DryRun     # 3) 실행될 명령 확인
powershell ... -File '...\Install-Harness.ps1' -Plan .\plan.json             # 4) 확인 후 적용
powershell ... -File '...\Install-Harness.ps1' -Rollback <저널경로>           # 되돌리기
```

다음 세션 첫 지시 예시:

> `C:\AI-Harness\proposals\HANDOFF.md` 를 읽고 §9.1 부터 이어서 진행해줘.

---

## 9.1 다음에 바로 할 수 있는 일 (우선순위 순)

구현이 막힌 것은 없다. 아래는 전부 **결정하면 바로 실행되는** 것들이다.

| # | 할 일 | 명령 | 성격 |
|---|---|---|---|
| ~~1~~ | ~~Drive 스냅샷 첫 발행~~ | — | **2026-08-23 완료.** `/AI-Harness-snapshots/v3.0.0` 에 80개(SNAPSHOT.json 포함). 되읽어 확인함. 불변이므로 다음은 새 라벨로 |
| ~~2~~ | ~~래퍼 정리~~ | — | **2026-08-23 완료** (§4) |
| ~~3~~ | ~~Codex 등록~~ | — | **2026-08-23 완료.** 되읽어 확인. 세 클라이언트가 처음으로 `IN_SYNC` (§5-43) |
| ~~4~~ | ~~azure 프리릴리스 결정~~ | — | **2026-08-23 완료.** 안정 버전 `2.0.5` 로 내림 |
| ~~5~~ | ~~`schemas/` 추가~~ | — | **2026-08-23 완료** (§6-7) |
| ~~6~~ | ~~중복 claude.ai Google 커넥터 정리 (D11)~~ | — | **2026-08-23 결정: 그대로 둔다.** 조사는 끝났고 사용자가 현 상태를 알고 유지하기로 했다. 다시 묻지 말 것 — 아래 표는 근거로 남긴다 |
| ~~7~~ | ~~레거시 `C:\AI-Tools` 삭제~~ | — | **2026-08-23 결정: 지우지 않는다.** 사용 중이다(§5-45). 다시 제안하지 말 것 |
| ~~8~~ | ~~`notion` / `azure-devops` / `markitdown` / `unity` 좌표~~ | — | **2026-08-23 완료** (§5-42) |

### 6번 — 이름이 겹치는 도구 15개 (2026-08-23 실측)

`claude.ai` 내장 커넥터와 로컬 `google-workspace` 가 **같은 이름의 도구**를 갖는다.
두 경로는 서로 다른 Google 계정에 연결돼 있다(§5-18).

| 영역 | 겹치는 이름 |
|---|---|
| 캘린더 (6) | `list_calendars` `list_events` `get_event` `create_event` `update_event` `delete_event` |
| 드라이브 (5) | `copy_file` `create_file` `update_file` `get_file_metadata` `share_file` |
| Gmail (4) | `list_drafts` `list_labels` `update_label` `delete_label` |

문제는 두 가지다.
**첫째, 어느 계정에 쓰는지가 이름으로 구분되지 않는다.** `create_event` 는 두 곳에 있다.
**둘째, 한쪽만 끄면 껐다고 착각한다.** 로컬 서버를 꺼도 claude.ai 커넥터는 그대로 살아 있다.

**결정 (2026-08-23): 그대로 둔다.** 사용자가 위 두 가지를 알고 현 상태를 유지하기로 했다.
따라서 이것은 미결 항목이 아니다. 다시 제안하지 않는다.

그래도 되살아날 수 있는 선택지는 남겨 둔다:
- **Claude Code 에서만 claude.ai 커넥터를 끈다** — `/mcp` 토글.
  claude.ai 웹·모바일에서는 그대로 쓰고, 터미널에서는 로컬 하나만 남는다. 토큰도 줄어든다
- **claude.ai 쪽 커넥터를 계정에서 해제한다** — 가장 확실하지만 웹·모바일에서도 없어진다

**이 상태에서 Google 관련 작업을 할 때는 어느 쪽 도구를 쓰는지 이름 앞의 서버로 확인한다.**
`mcp__google-workspace__create_event` 와 `mcp__claude_ai_Google_Calendar__create_event` 는
다른 계정에 쓴다.

### 재시작 — 2026-08-23 확인됨

claude 세션에 `contacts` 도구가 없다(6종 82개). 새 등록으로 동작한다.
정합도 `agy ok(꺼짐) / claude ok` 그대로다. codex 는 미등록이며 이는 미결정 항목(§7-2)이다.

### 이 세션에서 배운 것 중 다음 작업에 바로 걸리는 것

- 살아있는 등록을 바꿀 때는 실패가 **등록을 지운 채로 끝날 수 있다**(§5-28). 지금은 복원하지만
  복원도 실패할 수 있으니 `restored` / `restore_failed` 출력을 반드시 읽을 것
- 네이티브 CLI 를 호출하는 새 코드를 쓸 때 `2>&1` + `ErrorActionPreference='Stop'` 조합을
  조심할 것(§5-25). 함수 스코프로 `Continue` 를 걸어야 한다
- 새 `.ps1` 은 **UTF-8 BOM** 으로 저장하고 `Test-HarnessRepo.ps1` 을 돌릴 것
- **"대체됐다"고 판단한 파일은 그때 지운다.** 남겨 두면 지우려는 것을 다시 만들어 놓는다(§5-37).
  옛 경로를 안내하는 문서도 같이 고친다 — 문서가 남아 있으면 사람이 그 경로를 되살린다
- 계획 파일을 PS 에서 읽을 때 `Get-Content -Raw` 를 그냥 쓰지 말 것(§5-40)

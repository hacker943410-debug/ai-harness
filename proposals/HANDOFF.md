# AI Harness v3 마이그레이션 — 인수인계

작성: 2026-08-23
용도: 세션이 끊긴 뒤 **다음 세션이 이 문서만 읽고 이어서 작업**할 수 있게 한다.
읽는 순서: 이 문서 → `proposals/HARNESS_V3_PROPOSAL.md`(설계 근거) → 필요한 코드

---

## 0. 한 문장 요약

`C:\AI-Harness`(AI Harness 2.2)를 **GitHub에서 받아 어느 PC에서든 설치·사용할 수 있는 3계층 구조**로 재편하는 중이다.
M0~M6 완료, **M7 전반부 완료**, 후반부(통합 적용 스크립트·카탈로그 통합) 남음.

---

## 1. 좌표

| 항목 | 값 |
|---|---|
| 하네스 로컬 | `C:\AI-Harness` |
| 원격 | `https://github.com/hacker943410-debug/ai-harness` (**Private**) |
| 현재 HEAD | `4bab32b` (working tree clean, origin/main 과 동기) |
| 기준점 태그 | `v2.2.0` = `9e142bf` (롤백 지점) |
| 도구 루트 (Layer B) | `%LOCALAPPDATA%\AI-Tools` = `C:\Users\hacke\AppData\Local\AI-Tools` |
| 레거시 도구 루트 | `C:\AI-Tools` (**아직 존재**, ACL은 제한 완료, 삭제 대기) |
| OAuth 프로필 | `%USERPROFILE%\.config\google-workspace-mcp\profiles\default` (도구 루트 **밖**) |

### 커밋 이력

```
4bab32b  docs: PC 환경별 최초 설치 가이드 추가
e5af9c3  M7(1/2): 공용 런타임 계층 + 설치 전 환경 진단
75d0e46  M6: 공통 헬퍼 도입, 경로/인코딩 결함 일괄 수정, 저장소 자체 검사기 추가
321f1b4  M5: 공용 도구 루트를 %LOCALAPPDATA%\AI-Tools 로 이전하고 ACL 을 제한
3870325  proposal: 클라이언트 디스크립터에 config_path_is_authoritative 규칙 추가
26f3cd4  docs: 새 사용자용 Google Workspace 로그인 가이드 추가
9e142bf  (tag: v2.2.0) baseline: AI Harness 2.2 into version control
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

### 지금 존재하는 파일 (Layer A)

```
runtimes/google-workspace.runtime.json   ← 버전 핀의 유일한 소스 (3.4.4)
runtimes/_TEMPLATE.runtime.json
settings/clients/{claude,codex,agy}.client.json
scripts/_Harness.Common.ps1              경로·인코딩·네이티브명령·ACL 헬퍼
scripts/_Harness.Runtime.ps1             매니페스트/인덱스/지문/argv 전개
scripts/Get-HarnessEnvironment.ps1       설치 전 환경 진단 (읽기 전용)
scripts/Resolve-HarnessRuntime.ps1       읽기 전용 해석
scripts/Install-HarnessRuntime.ps1       설치 / -Adopt 채택
scripts/Register-HarnessRuntimeClient.ps1 등록 (되읽어 확인)
scripts/Test-HarnessRuntime.ps1          전송 검증 + 인증 검증 분리
scripts/Test-HarnessRepo.ps1             저장소 자체 검사
scripts/harness-mcp-probe.mjs            MCP 프로브
workflows/HARNESS_INSTALL.md             PC 환경별 최초 설치 가이드
workflows/GOOGLE_WORKSPACE_SETUP.md      새 사용자 Google 로그인 가이드
proposals/HARNESS_V3_PROPOSAL.md         설계 근거 (v1.1)
```

---

## 4. 지금 이 PC의 실제 상태

```
runtimes.json : state=verified  installed=3.4.4  install_dir=google-workspace-mcp
                (레거시 디렉터리명을 -Adopt 로 채택한 상태)
clients.json  : 아직 없음 (Register 를 실행하지 않았으므로)

claude  mcp get google-workspace  → exit 0  (등록됨, 래퍼 .cmd 를 가리킴)
codex   mcp get google-workspace  → exit 1  (미등록)
agy     mcp list                  → 등록됨
```

**드리프트 1건 (미해결):** 매니페스트는 `services = drive,gmail,calendar,docs,sheets,slides`인데
`%LOCALAPPDATA%\AI-Tools\google-workspace-mcp\google-workspace-mcp.cmd` 래퍼는 `...,contacts`를 설정한다.
현재 등록은 그 래퍼를 가리키므로 **실제로는 contacts가 켜져 있다**. M7 후반부에서 래퍼를 없애고
`.bin` shim + 명시적 env로 재등록하면 해소된다.

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

---

## 6. 남은 작업 (우선순위 순)

### M7b — 통합 적용 + 카탈로그 통합

1. **`scripts/Install-Harness.ps1`**
   - `-WhatIf`에 의존하지 말 것 (§5-13). **명시적 변경 계획 객체**를 만들어 렌더링
     `{kind: env-set|file-write|dir-create|acl-set|exec, target, old, new, command_line}`
   - 진단이 낸 계획 파일을 **인자로 받아** 소비 (재탐지로 사용자 편집을 무시하면 안 됨)
   - **롤백 저널**: 각 변경 직전에 이전 상태를 append-only로 기록 → `-Rollback <journal>`
   - 단계 간 **의존성**: 선행 단계를 거부하면 종속 단계는 아예 제시하지 않음
   - 적용 직전 **실행 중 CLI 세션 재확인** 후 거부
   - **3-way diff**(선언 vs 매니페스트 vs 실제)로 ADD/CHANGE/**REMOVE** 표시. REMOVE는 별도 확인
2. **`scripts/Sync-HarnessClients.ps1`** — (런타임 × 클라이언트) 정합
3. **`scripts/Connect-HarnessRuntimeAuth.ps1`** / **`Disconnect-HarnessRuntime.ps1`**
   - Connect: 소스가 git 워크트리 안/tools_root 안/그룹쓰기 가능이면 거부
   - Disconnect: Google 권한 취소 → 토큰 삭제 → 클라이언트 등록 제거 → state 되돌림
4. **카탈로그 통합**
   - `catalogs/mcp-catalog.json`의 `google-workspace-local` → `install.kind: "shared_runtime"`, `runtime_id`, `manifest` (package/version **제거**)
   - `policy`에 `shared_runtime_requires_manifest` / `shared_runtime_dir` / `shared_runtime_version_source`
   - `Install-ProjectMcp.ps1`에 `shared_runtime` 가드 (프로젝트별 설치 거부)
   - `registry_lookup` 53건 → MCP 공식 레지스트리 API로 해석
     `GET https://registry.modelcontextprotocol.io/v0.1/servers/{name}/versions/latest` (이름의 `/`는 `%2F`)
5. **`workflows/SHARED_RUNTIME.md`** — 런타임 수명주기 (install → auth → verify → sync 순서 명시. 인증 변경 시 클라이언트 재시작 필요)
6. **`Test-HarnessRepo.ps1` 확장** — 매니페스트 스키마, Layer A 절대경로 금지, never_sync 단일 소스

### M8 이후

7. 래퍼 `.cmd` 제거 → `.bin` shim + 명시적 env로 재등록 (§4 드리프트 해소)
8. 중복 claude.ai Google 커넥터 정리 (D11)
9. Drive를 `/AI-Harness-snapshots/v3.0.0/` 스냅샷으로 강등 + `sync-harness-to-drive.mjs` 처리
   (현재 삭제 패스 없음, 제외 목록 하드코딩, update 실패 시 create 폴백으로 동명 파일 생성)
10. `schemas/` 추가: runtime-manifest / runtime-index / client-descriptor / never-sync.generated
11. 레거시 `C:\AI-Tools` 삭제 (모든 CLI 재시작 후)
12. `POLICY_INDEX.compat.json` (기계가 읽는 계약은 YAML 금지 — PS 5.1에 파서 없음)
13. (선택) `.claude-plugin/marketplace.json`

---

## 7. 사용자 확인이 필요한 미결 사항

| # | 내용 |
|---|---|
| 1 | **Codex 재등록** — 지금 미등록 상태. 다만 orca가 설정을 소유해 다시 지워질 수 있음(§5-10). `risk: high` 등록이므로 `-IAcceptRisk` 필요. **사용자 확인 후 진행할 것** |
| 2 | **AGY 도구 통제 메커니즘** — 미검증. Gemini CLI의 `excludeTools`를 적용하면 안 됨 |
| 3 | 래퍼 제거 시점 — 살아있는 CLI 등록을 바꾸는 작업이라 확인 필요 |
| 4 | 레거시 `C:\AI-Tools` 삭제 시점 |

---

## 8. 작업 규칙 (이 사용자에게 확인된 것)

1. **살아있는 도구 설정(AI CLI MCP 등록, 사용자 환경변수, 공용 도구 루트)은 확인 없이 바꾸지 않는다.**
   진단(읽기 전용) → 무엇이 어떻게 바뀌는지 제시 → 확인 → 적용.
   실제로 한 번 거부당한 적이 있다. 문제는 명령이 아니라 *확인 없이 건드린 것*이었다.
2. 검증은 **파일 존재나 exit code가 아니라 실제 동작**으로 한다.
3. 실행하지 않은 것을 "완료"라고 보고하지 않는다. AST 파싱은 실행이 아니다.
4. 커밋 메시지는 **파일로 넘긴다** (`git commit -F`). PS 5.1은 큰따옴표가 든 인자를 네이티브 명령에 넘길 때 깨진다.
5. 새 `.ps1`을 추가하면 **UTF-8 BOM 적용 후** `Test-HarnessRepo.ps1`을 돌린다.

---

## 9. 이어서 시작하는 법

```powershell
# 1. 현재 상태 확인
powershell -NoProfile -ExecutionPolicy Bypass -File 'C:\AI-Harness\scripts\Get-HarnessEnvironment.ps1'
powershell -NoProfile -ExecutionPolicy Bypass -File 'C:\AI-Harness\scripts\Test-HarnessRepo.ps1'
powershell -NoProfile -ExecutionPolicy Bypass -File 'C:\AI-Harness\scripts\Resolve-HarnessRuntime.ps1' -All

# 2. git 상태
git -C C:\AI-Harness log --oneline -3
git -C C:\AI-Harness status --short
```

다음 세션 첫 지시 예시:

> `C:\AI-Harness\proposals\HANDOFF.md` 를 읽고 M7 후반부부터 이어서 진행해줘.

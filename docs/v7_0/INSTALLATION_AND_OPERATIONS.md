# AI Harness v7.0 — Roblox Studio MCP 상세 설치·운영 가이드

> **상태: 7.0.0 Release Candidate 준비 중.** 사용 가능한 정식 태그는 v6.2.0입니다. 이 문서는 \`upgrade/v7.0\`의 개발·검증 환경 안내입니다.
> **핵심:** 클론·MCP 등록·실제 Studio 연결·게임 수정·배포는 각각 별개입니다. 사용자의 Windows Roblox Studio에 접근하지 못하는 원격 CI는 실제 라이브 연결을 증명할 수 없습니다.

## 1. 시작 전 준비 및 접근 권한

필수: Windows 10/11 또는 macOS, Roblox Studio 최신 버전, Roblox 계정, Codex CLI, Git, Node.js 22+. 권장: GitHub CLI \`gh\`, PowerShell(Windows), Rojo/Rokit, StyLua, Selene. Wally와 Lune은 실제 패키지/테스트에 필요할 때만 사용합니다.

**작업은 반드시 비공개 테스트 Place에서 먼저 진행하세요.** 운영 중인 게임, 퍼블릭 서버, 유료 아이템·데이터스토어에 직접 변경하지 않습니다. Roblox Studio가 열려 있고 인증되어 있어도 권한은 자동 위임되지 않습니다.

\`\`\`powershell
git --version
gh --version
node --version
codex --version
\`\`\`

GitHub 로그인이 아직 없다면:
\`\`\`powershell
gh auth login --hostname github.com --git-protocol https --web
gh auth status
gh repo view hacker943410-debug/ai-harness
\`\`\`
GitHub와 Codex 인증은 별개입니다. \`gh auth token\`을 화면/로그에 출력하지 마세요.

## 2. v7.0 후보 저장소 연결

처음 받는 경우:
\`\`\`powershell
New-Item -ItemType Directory -Force C:\Dev | Out-Null
Set-Location C:\Dev
gh repo clone hacker943410-debug/ai-harness ai-harness
Set-Location C:\Dev\ai-harness
git fetch origin
git switch -c upgrade/v7.0 --track origin/upgrade/v7.0
git rev-parse HEAD
git status --short
\`\`\`

이미 동일 저장소가 있는 경우:
\`\`\`powershell
Set-Location C:\Dev\ai-harness
git status --short
# 미완료 변경사항을 먼저 보존하고, 깨끗한 작업 트리에서만:
git fetch origin
git switch upgrade/v7.0
git pull --ff-only origin upgrade/v7.0
\`\`\`

기존 작업을 보존해야 한다면 새로운 Worktree를 만드세요. \`git reset --hard\`, \`git clean -fd\` 또는 임의 파일 덮어쓰기는 하지 않습니다.

**버전 주의:** v7 브랜치에서는 \`HARNESS_VERSION=6.2.0\`이 아직 정상입니다. 실제 7.0 정식 릴리스가 아닌데 이 값을 강제로 바꾸거나 설치된 프로젝트의 Source Pin을 조작하지 마세요.

## 3. 공식 Roblox Studio Agent Plugin 설치

공식 자료:
- https://github.com/Roblox/roblox-studio-agent-plugin
- https://create.roblox.com/docs/studio/mcp

Codex CLI에서:
\`\`\`powershell
codex plugin marketplace add Roblox/roblox-studio-agent-plugin
codex
\`\`\`

Codex 대화형 화면에서 \`/plugins\`를 열어 **Roblox Studio** Plugin을 설치합니다. 완료 후 새 스레드(\`/new\`)에서 “Roblox Studio를 연결해줘. 먼저 읽기 전용으로 연결 상태만 확인해줘.”라고 요청하세요.

Studio에서는 Assistant → 메뉴 (…) → MCP Servers(또는 Manage MCP Servers) → **Enable Studio as MCP server** 활성화. 같은 설정 화면의 Quick Connect에서 Codex(일부 빌드에서 ChatGPT (codex))를 허용하고 Studio 연결 상태 표시등을 확인합니다.

**중복 주의:** Studio의 Quick Connect, 공식 Plugin 자동 등록, 기존 수동 \`codex mcp add\` 등록이 겹치면 중복 연결 오류가 날 수 있습니다. 추가 설치 전에 \`codex mcp list --json\`을 점검합니다. Roblox 공식 Plugin이 이미 연결돼 있다면 다른 비공식 MCP를 추가하지 않습니다.

### Plugin 설치 명령이 없는 CLI
먼저 \`codex --version\`, \`codex plugin --help\`, \`codex mcp --help\`로 현재 버전의 명령 지원을 확인합니다. CLI가 지원하지 않으면 공식 Studio 문서의 Quick Connect 또는 수동 MCP 등록법을 검토합니다. **추측으로 실행 플래그나 원격 실행 코드를 추가하지 마세요.**

Windows 공식 Studio MCP 바이너리 경로:
\`\`\`text
%LOCALAPPDATA%\Roblox\mcp.bat
\`\`\`
이는 Studio에서 제공하는 프로그램이며 새 서버 바이너리를 외부에서 임의 다운로드할 필요가 없습니다.

## 4. 읽기 전용 환경 진단 (아무것도 수정하지 않음)

\`\`\`powershell
node scripts/roblox/doctor.mjs --project C:\Dev\my-roblox-game
codex mcp list --json
\`\`\`

검사 결과의 \`REGISTERED_UNVERIFIED\`는 **등록됐다는 뜻**이며 Studio가 실제로 연결됐다는 뜻은 아닙니다. \`studio_connection=NOT_VERIFIED\` 역시 정상적인 보수적 표시입니다.

Codex에서 다음 질문으로 실제 Studio에 접근하는지 검증하세요.

> 열려 있는 Roblox Studio 목록을 공식 MCP \`list_roblox_studios\` 도구로 조회해. Studio ID, Place 이름/ID와 연결 상태를 표시하고, **절대 수정하거나 Playtest를 실행하지 마.** 그다음 승인한 테스트 Place만 \`get_studio_state\` 및 \`search_game_tree\`로 읽어줘.

여러 Studio 창이 보이면 정확한 \`studio_id\`와 Place를 사용자가 선택해야 합니다. 실제 MCP 도구의 인자 스키마는 호출 시점에 확인해야 합니다.

## 5. 읽기 전용 세션 증거 검토

Codex가 실제 MCP 호출 후 로컬 비공개 JSON에 Studio ID·호출 이름·성공 결과의 원본 참조를 보존하게 합니다. **예시 ID를 복사해서 증거처럼 사용하면 안 됩니다.**

\`\`\`powershell
node scripts/roblox/verify-session.mjs --evidence C:\Private\roblox-studio-readonly.json
\`\`\`

\`EVIDENCE_STRUCTURALLY_VALID\`은 JSON 필드의 내부 일관성만 확인합니다. 연결을 독립적으로 인증하지 않습니다. 실제 MCP 응답과 Studio 연결 표시를 별도로 대조하세요.

## 6. 게임 프로젝트 생성과 Rojo 소스 정본

\`\`\`powershell
# 생성 전 경로와 파일 목록만 확인
node scripts/roblox/scaffold.mjs --out C:\Dev\my-roblox-game

# 생성 승인 후, 새로운 비어 있는 폴더에서만:
node scripts/roblox/scaffold.mjs --out C:\Dev\my-roblox-game --create
node scripts/roblox/verify-project.mjs --project C:\Dev\my-roblox-game
\`\`\`

\`PASS_STATIC_ONLY\`는 프로젝트 파일·Rojo 설정의 정적 유효성만 뜻합니다. Studio 테스트는 실행하지 않았습니다.

Rokit를 공식 사이트에서 설치한 다음 \`rokit.toml\`의 도구 버전·바이너리 출처를 검토하고, 게임 프로젝트에서 명시적으로 설치합니다.

\`\`\`powershell
Set-Location C:\Dev\my-roblox-game
# 실제 도구 설치 승인 후만 수행
rokit install

# 필요할 때 Rojo 플러그인 설치 및 Studio 동기화:
rojo plugin install
rojo serve
\`\`\`

**Luau의 진실의 원본(Source of Truth)은 Rojo로 추적되는 \`.luau\` 파일**입니다. MCP로 Studio 내부 스크립트를 직접 수정하면 반드시 Git의 원본 코드로 다시 반영한 뒤 차이를 비교하세요. 현장 수정 내용은 다음 \`rojo serve\` 때 덮어써질 수 있습니다.

## 7. 로컬 게임 코드 품질·빌드 검사

\`\`\`powershell
# 설치된 외부 도구를 실제 실행함. 로컬 프로젝트에서:
node C:\Dev\ai-harness\scripts\roblox\verify-project.mjs --project C:\Dev\my-roblox-game --run-tools
\`\`\`

이 명령은 StyLua, Selene, Rojo 빌드를 실행합니다. 실행 전 도구 버전과 프로젝트 파일을 검토하세요. \`PASS_LOCAL_TOOLS_ONLY\`는 Luau 문법/정적 검사/빌드만 통과했다는 뜻이며 Playtest 완료를 뜻하지 않습니다. 프로젝트 수정에 사용할 코드가 적합한지 별도로 판단합니다.

## 8. 실제 Studio 연결·편집·Playtest 검증 — 병합 필수 항목

아래 작업은 **사용자 Windows PC 또는 macOS의 실제 Roblox Studio**에서 공식 Plugin이 연결된 Codex 세션으로 직접 수행해야 합니다. GitHub Actions는 Studio 화면에 접속할 수 없습니다.

1. Studio 연결 및 실제 Studio ID/Place 확인 — 원본 도구 호출 결과 기록.
2. 현재 테스트 Place와 Rojo 소스의 **복구 가능한 백업** 생성; 기준 커밋·Place 버전 저장.
3. 테스트 Place에 식별 가능한 임시 Luau 코드·Part 하나를 명시적으로 승인 후 생성·수정. **운영 Place 금지**.
4. Studio \`start_stop_play\`로 실제 플레이 모드 진입/종료.
5. \`get_console_output\`의 실제 오류 0 여부와 실패 가능성 점검.
6. \`screen_capture\`에서 생성 객체를 육안으로 확인. 원본 이미지 저장.
7. 변경을 파일 정본과 동기화하고, 저장/복원 테스트. **임시 Part 제거 또는 테스트 Place 복원**.
8. 두 명 이상의 클라이언트를 사용하는 멀티플레이 시나리오 검증(가능하면 공식 \`StudioTestService\` 이용). 단일 플레이테스트만 수행했다면 다중 사용자 검증은 \`NOT_RUN\`입니다.

Codex용 작업 지시 예시:
> 지금 열린 비공개 Roblox 테스트 Place 한 개만 대상으로 하며, 먼저 실제 studio_id와 Place ID를 확인해. 내 승인 전에 어떤 변경도 하지 마. 백업 후 임시 객체·스크립트 생성, Playtest, 콘솔 확인, 스크린샷, Rojo 소스 동기화와 완전 복구, 2클라이언트 검증을 순서대로 실행해. 각 단계마다 원본 MCP 결과 참조·명령·성공/실패·수정 파일·Place 버전을 기록해. 확인할 수 없으면 NOT_RUN으로 표시하고 PASS라고 보고하지 마.

## 9. 운영자 증거 검증 (실행 증명과 형식 검사는 별개)

\`\`\`powershell
node scripts/roblox/verify-live-evidence.mjs --evidence C:\Private\roblox-live-evidence.json
\`\`\`

이 검사는 *증거 필드/단계의 일관성*만 확인합니다. 성공적으로 작성된 JSON도 \`EVIDENCE_CONSISTENT_UNATTESTED\`와 종료코드 **3**을 반환합니다. 이는 의도된 동작입니다. 원본 MCP 기록, Studio 화면, 별도 테스트 Place의 저장 내역을 사람이 직접 대조해야 합니다. **JSON 파일 하나만으로 CI나 Harness가 라이브 MCP가 연결됐다고 자동 인증하지 않습니다.**

특히 아래는 승인 없이 수행하지 않습니다: Roblox 운영 게임에 게시, DataStore 실데이터 수정, 외부 Asset 업로드, 유료 생성형 콘텐츠 호출, 게임 권한 변경, 사용자 재화·Robux 관련 기능 조작.

## 10. CI와 v6.2 회귀 테스트

AI Harness 저장소 루트에서:
\`\`\`powershell
node --test scripts/roblox/test-v7.mjs
node --test scripts/roblox/test-live-v7.mjs
node scripts/validate-roblox-v7.mjs
node --test scripts/test-harness-v6.mjs
node --test scripts/test-harness-guard-integration-v6-2.mjs
node --test scripts/test-jev-v6-2.mjs
node scripts/validate-harness-v6.mjs

# Windows PowerShell 릴리스 검증(저장소의 .githooks 활성 상태 확인)
git config --local core.hooksPath .githooks
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/Test-HarnessRepo.ps1 -Json
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/Test-HarnessRelease.ps1
\`\`\`

이 테스트가 모두 PASS라고 해도 실제 Studio 플레이테스트는 여전히 별도 필수 조건입니다.

## 11. 장애 복구와 로그 관리

| 현상 | 점검 순서 | 해석 |
|---|---|---|
| \`codex\` 또는 Plugin 명령 없음 | \`codex --version\`, \`codex plugin --help\` | 실제 설치 버전 확인 |
| \`Roblox_Studio\` 서버 미등록 | \`codex mcp list --json\`, 공식 Plugin | 등록 필요 |
| 등록됐지만 도구 호출 실패 | Studio MCP 스위치/Quick Connect/재시작 | 등록과 접속은 별개 |
| Studio가 2개 이상 | \`list_roblox_studios\` + 명시적 ID | 다른 Place 수정 방지 |
| \`rokit install\` 실패 | 로컬 네트워크·도구 고정 버전 확인 | 대체 임의 다운로드 금지 |
| Rojo 동기화 충돌 | Git 원본·Studio 수정 내역의 Diff 비교 | 자동 덮어쓰기 금지 |
| 데이터 손상 의심 | 즉시 중단, 테스트 Universe로 격리, 복구 확인 | 릴리스 금지 |
| 검사 \`NOT_RUN\` | 실제 도구 실행 여부 확인 | PASS로 승격 금지 |
| 라이브 증거 코드 3 | 운영자 제출 증거 형식만 검사함 | 외부 원본 대조 필요 |

민감한 Place ID·Studio 세션·MCP 출력·인증정보는 공개 PR과 GitHub Actions Artifact로 업로드하지 않습니다. 원본 증거는 신뢰된 로컬 폴더에 보관하고, PR에는 **개인정보가 없는 승인 결과와 테스트 범위 요약**만 기록합니다.

## 12. v7.0 최종 병합과 정식 설치 구분

정식 v7.0 출시는 아래 모든 항목을 충족한 뒤에만 가능합니다.

- 최신 브랜치의 Linux·Windows 자동 테스트 및 전체 v6.2 회귀 PASS
- 실제 공식 Studio MCP 연결, 쓰기/Playtest/스크린샷/복구, 두 클라이언트 테스트를 **원본 증거와 함께 사용자 확인**
- Roblox Publishing을 테스트 Place로만 제한하고 고위험 작업은 별도 승인
- 관련 도구·Studio 버전 기록, 변경 전후 source sync/rollback 검증
- \`HARNESS_VERSION\`, Manifest, Policy Index, Claude Plugin/Marketplace 등 v7.0.0 정합성 확보
- 정식 \`v7.0.0\` 태그가 **실제 병합된 main 커밋**을 가리키는지 검증

현재는 테스트 Place에서의 직접 연결 증거가 없으므로 **main 병합과 v7.0.0 정식 태그 생성을 보류**합니다. 테스트·검토를 속성상 생략하거나 CI에 가짜 Studio PASS를 삽입하지 않습니다.

**정식 배포 후**에는 각 게임 프로젝트별 Harness를 바로 덮어쓰지 말고 \`PROJECT_INIT.md\`와 \`harness/update/UPDATE_PROTOCOL.md\`에 따라 현재 버전 탐지 → 별도 계획 → 체크포인트 → 적용 → 검증 → 재개 순서로 업데이트합니다. 이전 \`v6.2.0\` 고정 Snapshot은 그대로 유지합니다.

## 공식 참고 자료
- https://github.com/Roblox/roblox-studio-agent-plugin
- https://create.roblox.com/docs/studio/mcp
- https://create.roblox.com/docs/reference/engine/classes/StudioTestService
- https://rojo.space/docs/v7/getting-started/installation/
- https://github.com/rojo-rbx/rokit

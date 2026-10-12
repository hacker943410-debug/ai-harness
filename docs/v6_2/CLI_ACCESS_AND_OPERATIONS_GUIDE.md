# AI Harness — CLI 접속·검증·운영 상세 가이드 (v6.2 Candidate)

> **대상:** Windows 10/11 PowerShell, Codex CLI 중심. macOS/Linux의 Git·gh·Node 명령도 공통 적용 가능
>
> **기준:** 2026-10-12 · 저장소: https://github.com/hacker943410-debug/ai-harness
>
> **검토 브랜치:** `upgrade/v6.2` · **Draft PR #3:** https://github.com/hacker943410-debug/ai-harness/pull/3
>
> **중요:** 이 브랜치는 **정식 릴리스가 아닌 검증 후보**입니다. `HARNESS_VERSION`은 아직 `6.0.0`이며, main 병합·릴리스 태그 생성·운영 프로젝트 업데이트를 자동 실행하지 않습니다.

## 0. 목적과 안전 원칙

이 문서는 GitHub에 호스팅된 AI Harness를 CLI로 내려받고, 적절한 브랜치를 선택하고, Codex로 분석·테스트하고, v6.2 병합 전 결정까지 진행하는 **운영 매뉴얼**입니다.

작업 유형을 구분합니다.

| 원하는 작업 | 올바른 방법 | 위험 경계 |
|---|---|---|
| GitHub의 Harness **소스코드 검토** | Git/gh로 `upgrade/v6.2` 클론·체크아웃, Codex를 소스 폴더에서 실행 | 프로젝트 정책 설치와 다름 |
| v6.2 **코드 수정과 PR 갱신** | 테스트 후 후보 브랜치에만 커밋·Push | main 수정·자동 병합 금지 |
| 다른 개발 프로젝트에 Harness **설치·적용** | 검증 완료된 **불변 태그/스냅샷** + `PROJECT_INIT.md`의 `inspect → plan → apply → verify` | 후보 브랜치를 배포 버전으로 오인 금지 |
| 실제 Jev API 사용 | 별도 프로젝트의 검증된 Harness 바인딩, 환경변수, 명시적 Live Canary·Shadow 승인 | API 키 비공개, 비용 승인 |
| 토큰 예산 통제 | 설치된 프로젝트에서 **관리형 `harness-guard` 실행** | 일반 `codex` 대화형 세션은 자동 강제되지 않음 |

보호 규칙: **검토 전 `main` 직접 Push 금지**, `git reset --hard`, `git clean -fd`, 자동 `stash`, 무단 브랜치 삭제·태그 생성·PR 병합 금지. 기존 작업 트리에 수정 사항이 있으면 별도 Worktree 또는 새 클론을 권장합니다.

## 1. 시작 전 설치 점검 (Windows PowerShell)

PowerShell에서 다음 명령을 **하나씩** 실행합니다.

```powershell
git --version
gh --version
node --version
codex --version
```

- Git: `git --version` 동작 확인
- GitHub CLI: `gh --version` 동작 확인
- Node.js: v6 Harness는 **22 이상** 필요. Windows에서 사용 중인 Node v24도 적합
- Codex CLI: 설치되어 있어야 실제 모델 실행 검증 가능
- PowerShell: Windows PowerShell 5.1 또는 PowerShell 7 사용 가능. `powershell.exe`가 없는 macOS/Linux는 PowerShell 부분을 건너뛰고 실제 도구에 맞게 실행

필요한 프로그램의 설치/업데이트가 필요하다면 공식 출처를 확인한 후 변경합니다. 신뢰할 수 없는 원격 `curl | sh` 또는 `irm | iex` 실행은 기본 안내 경로에서 사용하지 않습니다.

공식 문서:
- GitHub CLI: https://cli.github.com/manual/
- GitHub CLI 인증: https://cli.github.com/manual/gh_auth_login
- GitHub CLI PR 체크아웃: https://cli.github.com/manual/gh_pr_checkout
- Codex: https://github.com/openai/codex

## 2. GitHub 계정 인증 — GitHub CLI와 Codex 인증은 별개

```powershell
# 브라우저에서 본인 계정으로 인증
gh auth login --hostname github.com --git-protocol https --web

# 실제 인증 계정 확인 (토큰 값 출력 금지)
gh auth status

# HTTPS Git 전용 Credential Helper 설정
gh auth setup-git

# 현재 저장소에 대한 읽기 권한 확인
gh repo view hacker943410-debug/ai-harness
```

인증 시 **본인이 해당 저장소에 접근 가능한 계정**인지 확인합니다. 코드 Push 권한은 단순 읽기 권한과 다릅니다. 사내 프록시/SSO/2FA는 별도 인증이 필요할 수 있습니다.

**주의:** `gh auth token`, `gh auth status --show-token`, PAT를 포함한 원격 URL을 출력하거나 화면 공유/로그에 노출하지 마세요. GitHub 인증 성공은 Codex 모델 인증 성공을 의미하지 않습니다. Codex 로그인은 Codex CLI의 현재 사용 방법과 이용 권한에 따라 별도로 설정합니다.

### GitHub CLI 없이도 가능한가?

가능합니다. 공개 저장소이거나 Git Credential Manager가 인증된 환경이면 아래 `git clone https://...` 방식을 사용해 소스를 받을 수 있습니다. 다만 PR 상태·Actions를 확인하는 데는 `gh`가 편리합니다. **저장소의 GitHub MCP 연결은 필수 조건이 아닙니다.**

## 3. 처음 소스코드를 내려받는 경우 — 권장: 별도의 폴더

Windows에서 예시 경로 `C:\Dev`를 사용합니다. 기존 폴더를 덮어쓰지 마세요.

```powershell
New-Item -ItemType Directory -Force C:\Dev | Out-Null
Set-Location C:\Dev

# 방법 A: GitHub CLI
gh repo clone hacker943410-debug/ai-harness ai-harness

# 방법 B: Git CLI (A 대신 사용할 때만)
# git clone https://github.com/hacker943410-debug/ai-harness.git ai-harness

Set-Location C:\Dev\ai-harness

git fetch origin
git branch -r
git status --short
```

### PR을 바로 열고 싶은 경우 (새 클론에서만)

로컬 추적 브랜치를 수동 생성하는 대신 GitHub CLI로 PR #3을 체크아웃할 수도 있습니다.

```powershell
gh pr checkout 3 --repo hacker943410-debug/ai-harness
git branch --show-current
```

기존에 변경 사항이 있다면 이 명령도 브랜치 전환에 영향을 주므로 새 클론이나 Worktree를 이용하세요. `gh pr checkout --force`는 사용하지 않습니다.

### v6.2 검토 브랜치로 이동

```powershell
# 저장소를 새로 클론한 경우 원격 v6.2에서 로컬 추적 브랜치 생성
git switch -c upgrade/v6.2 --track origin/upgrade/v6.2

git branch --show-current
git rev-parse HEAD
git status --short
```

이미 로컬 `upgrade/v6.2`가 존재한다면 **다시 `-c`로 생성하지 말고** 다음처럼 진행합니다.

```powershell
git status --short
# 변경사항이 없다면
git switch upgrade/v6.2
git fetch origin
git pull --ff-only origin upgrade/v6.2
```

`git pull --ff-only`가 거부된다면 로컬 커밋이나 원격 변경을 확인합니다. **자동 `reset --hard`로 강제 동기화하지 마세요.**

### 기존 작업 중인 폴더를 보호하고 싶은 경우 — Worktree 대안

이미 `ai-harness`에서 작업 중이라면 기존 디렉터리의 브랜치를 바꾸는 대신 별도 폴더에서 검토할 수 있습니다.

```powershell
Set-Location C:\Dev\ai-harness
git fetch origin
git worktree add -b review/v6.2 ..\ai-harness-v62-review origin/upgrade/v6.2
Set-Location C:\Dev\ai-harness-v62-review
git status --short
```

`review/v6.2` 로컬 브랜치가 이미 있으면 다른 이름을 사용합니다. 이 Worktree는 독립적인 작업 디렉터리이므로 원래 폴더의 미완료 변경을 보존합니다.

## 4. 잘못된 브랜치 작업 방지 — 반드시 확인할 7개 항목

```powershell
# (1) 현재 작업 중인 프로젝트 최상위 경로
git rev-parse --show-toplevel

# (2) 실제 브랜치
git branch --show-current

# (3) 원격 주소 (토큰이 포함되어 있지 않은지 확인)
git remote -v

# (4) 현재 커밋 SHA
git rev-parse HEAD

# (5) 수정/추가된 파일 존재 여부
git status --short

# (6) 후보 브랜치에 존재하는 Harness Version 원문
Get-Content .\HARNESS_VERSION

# (7) PR 상태 확인
gh pr view 3 --repo hacker943410-debug/ai-harness --json number,title,state,isDraft,headRefName,baseRefName
```

예상 조건:
- 브랜치는 `upgrade/v6.2` 또는 해당 브랜치에서 생성한 `review/v6.2`.
- PR #3의 `headRefName`은 `upgrade/v6.2`, `baseRefName`은 `main`, `isDraft`는 `true`.
- `HARNESS_VERSION`에 **`6.0.0`이 나오는 것은 현재 후보 상태에서 정상**. v6.2.0 정식 출시가 완료됐다는 의미가 아님.
- 검증 전 원격 `main`의 파일을 변경하지 않습니다.

## 5. Codex CLI에서 해당 GitHub 저장소를 열기

Codex CLI는 **현재 작업 디렉터리**의 프로젝트 규칙(`AGENTS.md`)을 읽습니다. 다만 `AGENTS.md`가 참조하는 모든 하위 Markdown 문서까지 자동 실행되지는 않습니다.

```powershell
Set-Location C:\Dev\ai-harness
git switch upgrade/v6.2
codex
```

**첫 번째 추천 요청 (읽기 전용):**

> 현재 저장소는 AI Harness의 v6.2 후보 브랜치다. `AGENTS.md`와 `README.md`, `docs/v6_2/CLI_ACCESS_AND_OPERATIONS_GUIDE.md`, `docs/v6_2/FINAL_PREMERGE_REVIEW.md`를 현재 검토 목표에 필요한 범위만 읽어라. 현재 브랜치·원격·커밋 SHA·PR #3 상태를 실제 Git/gh 명령으로 확인하고, v6.1·v6.2의 변경 내역·Jev 동작·토큰 정책·검증 경계를 요약해라. **아직 파일 수정·커밋·Push·브랜치 삭제·PR 병합·릴리스 태그 생성·외부 API 호출은 하지 마라.** 확인하지 못한 사항은 `NOT_VERIFIED`로 표시해라.

CLI가 `codex` 명령을 인식하지 못하면 우선 `codex --version`, PATH, 설치 환경을 확인합니다. CLI 인증 문제는 GitHub 인증과 별도입니다.

### 다른 CLI(Claude Code, Gemini 등)로 접속하는 경우

실제 v6.2 소스 저장소 루트에는 **`AGENTS.md`만 존재**합니다. 설치된 개별 프로젝트에는 `CLAUDE.md`, `GEMINI.md` 등의 Bridge를 생성할 수 있지만, 현재 GitHub 소스 폴더 자체에서 Claude/Gemini가 이 가이드를 자동으로 읽는다고 가정하지 마세요.

```powershell
Set-Location C:\Dev\ai-harness

# 해당 CLI가 설치된 경우에만 하나 선택
claude
# 또는 별도의 셸에서
# gemini
```

Claude/Gemini 첫 메시지 예시:

> 현재 디렉터리는 AI Harness v6.2 검토용 GitHub 소스 저장소다. 먼저 `README.md`와 `docs/v6_2/CLI_ACCESS_AND_OPERATIONS_GUIDE.md`에서 CLI 접속 및 검증 부분을 읽고, `AGENTS.md`와 `docs/v6_2/FINAL_PREMERGE_REVIEW.md`의 안전 조건을 준수해라. 실제 Git 브랜치·PR 상태를 확인한 뒤 작업을 시작해라. 명시적으로 승인받기 전에는 Push/병합/브랜치 삭제/유료 API 호출을 하지 마라.

사용 중인 CLI의 실제 버전, 지침 파일 지원 여부, 신뢰 설정을 먼저 점검합니다. **Codex 전용 `harness-guard-v6-2.mjs`가 자동으로 Claude/Gemini 실행을 계측하는 것은 아닙니다.** 공통 Git/Node 오프라인 테스트는 CLI에 관계없이 직접 실행할 수 있습니다.

## 6. 소스 코드 최종 검토 — 본격 수정 전

```powershell
gh pr view 3 --repo hacker943410-debug/ai-harness
gh pr diff 3 --repo hacker943410-debug/ai-harness --name-only
gh pr checks 3 --repo hacker943410-debug/ai-harness

# 현재 checkout의 기준 diff 요약
git diff --stat origin/main...HEAD
git log --oneline origin/main..HEAD
```

필수 검토 문서:
- `docs/v6_2/FINAL_PREMERGE_REVIEW.md`: 병합 승인 조건, 미검증 항목, 릴리스 절차
- `docs/v6_2/EXECUTION_ENFORCEMENT.md`: 관리형 Codex 실행·토큰 측정·Checkpoint·Completion Gate 한계
- `docs/v6_2/JEV_RUNTIME_INTEGRATION.md`: Jev 인증·Live Canary·Shadow·Fallback
- `docs/v6_1/CODEX_COMPATIBILITY_AND_OFFICE_SKILLS.md`: v6.1 CLI 변경 및 Office Skill의 실제 출처
- `harness/manifest.yaml`, `POLICY_INDEX.yaml`, `HARNESS_VERSION`: 정본·버전 일관성

**특별 확인:** v6.1에서 포함된 Word/PPT/Excel/PDF 4개는 자동 평가로 성능이 입증된 외부 전문 Skill이 아니라 **이 저장소에서 신규 작성한 지침형 Skill**입니다. 병합 전에 유지/교체/삭제를 별도 결정합니다.

## 7. 검증 명령 — 네트워크/API 과금 없이 시작

아래는 Harness 루트 디렉터리에서 실행합니다. `Node 22+` 및 PowerShell이 필요하며, 실행 전 작업 트리 상태를 기록합니다.

```powershell
node --test scripts/test-jev-v6-2.mjs
node scripts/test-jev-scenarios.mjs

node --test scripts/test-harness-guard-v6-2.mjs
node --test scripts/test-codex-compat-v6-1.mjs
node scripts/validate-office-skills-v6-1.mjs

node scripts/validate-harness-v6.mjs
node --test scripts/test-harness-v6.mjs

powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/Test-HarnessRepo.ps1 -Json
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/Test-HarnessRelease.ps1
```

**검증 기준:** 명령 종료 코드가 0이어야 하며, 출력에 FAIL 또는 미수행 항목이 있는지도 별도로 확인합니다. Windows/Linux CI Green은 위 명령 전체 또는 실제 모델 호출 테스트까지 모두 검증했다는 의미가 아닙니다. `Node --test`는 실제 provider API 호출을 수행하지 않도록 설계된 오프라인 검사입니다. 다만 `scripts/test-jev-scenarios.mjs`는 환경변수/플래그 조합에 따라 명시적으로 Live Canary를 지원하므로, 일반 검사에서는 `--live`를 붙이지 않습니다.

테스트 결과가 실패하면 해당 실패를 기록하고 원인을 조사하세요. 사용자 승인 없이 기존 테스트를 삭제하거나 조건을 약화해 PASS로 만들지 않습니다.

## 8. Jev 설정 — GitHub 소스 검토와 실제 사용을 구분

**현재 후보 브랜치만 클론한 상태라면 Jev 설정을 바로 활성화할 프로젝트 바인딩이 없을 수 있습니다.**

Jev 설정 명령은 실제 `.ai/harness-project.json`을 가진 프로젝트를 대상으로 합니다. API Key와 프로젝트를 지정하지 않으면 일반 소스 검토 중 Jev가 호출되지 않습니다.

Jev 실사용 준비:
1. Vercel AI Gateway에서 사용할 수 있는 `AI_GATEWAY_API_KEY`를 확보하고 실제 모델 사용권한·요금·정보처리 조건 확인.
2. 키를 **해당 PowerShell 프로세스 환경**에만 제공. 파일/PR/Issue/로그/AGENTS에 저장하지 않음.
3. 검증된 불변 Harness 소스와 프로젝트 `.ai/harness-project.json`의 `harness.root`, `harness.version`, `harness.source_hash`가 일치해야 함.
4. **실제 provider 호출 및 소액 과금 승인 후에만** 합성 입력 Live Canary로 Shadow 모드 활성화.

```powershell
# 검증된 정식 Harness 루트에서 실행
node scripts/jev-runtime-v6-2.mjs status --project C:/your/project

# 이 명령은 실제 Gateway 요청을 발생시킬 수 있음. 명시적 승인 후만 실행:
node scripts/jev-runtime-v6-2.mjs activate --project C:/your/project --live true

# 비활성화 (네트워크 요청 없음)
node scripts/jev-runtime-v6-2.mjs disable --project C:/your/project
```

Jev는 현재 **Shadow**로서 낮은 위험의 일부 개발 작업에서 합성·비민감 메타데이터만 평가합니다. 결정권한을 넘기지 않으며 장애 시 기존 결정적 Router로 복귀합니다. API 키만 존재한다고 자동 활성화되지 않습니다. **이 후보 브랜치의 `HARNESS_VERSION=6.0.0` 상태를 억지로 v6.2 정식 설치에 사용하지 마세요.** 상세 안내는 `JEV_RUNTIME_INTEGRATION.md`에 있습니다.

## 9. 실제 토큰 예산 검증 — 관리형 Codex 실행만

Harness가 다른 프로젝트에 올바르게 설치·고정되었다는 전제에서:

```powershell
# v6.2를 정상 태그/배포/설치한 검증된 로컬 Harness 루트에서만:
node scripts/harness-guard-v6-2.mjs preflight --project C:/your/project --request "버그 영향 범위 확인"

# 사용량 측정 가능한 Codex exec (실제 모델 사용량/비용 발생 가능)
node scripts/harness-guard-v6-2.mjs run --project C:/your/project --request "작은 버그 수정" --soft-limit 80000 --hard-limit 110000

node scripts/harness-guard-v6-2.mjs report --project C:/your/project
```

**확인할 필드:** `status`, `token_usage`, `token_measurement`, `budget.action`, `verification`, `jev`, `actual_agent_policy_reads`, `interactive_enforcement`.

- Soft/Hard Limit은 **완료된 turn 이후**에 평가됩니다. 진행 중인 turn의 토큰을 강제로 줄이는 기능이 아닙니다.
- Hard Limit 이후 다음 관리형 실행은 유효한 구조화된 Checkpoint 증거가 요구됩니다.
- `model tier`는 추천일 뿐 실제 사용 모델 변경은 확인되지 않았습니다.
- 정책 경로 안내는 실제 파일 읽기 증빙이 아닙니다.
- Windows에서 `codex`가 npm `.cmd` shim으로만 노출되는 경우 `spawn(shell:false)`의 호환성 테스트가 필요합니다. 실제 검증 전 성공으로 표시하지 마세요.
- 일반 대화형 `codex` 실행은 이 관리형 Wrapper를 거치지 않습니다.
- GitHub 후보를 단순히 Clone한 상태에서 `preflight` 실패는 올바른 project binding이 없다면 정상적인 차단일 수 있습니다.

## 10. 기존 개발 프로젝트에 Harness를 적용하려면

**소스 저장소(`ai-harness`)와 실제 앱 저장소는 다른 경로여야 합니다.** 지금은 v6.2 후보이므로 아래 명령 흐름은 **정식 6.2 릴리스/검증된 설치 소스가 준비된 이후**에만 실행합니다.

```powershell
# 읽기 전용 상태 점검
node scripts/harness-v6.mjs inspect --project C:/Dev/your-app
node scripts/harness-v6.mjs diagnose --project C:/Dev/your-app

# 의도 분류
node scripts/harness-v6.mjs route --project C:/Dev/your-app --request "현재 개발 상황을 보존하고 Harness를 업데이트해줘"

# 분석·검토 가능한 계획 생성 (제품 코드에는 변경 없음)
node scripts/harness-v6.mjs plan --project C:/Dev/your-app --request "현재 개발 상황을 보존하고 Harness를 업데이트해줘" --out C:/Dev/your-app/.ai/update-plan.json

# 계획/기존 변경사항/체크포인트/테스트 환경을 승인한 후에만:
# node scripts/harness-v6.mjs apply --plan C:/Dev/your-app/.ai/update-plan.json

# 적용 후 진단:
# node scripts/harness-v6.mjs verify --project C:/Dev/your-app
```

`plan`도 프로젝트의 필수 상태/검증 명령 설정이 없으면 차단될 수 있습니다. 먼저 `PROJECT_INIT.md`와 `harness/update/UPDATE_PROTOCOL.md`를 참고하세요. 중요한 결정이 필요한 경우에만 사용자 승인 요청을 하며, 임의로 기존 프로젝트의 배포·DB·인증 구조를 바꾸지 않습니다.

## 11. 검증 후 코드를 수정할 때 — 안전한 Git 운영

```powershell
git status --short
git diff --check
git diff --stat
```

Code Review 후 수정이 필요하면 **현재 브랜치에만** 최소 패치합니다. 새 변경사항은 반드시 관련 테스트와 회귀검증을 수행한 뒤, 정확한 경로만 `git add`로 지정합니다. 광범위한 `git add .`나 인증 파일 추가에 주의하세요.

```powershell
# 예: 검토한 파일만 스테이징 (실제 파일명으로 바꿔 실행)
# git add docs/v6_2/FINAL_PREMERGE_REVIEW.md
# git diff --cached
# git commit -m "docs(v6.2): clarify review instructions"
# git push origin upgrade/v6.2

gh pr checks 3 --repo hacker943410-debug/ai-harness
```

`main`에 직접 Push하지 마세요. Branch Protection/Required Checks/Review 상태를 확인합니다.

## 12. 최종 병합 전 Go/No-Go 체크리스트

- [ ] PR #3의 Head SHA 및 최신 CI Linux/Windows 결과 확인
- [ ] v6.1 모든 커밋이 v6.2의 조상인지 확인 (독립적인 v6.1 PR/작업자 없는지 확인)
- [ ] 사용자·프로젝트 맞춤 정책, 기존 Skill, 26개 정책, v6 베이스라인 무손실
- [ ] v6.1의 Office Skill 4종은 **외부 전문 Skill이 아님**을 인지하고 유지/교체/제거 선택
- [ ] 소스 Manifest·Index·버전·Skill 카탈로그 참조 검증
- [ ] 전체 Node/PowerShell 회귀검증 통과, 실패·미실행 항목 별도 보고
- [ ] 실제 Windows Codex managed guard 실행과 종료·사용량·Completion Gate 검증
- [ ] Jev의 실패 Fallback 및 데이터 범위 확인; Live Canary는 사용자 승인 후 검증
- [ ] 불필요한 JIT 정책 로딩 여부 및 실제 토큰/시간·품질 비교 (미측정은 UNKNOWN)
- [ ] v6.2.0 정식 버전 반영 계획: `HARNESS_VERSION`, `manifest`, `POLICY_INDEX.yaml`, 클라이언트·플러그인, 릴리스 태그와 소스 pin 일치
- [ ] 백업·롤백·기존 프로젝트 단계적 업데이트 계획
- [ ] 검증과 별개로 **사용자가 최종 병합을 명시 승인**

**현재 상태는 `HOLD`: 정적 CI 통과만으로 정식 릴리스/병합을 승인하지 않습니다.**

병합이 승인되면 Codex가 버전·태그 정합성을 확정하고, 최종 PR 리뷰를 거쳐 `main`에 병합합니다. 본 가이드는 병합 명령을 자동 실행하거나 `main`을 수정하지 않습니다.

## 13. v6.1 브랜치 삭제 여부

`upgrade/v6.1`은 v6.2에 포함된 것으로 확인됐으나, 마지막으로 다시 검증하세요.

```powershell
git fetch origin
git log --oneline origin/upgrade/v6.1..origin/upgrade/v6.2
git log --oneline origin/upgrade/v6.2..origin/upgrade/v6.1
```

**두 번째 명령은 추가 v6.2 커밋이 나올 수 있고, 세 번째 명령은 아무 커밋도 나오지 않아야 합니다.** 별도 작업자/PR이 없는지 확인 후에만 원격 v6.1 브랜치를 정리할 수 있습니다.

```powershell
# 명시적으로 v6.1 삭제가 승인된 후에만:
# git push origin --delete upgrade/v6.1
```

삭제하지 않아도 v6.2 검증·병합에는 영향을 주지 않습니다.

## 14. 문제 해결 표

| 증상 | 우선 진단 | 처리 |
|---|---|---|
| `gh` 명령 없음 | `gh --version` | 공식 GitHub CLI 설치 후 PATH 재시작 |
| `gh auth status` 오류 | 현재 로그인 계정·SSO·권한 | `gh auth login` 또는 적절한 계정으로 전환 |
| Clone 인증 실패 | Repo URL·권한·Git Credential Manager | HTTPS 인증 확인, 비밀 URL 사용 금지 |
| `fatal: not a git repository` | `Get-Location` | Clone 폴더로 이동 |
| `git switch`가 변경 충돌로 거부 | `git status --short` | 작업 유실 방지. 별도 Worktree에서 검토 |
| `git pull --ff-only` 실패 | 로컬/원격 Divergence | `git log --oneline --left-right`로 조사, 강제 Reset 금지 |
| `HARNESS_VERSION`이 6.0.0 | v6.2 후보 아직 미출시 | 정상. Release Gate 통과 후 변경 |
| `HARNESS_NOT_BOUND` | 프로젝트 `.ai/harness-project.json` 부재 | 소스 검토와 프로젝트 설치 절차 구분 |
| `PINNED_SOURCE_DRIFT` | 실제 Root/Hash/Version 불일치 | 코드 억지 수정·검사 우회 말고 정식 Migration |
| Jev `MISSING_API_KEY` | 해당 프로세스에 환경변수 미설정 | 인증값을 파일이 아닌 신뢰된 프로세스에 전달 |
| Jev `CANARY_FAILED` | API/모델/요금·키 권한/네트워크 | provider 상태 진단, Shadow 비활성 유지 |
| Guard `TOKEN_BUDGET_UNCONFIGURED` | Soft/Hard 한도 누락 | 명시적 승인과 적절한 예산 설정 |
| Guard Windows `.cmd` 문제 | Codex binary 경로/실행기 | 실제 binary 확인·시험, 쉘 우회 금지 |
| 테스트 PASS지만 실제 규칙 미이행 | 관리형 vs 대화형 실행 혼동 | Guard 보고서·정책 실제 읽기 증거·모델 사용량 분리 |
| GitHub CI Green인데 PR Hold | 실제 Codex E2E/Live Canary/Release tag 미검증 | 최종 검토 문서의 남은 Gates 완료 |

## 15. Codex에 전달할 최종 검증용 프롬프트

> 이 저장소는 `upgrade/v6.2` 후보이고 `main`은 수정하면 안 된다. 우선 `docs/v6_2/CLI_ACCESS_AND_OPERATIONS_GUIDE.md`와 `docs/v6_2/FINAL_PREMERGE_REVIEW.md`에서 필요한 부분만 읽어라. 실제 GitHub 원격·브랜치·PR #3·최신 커밋을 확인하라. v6.1의 모든 커밋이 v6.2에 포함됐는지 검증하라. v6.0 베이스라인과 변경 목록, Codex guard/토큰 정책 연결, Jev Shadow/Fallback/API 사용, Office Skill 출처와 기능 수준, immutable source pin을 실제 파일과 테스트로 독립 검증하라. 결함이 있다면 원인·영향·수정 범위·재현·회귀 테스트를 먼저 제시하고 후보 브랜치에서만 최소 수정하라. 테스트 결과는 명령·종료코드·환경·증거·NOT_RUN을 구분해 보고하라. Live Jev 호출·운영 데이터 접근·비용 발생·릴리스 버전 변경·원격 브랜치 삭제·PR 병합은 반드시 내 별도 승인 후 실행하라. 최종 출력은 Go/No-Go 판단과 남은 Blocker 목록으로 작성하라.

---

## 부록 — 공식 명령 문서

- [GitHub CLI gh auth](https://cli.github.com/manual/gh_auth_login)
- [GitHub CLI clone](https://cli.github.com/manual/gh_repo_clone)
- [GitHub CLI PR checkout](https://cli.github.com/manual/gh_pr_checkout)
- [GitHub CLI PR checks](https://cli.github.com/manual/gh_pr_checks)
- [OpenAI Codex repository](https://github.com/openai/codex)
- [AI Harness v6.2 Draft PR](https://github.com/hacker943410-debug/ai-harness/pull/3)

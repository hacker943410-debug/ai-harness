# AI Harness v5.0 — CLI별 패치노트

기준: v3.1 정본에서 v5.0으로의 변경. 기존 P01~P26 정책 번호와 3계층 구조는 유지한다.

## 공통

### 추가
- 하네스 정본에 `skills/` 공식 계층 추가.
- 첫 번들 Skill: `dashboard-builder`.
- `CORE → ROUTER → POLICY_INDEX → 필요한 Policy/Skill만 JIT` 실행 체계.
- 외부 Skill 검색보다 하네스 번들 Skill을 우선.
- `POLICY_INDEX.yaml.runtime.use_jit_skill_loading = true`.

### 유지
- 26개 정책의 ID/파일명/역할.
- GitHub = Canonical, Drive = immutable snapshot 원칙.
- Layer A/B/C 분리.
- MCP의 installed/registered/authenticated/verified 상태 분리.
- Jev는 optional advisor이며 기존 Router fallback 유지.

## OpenAI Codex CLI

### 변경
- `dashboard-builder`를 프로젝트 native Agent Skill로 설치 가능.
- 기본 설치 위치: `<project>/.codex/skills/dashboard-builder/`.
- 명령:
  ```powershell
  .\scripts\Install-ProjectSkill.ps1 -Id dashboard-builder -ProjectRoot <project> -Client Codex
  ```
- Skill을 설치하지 않아도 Global Harness Router가 정본 `skills/dashboard-builder/SKILL.md`를 JIT 절차서로 읽을 수 있음.
- `.ai/capability-lock.json`에 번들 Skill SHA-256과 설치 경로를 기록.

### 그대로인 부분
- MCP 등록 scope 제약과 `CODEX_HOME` 관련 계약은 변경하지 않음.
- Google Workspace Runtime 인증/등록 방식도 변경하지 않음.

## Claude Code

### 변경
- 프로젝트 native Skill 설치 위치: `<project>/.claude/skills/dashboard-builder/`.
- 기존 ai-harness plugin에 `dashboard-builder` wrapper 추가.
- wrapper는 원본을 복제하지 않고 `skills/dashboard-builder/SKILL.md`를 정본으로 참조.
- marketplace/plugin metadata를 5.0.0으로 상향.

### 명령
```powershell
.\scripts\Install-ProjectSkill.ps1 -Id dashboard-builder -ProjectRoot <project> -Client Claude
```

또는 ai-harness Claude plugin 설치 시 wrapper를 통해 호출.

### 그대로인 부분
- 기존 `/harness-init`, `/harness-doctor`, harness-runtime, harness-capability 유지.
- MCP tool deny가 context를 반드시 줄이지 않는 기존 제한은 유지.

## AGY (Google Antigravity)

### 변경
- Google의 현재 공식 Codelab 기준 프로젝트 범위 Agent Skill 경로 `<project-root>/.agents/skills/`를 native 설치 대상으로 지원.
- `dashboard-builder` 설치 위치: `<project>/.agents/skills/dashboard-builder/`.
- `Install-ProjectSkill.ps1 -Client AGY`를 지원하고 `-Client AllNative`에도 포함.
- 설치하지 않은 프로젝트에서는 Router가 Global Harness의 `skills/dashboard-builder/SKILL.md`를 JIT 절차서로 읽는 fallback도 유지.

### 그대로인 부분
- MCP per-tool deny/approval 부재라는 기존 limitation 유지.
- high-risk Runtime은 server-level on/off 또는 등록 생략 전략 유지.

## 여러 CLI를 함께 사용하는 프로젝트

Codex + Claude + AGY를 같이 쓰면:

```powershell
.\scripts\Install-ProjectSkill.ps1 -Id dashboard-builder -ProjectRoot <project> -Client AllNative
```

결과:

```text
<project>/
├─ .codex/skills/dashboard-builder/
├─ .claude/skills/dashboard-builder/
└─ .agents/skills/dashboard-builder/
```

둘은 같은 Harness 원본에서 복사되며 capability-lock에 hash가 남는다.

## dashboard-builder 기능

```text
Excel / CSV / JSON
        ↓
데이터 구조·품질 분석
        ↓
비즈니스 질문
        ↓
KPI 3~7개
        ↓
차트·필터·레이아웃
        ↓
Design System
        ↓
HTML / 기존 Web Stack
        ↓
데이터 무결성 + 반응형 + 오류상태 QA
```

- SheetJS / Chart.js 사용 가능
- file:// 로컬 fallback
- http/https 자동 데이터 로드
- Cloudflare R2/Workers 배포 지침
- 데이터에 없는 KPI/수치를 임의 생성하지 않음
- 검증 전 완료 판정 금지

## 마이그레이션

기존 프로젝트는 즉시 깨지지 않는다. 기존 Policy Runtime은 그대로 동작한다.

v5 bridge를 프로젝트에 반영하려면 Global Harness 업데이트 후 `PROJECT_INIT.md`를 다시 실행한다. 기존 project instruction은 marker 내부만 갱신한다.

dashboard-builder가 실제 필요한 프로젝트에서만 Skill을 설치하거나 JIT로 읽는다. 모든 프로젝트에 강제 복사하지 않는다.

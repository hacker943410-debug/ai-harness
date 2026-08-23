# AI Harness Patch Notes

이 문서는 AI Harness의 사용자 관점 변경사항과 검증 결과를 누적 기록한다. 최신 항목을 위에 추가한다.

## 2.2 — 2026-08-23

### 목표

MCP 호환 AI가 바뀌어도 Google Workspace 업무를 동일한 PC 공용 런타임과 OAuth profile로 수행할 수 있도록 기반을 구성했다.

### 추가 및 변경

- `C:\AI-Tools\google-workspace-mcp`에 `@dguido/google-workspace-mcp` 3.4.4를 정확한 버전으로 설치했다.
- Google Drive, Gmail, Calendar, Docs, Sheets, Slides, Contacts 공용 실행 래퍼와 범용 MCP 설정 예시를 추가했다.
- OAuth credential 가져오기, 사용자 전용 ACL 적용, 최초 인증을 수행하는 스크립트를 추가했다.
- `workflows/GOOGLE_WORKSPACE_MCP.md`에 공용 경로, 클라이언트 연결, 권한 경계, 공식 Google 원격 MCP 선택 기준을 정의했다.
- MCP Catalog에 `google-workspace-local` 항목을 추가했다.
- 비밀값이 없는 `settings/google-workspace/` 이식형 manifest와 설정 template을 추가했다.
- `Initialize-GoogleWorkspaceMcp.ps1`가 경로가 다른 PC에서도 공용 런타임을 설치하고 사용자 locator 환경변수를 설정한다.
- `Resolve-GoogleWorkspaceMcp.ps1`가 사용자 환경변수와 표준 후보 경로에서 command를 자동 탐지한다.
- PROJECT_INIT이 새 AI 클라이언트를 발견하면 사용자가 경로를 다시 입력하게 하지 않고 공식 방식으로 한 번 등록하도록 규정했다.
- 현재 PC의 Codex와 Claude Code에 `google-workspace`를 전역/사용자 범위로 등록했다.
- AGY CLI의 공용 `~/.gemini/config/mcp_config.json`에도 `google-workspace`를 등록하고 자동 초기화 대상에 추가했다.
- Google Drive MASTER `/AI-Harness`에 전체 Harness를 경로 기준으로 동기화했다(기존 31개 갱신, 신규 15개 생성, 실패 0개).

### 보안 및 제한

- OAuth client secret과 token은 Harness 및 프로젝트에 저장하지 않는다.
- Google Cloud의 Desktop app OAuth JSON 발급과 브라우저 동의는 사용자 계정 승인이 필요한 최초 1회 단계다.
- Google 공식 Workspace 원격 MCP는 2026-08-20 기준 Developer Preview이고 클라이언트별 OAuth redirect 설정이 필요하므로 PC 공용 기본값으로 사용하지 않았다.

### 검증

- PASS — npm audit 취약점 0건
- PASS — Node.js 24.19.0으로 런타임 요구사항(Node 22 이상) 충족
- PASS — MCP 실행 파일이 3.4.4로 시작되고 stdio 대기 상태 진입
- PASS — Desktop app OAuth credential과 access/refresh token 존재 및 JSON 파싱 확인(비밀값 미출력)
- PASS — 공용 MCP stdio handshake 및 tool discovery 확인
- PASS — 공용 locator 환경변수와 resolver가 동일 command를 반환
- PASS — Codex global 및 Claude Code user scope 연결 상태 확인
- PASS — Drive MASTER의 `settings/google-workspace` manifest/template 존재 확인
- INFO — 실제 Drive/Gmail 데이터 호출은 각 AI 클라이언트 등록·재시작 후 최소 권한 읽기 요청으로 확인

## 2.1 — 2026-08-23

### 목표

웹·모바일 프로젝트 진행 중 현재 Agent에 필요한 Capability가 없을 때, 적합한 MCP 또는 Agent Skill을 찾아 프로젝트 범위로 한 번 설치하고 이후 재사용할 수 있는 JIT Capability Acquisition 계층을 추가했다.

### 추가

- `catalogs/mcp-catalog.json`
  - 공통 개발, 웹, 디자인, DB, API, Cloud, 관측성, 협업, 분석, Android/iOS MCP 후보 정의
  - 검증된 설치 좌표와 검색 전용 후보를 `verified` / `discovery_only`로 구분
- `catalogs/skill-catalog.json`
  - Skills.sh에서 확인한 웹·모바일·DB·테스트·설계·작업 절차 Skill 정의
- `schemas/capability-lock.schema.json`
  - 프로젝트별 MCP/Skill 설치 기록 형식 정의
- `workflows/CAPABILITY_ACQUISITION.md`
  - Capability Gap 판정부터 검색, Risk Gate, 프로젝트 설치, 검증, 재사용까지의 표준 절차
- `scripts/Search-HarnessCapability.ps1`
  - 로컬 카탈로그를 Capability·도메인·이름으로 검색
- `scripts/Install-ProjectSkill.ps1`
  - Skills.sh CLI를 이용한 프로젝트 로컬 Skill 설치 및 Lock 기록
- `scripts/Install-ProjectMcp.ps1`
  - 정확한 Version의 npm MCP 프로젝트 설치 또는 검증된 Remote MCP 기록
- `scripts/Test-ProjectCapabilities.ps1`
  - Catalog, Lock, Version pin, 프로젝트 Scope, Secret 의심 패턴, 중복 MCP 검사

### 변경

- Harness Version을 `2.0`에서 `2.1`로 갱신
- Router에 `TOOL_CAPABILITY_GAP`, `MCP_DISCOVERY`, `SKILL_DISCOVERY`, `PROJECT_TOOL_INSTALL`, `REMOTE_MCP_AUTH`, `TOOL_VERSION_DRIFT`, `TOOL_INSTALL_FAILED`, `PRODUCTION_CAPABILITY` 경계 추가
- P15에 MCP/Skill을 Dependency 범위로 명시하고 JIT Acquisition 계약 추가
- P17에 MCP Credential, OAuth Scope, Project-local Config 보안 계약 추가
- Doctor에 Capability Catalog와 프로젝트 설치 상태 검사 항목 추가
- README와 PROJECT_INIT에 선택적 Capability 계층 연결

### 설계 결정

- MCP/Skill 전문을 `CORE`나 `POLICY_INDEX`에 preload하지 않는다.
- 설치 좌표를 확신할 수 없는 항목은 자동 설치하지 않고 `discovery_only`로 유지한다.
- 프로젝트 설정은 `.ai/mcp/desired.json`, 설치 상태는 `.ai/capability-lock.json`에 Secret 없이 기록한다.
- Client별 MCP 설정 형식은 서로 다르므로 정규화된 Desired State와 Client Adapter를 분리한다.
- 설치 성공과 Runtime 검증을 구분한다. 실제 호출 전에는 `verified`로 기록하지 않는다.

### 호환성 및 제한

- Skills 설치 후 Client에 따라 새 Agent 세션이 필요할 수 있다.
- iOS Simulator/Xcode MCP는 macOS와 Xcode가 필요하다.
- `registry_lookup`, `remote_or_client`, `source_or_registry` 항목은 설치 시점에 공식 문서를 재확인해야 한다.
- 현재 Patch는 전역 자동 설치를 제공하지 않는다. 프로젝트 범위가 기본이며 의도된 동작이다.

### 검증

- PASS — MCP Catalog JSON 파싱, 64개 ID 중복 없음
- PASS — Skill Catalog JSON 파싱, 44개 ID 중복 없음
- PASS — Capability Lock JSON Schema 파싱
- PASS — PowerShell Script 4개 AST 구문 파싱
- PASS — `browser automation` 검색에서 Playwright MCP와 Playwright Skill 반환
- PASS — Skill 설치 `-WhatIf`가 프로젝트 Root 대상 명령으로 생성됨
- PASS — MCP 설치 `-WhatIf`가 exact Version의 project devDependency 명령으로 생성됨
- PASS_WITH_INFO — Harness Root 대상 Capability Doctor; 설치 Lock이 아직 없음을 정상 정보로 반환

---

## 2.0 — 기존 기준선

- 26개 전문 정책
- CORE + ROUTER + POLICY_INDEX 기반 JIT Policy Loading
- PROJECT_INIT을 통한 얇은 Project Adapter 설치
- HARNESS_DOCTOR 기반 읽기 전용 운영 진단

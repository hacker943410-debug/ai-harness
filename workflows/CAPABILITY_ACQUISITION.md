# Capability Acquisition Workflow

Document Version: 1.0  
Purpose: 현재 프로젝트에 필요한 MCP 또는 Agent Skill을 필요할 때만 발견·검토·설치·검증하고 재사용한다.

## 1. 기본 원칙

1. 내장 도구, 현재 프로젝트 Dependency, 이미 설치된 MCP/Skill을 먼저 확인한다.
2. 현재 작업에 필요한 Capability가 실제로 부족할 때만 검색한다.
3. MCP는 외부 시스템 접근·실행 도구이고, Skill은 절차·규칙·도메인 지식이다.
4. 설치 위치의 기본값은 현재 프로젝트다. 사용자 또는 플랫폼이 명시하지 않은 전역 설치를 하지 않는다.
5. `discovery_only` 항목은 이름만으로 설치하지 않는다. 공식 Registry, 제작사 문서 또는 Skills.sh에서 최신 설치 좌표를 재확인한다.
6. 로컬 Package형 MCP는 정확한 Version을 고정한다. `latest`를 영구 설정에 남기지 않는다.
7. 설치 승인, Credential 연결, Production 변경 승인은 서로 다른 권한이다.
8. Secret 실제 값은 Catalog, Lock, Project State, Prompt, Adapter에 기록하지 않는다.

## 2. Capability Gap 판정

다음 순서로 확인한다.

```text
요구 기능
→ Agent 내장 도구로 가능한가?
→ 프로젝트에 이미 있는 CLI/Package/Script로 가능한가?
→ capability-lock.json에 설치·검증된 도구가 있는가?
→ MCP가 필요한가, Skill이 필요한가, 둘 다 필요한가?
```

기존 방식으로 안전하게 해결 가능하면 새 도구를 설치하지 않는다.

## 3. 검색 순서

### MCP

1. `catalogs/mcp-catalog.json`을 capability/domain으로 검색한다.
2. `verified` 항목이라도 설치 직전 공식 문서와 현재 좌표를 확인한다.
3. `registry_lookup` 또는 `discovery_only`는 공식 MCP Registry와 제작사 문서에서 동일 Publisher인지 확인한다.
4. 후보가 여러 개면 공식성, 최소 권한, 플랫폼 호환성, 유지보수 상태, 중복 Capability 순으로 비교한다.

### Skill

1. `catalogs/skill-catalog.json`을 검색한다.
2. Skills.sh 상세/API에서 source, slug, file tree, content hash, duplicate 여부, audit 결과를 확인한다.
3. 설치 전 `SKILL.md` 전체와 포함 Script를 검토한다.
4. Official/first-party를 우선하되 Audit가 안전성을 완전히 보증한다고 간주하지 않는다.

## 4. Risk Gate

- LOW: 읽기 전용 절차 Skill, 문서 변환. 검토 후 프로젝트 로컬 설치 가능.
- MEDIUM: 브라우저 제어, 일반 개발 도구. Target과 Side Effect를 확인한다.
- HIGH: 파일 쓰기, GitHub write, DB, SaaS, Device 제어. 최소 권한과 허용 Root/Resource를 고정한다.
- CRITICAL: 결제, Production, Cloud IAM, Provision/Delete. 설치와 별개로 실제 실행 전 명시적 범위·복구·승인을 확인한다.

## 5. 프로젝트 로컬 설치

### Skill

프로젝트 Root에서 Skills CLI를 실행한다. 기본적으로 Telemetry를 끈다.

```powershell
$env:DISABLE_TELEMETRY = '1'
npx skills add <source> --skill <skill-id>
```

CLI가 현재 Agent용 프로젝트 디렉터리에 설치했는지 실제 생성 파일로 확인한다. 새 세션이 필요한 Client에서는 현재 세션에 즉시 활성화됐다고 주장하지 않는다.

### Local Package MCP

프로젝트에 `package.json`이 있고 npm 기반 MCP인 경우 정확한 Version으로 devDependency를 설치할 수 있다.

```powershell
npm install --save-dev --save-exact <package>@<version>
```

그 후 `.ai/mcp/desired.json`에 Secret 없는 정규화 설정을 기록한다. 실제 Client 설정은 해당 Client의 공식 프로젝트 설정 형식으로 변환한다.

### Remote MCP

Package 설치 대신 프로젝트 Client 설정에 Remote URL을 추가한다. OAuth Token이나 API Key는 Client/OS Secret Store 또는 환경변수 참조로만 제공한다.

## 6. 검증

설치 후 가능한 범위에서 다음을 수행한다.

1. 설치 파일 또는 Package resolution 확인
2. MCP handshake 또는 Skill discovery 확인
3. 읽기 전용 Smoke Test
4. 필요한 최소 Permission 확인
5. 예상하지 않은 Lockfile/설정 변경 확인
6. `.ai/capability-lock.json` 기록

설치만 성공하면 상태는 `installed`다. 실제 호출까지 확인돼야 `verified`다.

## 7. 재사용과 Update

다음 작업에서는 먼저 Lock과 실제 설치 상태를 비교한다. 일치하고 검증 상태가 유효하면 재설치하지 않는다.

Update는 현재 Task에 필요하거나 보안·호환성 근거가 있을 때 별도 Dependency Change로 수행한다. 자동으로 최신 Version을 따라가지 않는다.

## 8. 실패와 정리

- 설치 실패를 광범위 권한, 전역 설치, `latest`, TLS 검증 해제로 우회하지 않는다.
- 부분 생성 파일과 Lockfile 변경을 확인한다.
- 현재 작업에 불필요해진 도구를 즉시 자동 삭제하지 않는다. Consumer와 프로젝트 정책을 확인한다.
- 실패 원인과 다음 안전한 선택지만 기록하고 Secret이나 긴 Tool Output은 저장하지 않는다.

## 9. Compact Record

```text
CAPABILITY ACQUISITION
Need: ...
Existing capability: YES / NO
Type: MCP / SKILL / BOTH
Candidate: ...
Source verified: YES / NO
Risk: LOW / MEDIUM / HIGH / CRITICAL
Scope: PROJECT
Install: NOT_NEEDED / PLANNED / INSTALLED / FAILED
Runtime verification: VERIFIED / PARTIAL / NOT_RUN
```

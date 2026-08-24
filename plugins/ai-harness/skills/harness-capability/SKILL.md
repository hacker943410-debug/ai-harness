---
name: harness-capability
description: 현재 작업에 필요한 도구(MCP 서버 또는 Agent Skill)가 없을 때 발견·검토·설치·검증하는 절차. "이걸 하려면 MCP 가 필요한데 없다", "무슨 Skill 을 깔아야 하나", "이 MCP 설치해도 되나", 새 외부 도구·SDK 도입 검토, Capability Gap 판정 상황에 쓴다.
---

# Capability 획득

```
HARNESS_ROOT = ${CLAUDE_PLUGIN_ROOT}/../..
```

## 먼저 읽는다

- `<HARNESS_ROOT>/workflows/CAPABILITY_ACQUISITION.md` — 절차 정본
- `<HARNESS_ROOT>/catalogs/mcp-catalog.json` / `skill-catalog.json` — 검색 대상

이 SKILL 은 요약이다. 충돌하면 위 파일이 이긴다.
관련 정책은 P15(의존성·외부 계약), P17(보안·권한), P23(범위 이탈), P06(검증)이다.

## 0. 먼저 — 정말 필요한가

```
요구 기능
→ 내장 도구로 가능한가?
→ 프로젝트에 이미 있는 CLI / Package / Script 로 가능한가?
→ .ai/capability-lock.json 에 이미 설치·검증된 것이 있는가?
→ 그래도 안 되면: MCP 인가, Skill 인가, 둘 다인가?
```

기존 방식으로 안전하게 되면 **새 도구를 설치하지 않는다.**
MCP 는 외부 시스템 접근·실행 도구, Skill 은 절차·규칙·도메인 지식이다.

## 1. 검색

카탈로그를 capability/domain 으로 검색한다. 편의 스크립트가 있다:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File '<HARNESS_ROOT>\scripts\Search-HarnessCapability.ps1' -Query <키워드>
```

**`discovery_only` 는 이름만으로 설치하지 않는다.** 공식 Registry·제작사 문서에서 좌표를 재확인한다.
`verified` 항목이라도 설치 직전에 현재 좌표를 확인한다.

**이름이 같다고 같은 것이 아니다.** 발행자(publisher)를 대조한다.
npm 의 `repository`, PyPI 의 `project_urls.Source`, OpenUPM 의 저장소가 각각 근거가 된다.
실제로 이름은 맞지만 발행자가 다른 패키지를 집을 뻔한 적이 있다.

## 2. Risk Gate

| 등급 | 예 | 요구 |
|---|---|---|
| LOW | 읽기 전용 절차 Skill, 문서 변환 | 검토 후 프로젝트 로컬 설치 |
| MEDIUM | 브라우저 제어, 일반 개발 도구 | Target 과 Side Effect 확인 |
| HIGH | 파일 쓰기, GitHub write, DB, SaaS, 장치 제어 | 최소 권한, 허용 Root/Resource 고정 |
| CRITICAL | 결제, Production, Cloud IAM, Provision/Delete | 설치와 별개로 **실행 전** 범위·복구·승인 확인 |

**설치 승인 / Credential 연결 / Production 변경 승인은 서로 다른 권한이다.** 하나를 받았다고 나머지를 가정하지 않는다.

## 3. 설치

- 기본 설치 위치는 **현재 프로젝트**다. 명시되지 않은 전역 설치를 하지 않는다.
- Package 형 MCP 는 **정확한 버전을 고정**한다. `latest` 를 영구 설정에 남기지 않는다.
- 프리릴리스는 상류에 정식 릴리스가 없을 때만 쓰고, 검사기가 WARN 을 내는 것이 정상이다.
- Secret 실제 값은 Catalog / Lock / Project State / Prompt / Adapter 어디에도 적지 않는다.
  환경변수 이름이나 Secret Store 참조만 적는다.

**전역 공용 런타임**(여러 프로젝트에서 쓰는 MCP)이면 이 절차가 아니라
`harness-runtime` Skill 과 `workflows/SHARED_RUNTIME.md` 로 넘어간다. Layer B 가 관여한다.

## 4. 검증

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File '<HARNESS_ROOT>\scripts\Test-ProjectCapabilities.ps1'
```

1. 설치 파일 또는 package resolution 확인
2. MCP handshake 또는 Skill discovery 확인
3. **읽기 전용 Smoke Test — 실제로 한 번 호출한다**
4. 필요한 최소 Permission 확인
5. 예상하지 않은 Lockfile/설정 변경 확인
6. `.ai/capability-lock.json` 기록

**설치만 성공하면 `installed` 다. 실제 호출까지 확인돼야 `verified` 다.**
새 세션이 필요한 클라이언트에서는 현재 세션에 즉시 활성화됐다고 주장하지 않는다.

## 5. 실패했을 때

광범위 권한 부여, 전역 설치, `latest`, TLS 검증 해제로 **우회하지 않는다.**
부분 생성 파일과 Lockfile 변경을 확인하고, 실패 원인과 다음 안전한 선택지만 기록한다.
Secret 이나 긴 Tool Output 은 저장하지 않는다.

## 6. 기록 형식

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

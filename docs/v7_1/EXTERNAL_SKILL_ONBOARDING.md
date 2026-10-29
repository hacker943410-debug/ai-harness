# AI Harness: 외부 Skill 보안 도입 및 v7.1 단계별 계획

작성: 2026-10-29 / 상태: **후보 설계 + 검증 대기** / 정식 배포: **아님**

## 1. 변경 목적과 운영 제한

기존 v7.0.0과 Draft PR #5 (`fix/v7.0.1-cli-triad`)는 보존한다. 이 문서는 추가 보안 패치의 검증 기준이다. **승인 없이 main 병합, 릴리스 생성, 운영 프로젝트 설치, CLI 변경 및 외부 서비스 인증을 수행하지 않는다.**

- 운영 목표: Codex / Claude Code / AGY 중 **선택한 한 CLI**만 사용해 공통 정책을 적용한다. 3개 구독은 필수가 아니다.
- 상위 정본: `CORE.md`, `ROUTER.md`, `POLICY_INDEX.yaml`, 선택된 P01~P26, 프로젝트 `.ai/HARNESS.md`.
- 외부 Skill의 지침·명령·설치 스크립트는 위 정책을 수정·무효화할 수 없다.
- 기존 Codex Guard는 **관리형 `codex exec` 경로만** 관찰한다. 일반 대화형 CLI, Claude/AGY의 토큰 강제 적용으로 표현해서는 안 된다.
- 모델 `gpt-6.1-terra`의 존재와 실제 계정 접근 가능 여부, 비용 및 품질은 별도 검증한다.

## 2. 외부 Skill 도입 게이트

기존 설치기는 번들 Skill을 복사하고 전체 SHA-256 파일 트리 해시를 기록하지만 외부 Skill은 `npx skills add`를 호출한 뒤 원본 검증 없이 잠금 파일에 등록하는 경로가 있었다. 신규 후보 패치에서는 **원격 실행 경로를 제거**하고 외부 Skill도 번들과 동일한 단계적 복사·검증·원상복구 절차로 통합한다.

1. **조사:** 공식 저장소·특정 커밋·라이선스, Skill 별 용도와 기존 Harness 중복 확인.
2. **격리:** 별도 디렉터리에 *특정 커밋*의 Skill 자료만 스냅샷으로 준비. 프로젝트 안에 두지 않는다.
3. **검토:** `SKILL.md`, 참조 스크립트, 설치 hooks, 원격 API·프록시, 시크릿·민감정보 처리, 자동 업데이트·자동 Push 여부 전체 확인. 이 단계에서 콘텐츠를 읽었다는 이유만으로 명령을 실행하지 않는다.
4. **고정:** `Get-HarnessSkillManifest`로 파일 목록 및 `sha256-tree-v1` 해시를 산출, 검토 기록에 실제 소스 커밋과 함께 고정한다. 해시만으로 GitHub 원본 출처의 진위가 보증되는 것은 아니다.
5. **계획/승인:** 프로젝트 범위, 대상 CLI, 기존 사용자 파일 충돌, 네트워크·토큰·추가 요금 확인. `-WhatIf`로 예행연습.
6. **설치/검증:** 검토된 로컬 폴더와 예상 해시를 명시하여 설치. 설치 전·스테이징·설치 후 전체 트리 해시 검증, 실패 시 롤백, `.ai/capability-lock.json`에 파일별 해시 기록.
7. **운영:** 사용자 승인 없는 자동 업데이트와 글로벌 설치 금지. 원본 변경 시 새 커밋 및 해시로 재검토.

### 명령 예시 (Windows PowerShell)

아래는 **검토된 로컬 소스와 해당 ID가 Catalog에 존재하는 경우에만** 사용할 수 있는 예시다. 먼저 스냅샷을 따로 준비해야 하며, 해당 프로젝트의 실제 설치를 이 문서에서 수행하지 않는다.

```powershell
. .\scripts\_Harness.Common.ps1
. .\scripts\_Harness.Skill.ps1
$skillDir = 'C:\ReviewedSkills\skill-name'
$expected = (Get-HarnessSkillManifest $skillDir).Hash
.\scripts\Install-ProjectSkill.ps1 -Id 'skill-name' -ProjectRoot 'C:\Projects\Project' `
  -Client Codex -ReviewedSourceDirectory $skillDir -ExpectedTreeHash $expected -AllowDiscoveryOnly -WhatIf
# 설치와 권한·데이터 전송을 검토하고 승인한 뒤에만 -WhatIf를 제거한다.
```

`-AllowDiscoveryOnly`는 **검토 전 소스 설치 허용 스위치가 아니다.** Catalog의 discovery-only 표시를 추가로 확인하는 예외이며, 로컬 폴더·정확한 해시 요건은 여전히 적용된다.

## 3. 조사한 외부 Skill 후보 (설치·승인 전)

| 출처 | 우선 검토 범위 | 장점 | 검토 위험 | 상태 |
|---|---|---|---|---|
| [NomaDamas/k-skill](https://github.com/NomaDamas/k-skill) | KOSIS/공공 통계, 한국어 문서·검색 | 한국형 데이터 연결 | 호스팅 프록시, 자동 업데이트, 런타임 npm 패키지, 자격증명·라이선스 | 조사 후보 |
| [EveryInc/compound-engineering-plugin](https://github.com/EveryInc/compound-engineering-plugin) | `ce-plan`, `ce-code-review`, `ce-handoff`, `ce-compound` | 작업 계획·검증·지식 축적 | 기존 Phase Engine 중복, 에이전트 자동 변경·커밋·PR 작업 | 조사 후보 |

**k-skill:** 공식 설치 안내에는 전체·글로벌 설치와 `@nomadamas/k-skill@0 update` 흐름이 있다. Harness에서는 해당 전역 설치·자동 업데이트를 기본 적용하지 않는다. 공개 프록시 경유 기능은 사용자 데이터가 어디로 전송되는지 검증 전까지 비활성화한다. AgriPrice-Guard AI의 기존 공식 데이터 수집/검증·학습 분리 체계를 외부 Skill로 덮어쓰지 않는다.

**Compound Engineering:** 개발 과정의 장점을 선별 채택하되 기존 정책/계획/검증 엔진을 대체하지 않는다. `ce-work`·자동 PR/Push/병합·고위험 파일 변경 기능은 별도 승인 및 권한 격리 검증 전까지 비활성화한다. AGY 플러그인 지원 문서가 있다고 해도 실제 실행 환경의 권한 적용은 재시험한다.

## 4. 차기 버전 작업 순서

| 단계 | 변경 | 필요한 실증 | 병합 조건 |
|---|---|---|---|
| v7.0.1 | 기존 Draft PR #5의 단일 CLI 선택·공통 정책 로딩 | 실제 사용하는 1종 CLI의 E2E, Windows/Linux 회귀 | 설치·롤백 및 정책 보존 통과 |
| v7.1.0-P0 | 외부 Skill 설치의 로컬 리뷰/트리 해시·격리 게이트 | 새 PowerShell 회귀 + 기존 번들 스킬 회귀 | CI 성공, 무단 원격 실행 경로 0 |
| v7.1.0-P1 | 승인된 Skill 별 Skill Broker·Compound Loop | 샘플 프로젝트 A/B 테스트, 라이선스·시크릿/프록시 감사 | 최소 권한, 기존 정책과 중복 없음 |
| v7.1.1 | Execution Guard 및 Model Router 시험 | 일반 대화형 경로의 관찰 한계 명시; Terra/Sol 성능·비용 실측 | 지원된 경로별 집행 강도와 증거 확보 |
| v7.2.0 | Windows Control Center GUI | 비개발자 설치·백업·검증·롤백 사용성 검사 | 핵심 기능 GUI 재현 |

토큰 절감률 목표(예: 15%)는 **검증 대상 가설**이지 달성 성과가 아니다. 작업군, CLI 버전, 모델 접근권, 성공률, 재시도, 실제 토큰과 결제 비용을 함께 측정한다.

## 5. 뉴스 교차 검증 게이트

AI 한국어 뉴스·3종 CLI·해커톤의 기술 동향은 설계 후보를 제공하지만, 실제 반영 전에는 **각 공급자의 릴리스 원문, 코드, 사용 조건 및 재현 테스트**로 확인한다.

- Codex: MCP 취소, 세션·멀티에이전트 중단, 모델 라우팅/승인 정책 확인
- Claude Code: 승인·실행 상태 및 기존 `CLAUDE.md` 규칙 보존
- AGY CLI: `AGENTS.md` 로딩·MCP 개별 도구 제한·모델/구독 조건 확인
- GitHub Agentic Autofix, REA 및 기타 실험적 도구: 활용 범위·과금·보안·자동 실행 여부 검증 후 별도 후보로 유지
- **최신 버전 문자열, 모델 성능 주장, Skill 개수는 고정 진실로 취급하지 않는다.** 실사용 시 공식 원문과 현행 상태를 재점검한다.

## 6. 검증 명령 및 제약

```powershell
.\scripts\Test-ReviewedExternalSkill.ps1
.\scripts\Test-ProjectSkillInstall.ps1
node scripts/validate-harness-v6.mjs
node scripts/validate-release-v7.mjs
```

CI 후보: `.github/workflows/reviewed-external-skill.yml` (Windows + Linux, Windows PowerShell 5.1 확인 포함).

이 문서 작성 시점에는 **실제 PC의 CLI E2E, 외부 Skill 코드 감사, 외부 API 접속, 모델 비용·성능 벤치마크는 완료되지 않았다.** 별도 작업과 승인 없이 `main` 또는 기존 운영 프로젝트를 수정하지 않는다.

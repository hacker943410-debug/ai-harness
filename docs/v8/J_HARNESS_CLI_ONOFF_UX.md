# J Harness v8 — CLI 설치 및 ON/OFF 화면 설계

- 결정일: 2026-10-29
- 공식 새 이름: **J Harness** (기존 v7 저장소·릴리스·문서의 역사적 `AI Harness` 표기는 그대로 둔다)
- 실행 파일 표시명: **J Harness**; 권장 단축 명령: **`jh`**
- 상태: **사용자 UX/보안 설계안, 구현·설치 완료 아님**
- 제품 제약: 사용자가 변경할 수 있는 Harness 설정은 **ON/OFF 한 가지뿐**이다. Codex/Claude/AGY, 모델·Skill·예산·정책·버전은 읽기 전용 상태 정보이며 선택 메뉴를 만들지 않는다.

## 1. 질문: 기존 Codex/Claude/AGY CLI에 J Harness ON/OFF 메뉴를 추가할 수 있는가?

기술적으로 각 CLI의 Skill/명령 메뉴에 `/j-harness` 등 **보이는 진입점**을 추가하는 것은 CLI 지원 범위에 따라 가능하다. 그러나 그 Slash 명령은 보통 Agent의 지침/Tool 실행 경로에 진입한다. 그곳에서 `ON/OFF`를 직접 변경하도록 구현하면 AI가 Tool/Shell/MCP를 호출해 동일한 코드를 실행하여 **스스로 Harness를 OFF** 할 수 있다. 이는 사용자 요구를 위반한다.

**결정:** 실제 ON/OFF 변경 메뉴는 **AI TUI 내부 Skill이 아니라 별도 신뢰된 J Harness 터미널 관리자(`jh`)**가 소유한다. `/j-harness`는 지원하는 경우 읽기 전용 상태/설명 창만 제공하는 선택적 편의 기능이며 강제 실행/전환 권한이 없다. 각 CLI의 공식 API가 **AI가 실행할 수 없는 사용자 전용 이벤트**를 제공한다고 실증되기 전에는 CLI 내부에서 ON/OFF 변경을 지원하지 않는다.

공식 문서(조사 원천):
- Codex의 Skill은 모델이 읽고 실행할 지침. https://developers.openai.com/plugins/concepts/skills
- Codex CLI 커스터마이징/입력/테마. https://developers.openai.com/docs/cli-customization
- Claude Code CLI의 커스텀 명령/Skill 기능은 가용 버전에서 별도 확인 필요. https://code.claude.com/docs/en/skills
- AGY CLI는 Skill을 slash command로 자동 노출. https://www.agy.dev/docs/skills/

## 2. 권장 사용자 경험 — 설치 후 기본 ON

### 설치·첫 실행

1. 사용자가 소유자 승인된 릴리스를 **신뢰된 설치 프로세스**로 설치한다. 설치 과정은 관리자 권한을 적절히 요구하고, 정책/실행기/상태 저장소를 AI 작업 폴더와 분리한다.
2. `jh` 명령을 PATH에 등록하고, 사용 중인 `codex`, `claude`, `agy` 실행 경로·버전을 **자동 감지**한다. 다른 CLI 설치를 요구하지 않는다.
3. 관리형 실행 경로·OS 격리·정책 서명/해시·사용자 인증이 검증되면 최초 상태를 **ON**으로 표시한다. 하나라도 필수 조건이 불충분하면 **BLOCKED**로 표시하고, ON이라고 선언한 채 무관리 작업을 수행하지 않는다.
4. 사용자는 PowerShell/Windows Terminal에서 `jh` 명령으로 관리 메뉴를 연다. CLI 선택 메뉴·모델 설정·예산 변경·Skill 변경·관리자 편집 항목은 없다.

```text
PS C:\Projects\MyApp> jh

┌─────────────────────────────────────────────┐
│ J Harness                                   │
│ 상태: ON (관리형)                            │
│ 감지된 CLI: Codex CLI (읽기 전용)           │
│ 정책: 소유자 승인 버전 / 무결성 PASS         │
│                                             │
│ J Harness 활성화                            │
│   (●) ON     ( ) OFF                        │
│                                             │
│ 변경하려면 사용자 본인 확인 필요            │
└─────────────────────────────────────────────┘
```

위 내용은 **예시 화면**이며 `jh` 실행 파일이나 UI는 아직 구현하지 않았다.

### 토글 변경

- ON → OFF: 사용자 전용 관리자 화면에서 선택→ **AI 실행 세션과 분리된 로컬 사용자 본인 확인**→ 활성 관리형 세션 안전한 종료 또는 전환 보류→ `OFF/UNMANAGED` 표시. 자동 OFF 금지.
- OFF → ON: 동일한 본인 확인→Supervisor/정책/OS 경계 재검증→정상일 때만 `ON/MANAGED`, 실패 시 `BLOCKED`.
- 사용자 토글 상태는 프로젝트 폴더, `AGENTS.md`, `CLAUDE.md`, `.ai` 설정, 모델의 셸/Tool로 편집할 수 있는 파일에 저장하지 않는다.
- CLI에서 `jh on`/`jh off`와 같은 **무인 실행형 상태 변경 명령은 제공하지 않는다.** 본문만 따라 실행 가능한 스크립트·환경변수로 토글을 제어할 수 있게 만들면 AI도 같은 경로를 호출할 수 있다.
- Windows 터미널 화면만 띄웠다고 사람의 직접 조작이 증명되지 않는다. **별도 신뢰된 사용자 인증/확인 UI, 다른 OS 권한 경계 또는 이에 준하는 보호**가 필요하다. 선택 구현 시 Windows Hello 등은 가능성 검토 대상이지 현재 작동하는 기능이 아니다.

### 터미널 명령 안내

| 입력 | 용도 | 접근권한 |
|---|---|---|
| `jh` | 사용자 인증을 요구하는 ON/OFF 관리 메뉴 | **사용자 전용**; AI Tool/PTY 직접 사용 차단 |
| `jh status` | ON/OFF/BLOCKED, 감지된 CLI, 정책 버전만 읽기 | 읽기 전용 |
| `jh doctor` | OS/Policy/CLI 실제 강제 경계 **읽기 전용** 진단 | 읽기 전용 |
| `jh run` | Supervisor가 감지된 현재 CLI를 관리형 작업공간에 실행 | 실행이 가능하려면 보호된 Supervisor와 OS 격리 검증 선행 |
| `jh on`, `jh off` | **지원하지 않음** — AI 우회 가능 | 명령 노출 금지 |

상태 화면/진단은 **설정값 변경이 아니다**. 사용자에게 여러 개의 선택 가능한 설정을 제공하지 않는다.

## 3. 기존 CLI를 그대로 사용하는 경험

### 단기 구현에서 확실히 제공할 수 있는 경로

- `jh` → ON/OFF 관리
- `jh run` → 실제 사용하는 CLI 1개를 Supervisor가 자동 탐지하여 관리형으로 실행
- 명시적으로 `codex`/`claude`/`agy`를 직접 실행하면 현재 단계에서는 **UNMANAGED**. `AGENTS.md`/Hook/Skill이 로딩되더라도 통제가 적용됐다고 보장해서는 안 된다.

### 최종 목표 (추가 OS 검증 필요)

- 사용자는 평소와 동일하게 `codex`, `claude`, `agy`를 입력한다.
- J Harness 설치기가 경로·권한·바이너리 출처를 검증하여 이 호출이 **보호된 Supervisor 진입점**을 통과하도록 구성한다.
- `PATH` 셸 별칭만으로는 직접 바이너리 절대 경로 실행, 다른 터미널·IDE·하위 프로세스 우회를 막을 수 없다. 이 상태에서는 ENFORCED로 표시하지 않는다.
- 지원되지 않는 CLI 또는 격리 실패 시 `ON`의 조용한 우회가 아닌 BLOCKED/UNMANAGED 진단을 제공한다.
- 원본 CLI 파일을 덮어쓰거나 인증 정보·모델 설정을 몰래 변경하지 않는다.

## 4. 네임스페이스 및 호환성

- 공식 브랜드 `J Harness`, Windows 시작 메뉴 명칭 `J Harness`, 터미널 명령 `jh`, 진단 출력 `J Harness`.
- **기존 Github 저장소** `hacker943410-debug/ai-harness`, v7.x 태그, 정책/스크립트/CLI 경로는 호환성을 위해 **이 PR에서 이름 변경하지 않는다**.
- GitHub 저장소명을 변경하려면 별도 소유자 승인, clone/remote/CI/링크/릴리스 무결성 영향 검증이 필요하다.
- 환경변수와 lock 파일의 기존 `AI-HARNESS` 식별자는 호환 기간 동안 유지하고, v8 마이그레이션 설계 시 명확한 버전/alias 전략을 수립한다.
- CLI 내부 `/j-harness`를 구현하더라도 **읽기 전용 상태 및 `jh` 관리자 메뉴 안내**만 제공한다.

## 5. 추가 수용 테스트

- 새 설치 상태 ON 표시와 실제 Supervisor/OS 통제 증거가 일치한다.
- `jh` 메뉴에 단 하나의 설정(ON/OFF)만 있다.
- `jh status`는 AI가 호출해도 상태를 변경하지 않는다.
- AI Tool을 통해 `jh`, 가짜 PTY, `jh on/off`, Shell 환경변수, 관리자 RPC를 호출해도 토글 변경이 거부된다.
- 사용자 본인 확인 실패·취소·만료 시 상태 변경 0건.
- ON 중 Supervisor 고장 → OFF 자동 전환이 아니라 BLOCKED.
- OFF/ON 전환 중 실행 세션은 중지/재시작 또는 전환 거부로 일관성을 보장.
- 보호된 `codex` 경로를 우회하는 직접 바이너리 실행은 감지되거나 UNMANAGED로 보고하며, 절대로 J Harness ENFORCED로 오표시하지 않는다.
- GitHub 원본·정책 파일을 AI가 변경할 수 없고, 별도 사용자 승인을 거친 검증된 릴리스만 적용한다.

## 6. 현행 상태

**미구현**: `jh` 실행기, 설치 프로그램, Windows 신뢰된 토글 인증 UI, Supervisor 관리형 CLI 실행기, 완전한 OS 강제, 기존 CLI 내부 읽기 전용 상태 메뉴.

본 문서는 사용자 요구를 확정하는 **제품 UI/보안 설계 문서**다. 실제 ON/OFF가 구현·동작한다고 주장하지 않는다.

# J Harness v8 Phase 2 — Windows 포터블 자동 설치 후보

**상태: Draft PR #9, 실제 PC 설치 권장 전 검증 단계.** 이 문서는 아직 출시된 정식 사용설명서가 아닙니다.

## 이번에 구현한 실제 기능

1. Windows x64에서 `J_Harness_Setup.cmd`를 실행하면 **PowerShell만으로 읽기 전용 설치 계획**을 먼저 보여줍니다.
2. 사용자가 `INSTALL`을 직접 입력해 동의해야 설치를 시도합니다. 설치 승인 입력은 Supervisor의 AI 방지용 인증 기능과 다릅니다.
3. 설치 ZIP에 Node.js `v22.22.2`의 Windows x64 공식 `node.exe`를 포함하며, **코드에 고정된 SHA-256**과 실제 바이너리 해시를 대조합니다. 사용자의 기존 Node.js는 설치·제거·갱신하지 않습니다.
4. 승인 후 실행 파일을 `%LOCALAPPDATA%\JHarness-Bootstrap\node-v22.22.2\node.exe`에 검증 복사합니다.
5. **기존 설치된 Codex CLI**를 재사용해 J Harness Core beta.1 설치·연결을 수행하고 `doctor` 결과를 확인합니다.
6. 설정은 `CODEX_HOME`으로 지정된 기존 Codex 프로필에 **식별 가능한 관리 블록만** 추가하며, 인증·모델·MCP·Windows 계정·시스템 PATH·레지스트리를 변경하지 않습니다.
7. `J_Harness_Uninstall.cmd`는 별도 `UNINSTALL` 확인 후 기존 Core의 안전 해제 기능을 호출하고 사용자 원본 지침을 복원합니다. 비공개 Core 백업과 Node 캐시는 추후 검토를 위해 유지합니다.
8. 별도 옵션 `-AllowOfficialNodeDownload`를 승인 시 지정한 경우에만 정확한 공식 URL에서 고정 Node 실행 파일을 내려받고 SHA 검증한 후 사용합니다. ZIP에 포함돼 있으면 네트워크가 필요하지 않습니다.

**Node 공식 SHA-256 근거:** [Node.js v22.22.2 공식 SHASUMS](https://nodejs.org/dist/v22.22.2/SHASUMS256.txt) 의 `win-x64/node.exe`, SHA-256 `ae1a50511be58e987483fdbc12125407443926d2d394669ade2352776e920dd3`.

## 한 번에 구성되는 것과 아직 아닌 것

| 항목 | 이번 Phase 2 |
|---|---|
| 별도 Node.js 글로벌 설치 없이 시작 | **구현** (ZIP에 공식 pinned Node 포함) |
| J Harness Core 설치·doctor | **구현** (기존 Codex가 있을 때) |
| 설치 계획·사용자 동의 | **구현** (Windows PowerShell / CMD) |
| 기존 설정·인증 보존 | 코드 구현, CI에서 격리 테스트 |
| 해제 및 원본 지침 복원 | 구현, CI에서 격리 테스트 |
| Codex CLI 자체 자동 설치 | **미구현** — 누락 시 중지 |
| Claude Code / AGY CLI 실제 Core 연동 | **미구현** — 다른 구독 강요 없음 |
| Rojo/StyLua/Selene 자동 설치 | **미구현** — Phase1의 계획 단계만 |
| Windows 정식 `Setup.exe` 및 공급자 코드 서명 | **미구현** |
| AI가 ON/OFF 변경을 못 하도록 OS 보안 분리 | **미구현** — Supervisor 후속 |
| 사용자의 Windows PC 실기 | **미검증** — GitHub Actions 가상 Windows 실행기와 구분 |

## 왜 아직 정식 출시하지 않는가?

- 배포 ZIP의 `SHA256_MANIFEST.json`은 파일 손상 탐지용일 뿐 배포자가 누구인지 증명하는 전자서명이 **아닙니다**.
- GitHub Actions 시험에서는 **가짜 Codex 실행 파일**로 CLI 버전 확인을 모의합니다. 실제 사용자의 로그인·모델 동작·인증 승인을 검증한 것은 아닙니다.
- Core가 프로세스와 같은 Windows 사용자 권한으로 실행되는 동안에는 정책 파일/ON·OFF의 우회를 OS 수준에서 막지 못합니다.
- 오류 시 변경된 런타임을 보존해야 할 수도 있습니다. 설치 실패를 자동으로 모두 롤백했다고 주장하지 않고 `PARTIAL_CORE_PRESERVED_MANUAL_REVIEW_REQUIRED`를 구분합니다.
- ZIP 내부 파일의 공식 서명/매니페스트 보호가 없으며, 사용자에게 직접 배포하는 최종 단계에서 배포자 서명·공급망 검증을 추가해야 합니다.

## 개발용 실행 예시 (검증 PC·전용 테스트 프로필만)

GitHub Actions가 만든 **테스트 ZIP** 압축 해제 후:

```powershell
# PC의 Codex 프로필에는 영향을 주지 않는 계획 조회
powershell.exe -NoProfile -File .\bootstrap\Bootstrap-JHarness.ps1 -Action Plan -Client codex

# 실제 기존 Codex 프로필에 설치되는 실행은 별도 승인·테스트 종료 후에만.
# J_Harness_Setup.cmd 에서 안내를 읽고 INSTALL을 입력하는 방식이다.
```

## Phase 3까지 남은 구성

- 원클릭 `Setup.exe` 또는 공급자 서명된 신뢰 배포 패키지.
- 기존 Codex가 없는 PC에서도 공식 CLI 설치 후보를 선택·다운로드·검증·권한 범위 고지 후 구성하는 별도 어댑터.
- 실제 선택한 Claude/AGY 하나만 사용해도 Core의 공통 정책을 로드하는 어댑터.
- 필요할 때만 도구/라이브러리를 격리 설치하는 프로젝트별 의존성 관리기.
- 사용자 승인 이력·복구 저널과 실제 PC에서 설치·업데이트·삭제 실기 검증.
- Supervisor의 독립적인 사용자 인증·OS 강제 권한 경계.

**기존 GitHub main / v7.0.0 / v8.0.0-core-beta.1 / 사용자 PC 설정은 변경하지 않습니다.**

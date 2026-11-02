# J Harness 8 — 환경 자동구성 기반 (Phase 1)

상태: **개발 브랜치 후보 / 정식 설치 프로그램 아님**.

## 사용자 요구
사용자가 매번 Node.js, Git, CLI, 프로젝트 라이브러리를 설치하는 것이 아니라, 완성된 J Harness가 **설치 전 PC 진단 → 필요한 구성요소만 선택 → 공식 출처·버전·해시 확인 → 사용자 승인 후 설치 → 실기 검증 → 실패 시 복원**을 책임져야 한다.

**다른 CLI 구독은 강제하지 않는다.** Codex, Claude Code, AGY 중 실제 쓰는 하나만 있으면 된다. 더 많은 CLI를 설치해도 Harness 정책의 의미는 동일해야 하지만, 같은 수준의 OS 강제 통제는 별도 실기 검증이 필요하다.

## 이번에 구현된 기능
- Node.js 22 이상인지 현재 Node 실행 환경의 런타임 버전 확인.
- Codex / Claude / AGY 중 선택한 **1개만** PATH에서 탐색. CLI를 실행하거나 로그인하지 않고 발견/미발견만 기록.
- Git은 항상 선택 사항. 프로젝트에 따라 Roblox의 Rojo / StyLua / Selene만 추가 탐지.
- 설치 전 조치 계획 수립: 기존 재사용, 설치 승인 필요, 선택 프로젝트용 나중 설치, GUI 사용자 승인 등을 구분.
- Windows에서 Node가 아직 없어도 작동하는 별도 PowerShell Preflight.
- 사용자 승인+사전에 확정된 SHA-256이 있을 때만 로컬 단일 파일을 관리 폴더에 검증 복사하는 구성요소 준비 API. 이것은 **실제 패키지 실행이나 앱 설치가 아님**.
- Node 네이티브 테스트에서 정상/누락/구버전/단일 CLI/해시 불일치/기존 파일 보존/실행 차단/읽기 전용을 검사.

## 개발자 시험 명령
Node가 이미 있는 개발 PC에서:

    node core/environment/doctor.mjs inspect --client codex --profile general
    node core/environment/doctor.mjs plan --client agy --profile general
    node core/environment/doctor.mjs plan --client codex --profile roblox
    node --test core/tests/environment.test.mjs

Node가 **없는 Windows PC**에서도 가능한 읽기 전용 진단:

    powershell.exe -NoProfile -File core/environment/Preflight-JHarness.ps1 -Client codex -Profile general

해당 스크립트는 설치, 네트워크 다운로드, 레지스트리 변경, PATH 변경, CLI 로그인, 기존 지침·인증 변경을 하지 않습니다.

**현재 명령에는 install/apply 명령이 구현되지 않았고, 설치 성공을 주장하지 않습니다.** 탐지한 PATH 파일의 실제 버전·출처·인증·실행 가능성도 아직 검증하지 않습니다.

## 최종 설치 모델 (다음 단계 설계)
1. 최종 배포 패키지는 Node 실행 엔진을 자체 포함해 Windows 사용자에게 별도 Node 설치를 요구하지 않아야 한다.
2. AI가 변경할 수 없는 서명된 공급망/릴리스 매니페스트로 정확한 파일 버전·SHA-256·출처를 검증한다. 단순히 다운로드한 파일 옆 SHA 파일을 비교하는 것만으로 소유자 승인 출처가 인증되는 것은 아니다.
3. 기존 CLI를 탐지해 재사용한다. 사용하지 않는 CLI는 설치하지 않고, 인증은 기존 제품의 공식 로그인만 사용한다.
4. 외부 도구 설치·사용자 홈 변경·OS 권한 변경에는 설치 계획과 사용자의 별도 명시적 승인을 요구한다.
5. 일반 라이브러리는 가능한 프로젝트 또는 Harness 관리 영역에 격리한다. 임의 글로벌 npm/winget 설치는 금지한다.
6. 모든 설치는 변경 로그, 버전 고정, 무결성 검사, 테스트, 업데이트·제거 복구를 통과해야 완료로 표시한다.
7. Supervisor의 ON/OFF 변경은 이 설치 승인과 별개다. 일상 사용의 설정은 사용자 ON/OFF 하나로 유지한다.
8. 실제 보안 격리는 사용자 Windows PC에서 별도 권한·인증 경계의 적대적 검증 후 구현한다. 단순 지침이나 사용자 홈 파일만으로 ENFORCED라고 주장하지 않는다.

## 현재의 한계
- Windows 원클릭 Setup.exe, 설치 런타임 포함 배포 ZIP, 신뢰된 온라인 다운로더/패키지 관리자, OS ACL 분리, 실제 설치 및 롤백은 **NOT_IMPLEMENTED / NOT_RUN**.
- J Harness Core beta.1은 여전히 기존 Node 22+와 Codex를 요구한다. 이 Phase 1 브랜치는 그것을 자동 설치로 바꾸지 않았다.
- 문서/오프라인 테스트/CI 성공은 사용자 PC에서 프로그램이 자동 설치됐다는 증거가 아니다.
- GitHub main, v7.0.0 및 v8.0.0-core-beta.1 태그·릴리스, 로컬 사용자 PC의 설정은 변경하지 않는다.

## Phase 2 수용 조건
- 독립 실행형 설치기가 부족한 필수 컴포넌트를 발견하고 공식 배포물을 검증·설치/격리하며 정상 재사용 시 중복 설치 0건.
- 설치 계획에서 **설치 전 변경·승인·복구 범위**가 명확하고, 승인 취소 시 변경 0건.
- 누락된 종속성/네트워크 장애/해시 불일치/권한 오류는 BLOCKED와 복구 결과를 명시.
- Core의 설치·doctor·ON/OFF·Skills·작업 기록 기능의 기존 회귀 PASS 유지.
- 실제 Windows PC에서 처음 설치와 재설치·업데이트·제거·복구를 원본 설정 비교로 검증.

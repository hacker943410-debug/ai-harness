# J Harness v8 Core beta.1 — 설치와 사용
지원 후보: Windows 11 x64, Node.js 22 이상, 이미 설치한 Codex CLI. 실제 시험 버전은 Node.js 24.19.0 / Codex 0.166.0입니다.
Codex 전용 베타입니다. Claude·AGY 어댑터, 실제 토큰·비용 계측, 자동 예산 제어는 아직 없습니다.

## 1. 준비와 설치
릴리스 자산 J_Harness_Core_v8.0.0-core-beta.1_windows-x64.zip과 SHA256SUMS.txt를 내려받고 ZIP의 SHA-256을 대조한 뒤 압축을 풉니다.
Windows 서비스·MSI·새 계정·VM·추가 모델 설치는 필요 없습니다. Node.js와 Codex가 없으면 설치기는 중지하고 자동 설치하지 않습니다.

압축을 푼 폴더에서 PowerShell:
    .\Install-JHarness.cmd
    .\jh.cmd doctor

또는 동일한 실행:
    node .\core\setup.mjs install
    node .\core\setup.mjs run doctor

대상은 현재 CODEX_HOME이며, 지정돼 있지 않으면 기존 Windows 사용자 프로필의 .codex입니다.
기존에 로그인한 Codex의 인증·모델·MCP·프로젝트 설정을 그대로 사용합니다. Harness 때문에 새로 로그인하거나 모델을 고를 필요가 없습니다.
아직 Codex 자체에 로그인하지 않은 사용자는 Codex의 정상 로그인 절차를 먼저 완료해야 합니다. Harness는 인증파일을 읽어 복사하거나 로그인을 대신하지 않습니다.
Orca 등 프로필 관리 도구에서는 해당 Codex를 실행할 때와 같은 CODEX_HOME 환경에서 설치하세요. 다른 계정/프로필에 자동 설치됐다고 주장하지 않습니다.

설치가 끝나면 새 Codex 세션을 열어 개발을 요청합니다. 프로젝트마다 AGENTS.md를 복사하지 않습니다.
글로벌 AGENTS.override.md가 있으면 그 파일을, 없으면 AGENTS.md를 선택해 소유한 연결 블록만 추가합니다.
기존 지침의 원본 바이트는 <CODEX_HOME>/j-harness-core/backup/global-guidance.before.bin에 보관합니다.
설정·인증파일은 변경하지 않습니다. 사용자 지침이 너무 크거나 관리 블록이 충돌하면 덮어쓰지 않고 중지합니다.

## 2. 평소 사용
실제 개발 프로젝트에서 평소처럼 codex를 실행해 “간단한 웹 프로그램을 만들어줘”라고 요청하세요.
분석 → 권장 계획 → 필요한 정책/Skills → 구현 → 실제 검증 → 초보자 인도가 기본 흐름입니다.
단순 적용 문구만으로 성공을 판단하지 말고 실행 명령·테스트·산출물을 확인하세요.

배포 폴더에서 .\jh.cmd를 실행하면 ON/OFF 메뉴를 엽니다:
    .\jh.cmd
    .\jh.cmd status
    .\jh.cmd doctor
    .\jh.cmd off
    .\jh.cmd on

영구 PATH는 바꾸지 않습니다. 다른 폴더에서는 설치된 <CODEX_HOME>/j-harness-core/bin/jh.cmd의 전체 경로로 실행하세요.
일반 codex의 글로벌 지침 연결은 PATH의 jh 등록과 별개입니다.
ON/OFF 변경은 새 Codex 세션을 기준으로 합니다. ON이면서 파일이 깨졌으면 정상 연결로 표시하지 않습니다.
Core는 협업 지침 도구이며 OS 권한으로 AI의 모든 우회를 막는 보안 제품이 아닙니다.

## 3. Skills·정책·노하우
    .\jh.cmd skills list
    .\jh.cmd skills search "웹 개발 테스트"
    .\jh.cmd skills read jh-web-quality
    .\jh.cmd policy read P06
    .\jh.cmd lessons "오류"

내장 jh-guided-development, jh-web-quality와 기존 dashboard-builder를 필요에 따라 읽습니다.
여러 줄 Skill 설명을 지원하며 지원 불가 형식은 명시합니다. 발견한 외부 Skill의 실행 승인을 자동 부여하지 않습니다.
외부 Skill은 사용자가 내용·스크립트·출처·해시를 검토해 명시적으로 등록한 경우만 연결하며 원격 다운로드·자동 실행은 하지 않습니다.
조회·추천·진단은 파일을 쓰지 않습니다. 명시적 begin/advance/verify/skills record/learn/finish 기록은 선택한 프로젝트의 .jh-artifacts/j-harness-core에 저장합니다.
이전 전역 이력은 읽기 전용 호환 입력으로 보존합니다. Skill APPLIED는 Agent 보고이며 실제 명령 실행 근거와 구분합니다.
정책/Skill은 필요한 것만 선택적으로 읽습니다. bytes/4는 추정치이며 실제 토큰·요금 계측이 아닙니다.

## 4. 업데이트·제거·복원
새 배포 폴더에서 같은 Codex 프로필을 대상으로:
    .\Update-JHarness.cmd
    .\jh.cmd doctor

업데이트 전 런타임·Core 설정·Skills·역사를 별도 backup-before-update 폴더에 보관합니다.
사용자 지침과 ON/OFF를 유지하고, 실패하면 이전 Core로 복구를 시도합니다. 출력한 backup/archive 경로를 보관하세요.
모르는 커스텀 파일·변조·충돌이 있으면 덮어쓰지 않고 중지합니다. 업데이트는 진행 중인 개발을 마친 새 세션 경계에서 수행하세요.
이전 설치기가 영구 User PATH를 등록했다면 portable updater는 중지합니다. 그 경우 기존 패키지의 검증된 core/Uninstall-JHarnessCore.ps1로 해제한 뒤 설치하세요. 실행 정책을 자동 변경하거나 우회하지 않습니다.

제거:
    .\Uninstall-JHarness.cmd

관리 연결만 해제하고 Core는 .uninstalled-시각 폴더에 보관합니다. 기존 지침·CLI 설정·인증과 프로젝트 .jh-artifacts는 삭제하지 않습니다.
이전 버전으로 수동 복원할 때는 새 버전을 해제하고 빈 j-harness-core 위치에 출력된 원본 backup 폴더를 복원한 뒤 이전 bin/jh.cmd on 또는 off를 적용합니다.
목적지 충돌·지침 변조가 있으면 덮어쓰거나 재귀 삭제하지 말고 중지하세요.

## 5. 문제 확인과 지원 범위
doctor의 home / instructionTarget / effective / runtimeDrift / backupStatus를 확인하세요.
CONNECTED_FOR_NEW_SESSIONS는 파일 연결·해시 검사 결과이고, 실제 모델의 지침 준수를 자동 증명하지 않습니다.
다른 Windows PC·다른 Windows SID·ARM64 또는 다른 CLI를 검증한 것처럼 확대하지 않습니다. 구체적인 수용 시험 결과는 함께 제공한 ACCEPTANCE_KO.md를 확인하세요.

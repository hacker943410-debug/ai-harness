# Core 안정화 후보 업데이트·제거·복원
대상: 8.0.0-core-mvp.1 → 8.0.0-core-mvp.2 로컬 검토 후보. 공식 소유자 서명 릴리스가 아니다.
이 문서는 실행 승인이 아니다. 실제 사용자 설치본은 그대로 유지한다. 기존 패키지와 새 패키지를 모두 보관한다.

## 승인 전 확인
- 실제 CODEX_HOME과 기존 install.json, runtime inventory, 글로벌 AGENTS 대상/해시/외부 편집을 확인한다.
- 작업 중인 프로젝트를 기록하고 테스트를 마친 뒤 새 세션 경계에서 적용한다.
- 등록 Skill/skills-registry.json, 이전 projects 기록, lessons.json을 목록·해시로 확인한다. 인증파일과 config.toml은 복사/수정하지 않는다.
- archive/candidate/복구 대상의 절대 경로를 확인한다. 기존 사용자 파일·기록을 재귀 삭제하지 않는다.

## 승인 후 적용 순서
1. 기존 패키지에서 core/Uninstall-JHarnessCore.ps1 -CodexHome '<같은 홈>' 실행.
   관리 블록만 해제하고 j-harness-core.uninstalled-<시각>에 runtime·설정·원본 지침 백업·기록이 남는다. 이 archive 경로를 기록한다.
2. 새 패키지에서 core/Install-JHarnessCore.ps1 -CodexHome '<같은 홈>' 실행. -RegisterUserPath는 사용하지 않는다.
3. 사용자 확장이 있으면 이전 archive의 registered/와 skills-registry.json을 원래 해시대로 새 설치 루트에 복사해 보존한다.
   이전 projects/와 lessons.json도 필요하면 그대로 복사해 읽기 전용 역사로 사용한다. 원본 archive를 변경하지 않는다.
   목적지 충돌·해시 차이·미확인 커스텀 파일이 있으면 덮어쓰지 말고 중지한다.
4. jh doctor에서 mvp.2/CONNECTED_FOR_NEW_SESSIONS/backup MATCH 확인.
   status/doctor/skills list/search/read/policy read가 파일을 쓰지 않는지 확인하고, 새 Codex 세션 시작.
5. 실제 실행 기록은 프로젝트 .jh-artifacts/j-harness-core에 생성된다. 이전 전역 기록은 자동 정리·삭제하지 않는다.

## 제거
해당 새 패키지의 core/Uninstall-JHarnessCore.ps1 -CodexHome '<같은 홈>' 실행.
관리 지침만 해제하며 private runtime archive는 보관한다. 프로젝트 내부 .jh-artifacts는 삭제하지 않는다.
기존 CLI 설정/인증과 사용자가 관리 블록 밖에 추가한 지침을 유지한다.

## 이전 설치본으로 복원
1. 새 설치기를 다시 실행하지 말고, 새 패키지 제거기로 후보를 archive한다.
2. 활성 j-harness-core가 사라진 것을 확인한 후, 1단계에서 보관한 이전 archive를 같은 홈의 j-harness-core로 되돌린다.
   경로를 확인한 뒤 한 디렉터리만 rename/move하며 기존 폴더를 덮어쓰거나 삭제하지 않는다.
3. 복원한 이전 bin/jh.ps1 on으로 관리 블록을 다시 연결하고 doctor로 mvp.1/원래 runtime hash 확인.
   원래 OFF였으면 OFF를 유지한다.
4. 글로벌 지침의 관리 블록 밖 수정은 보존한다. 드리프트가 있으면 과거 전체 지침을 덮어쓰지 말고 중지한다.

임시 홈에서 등록 Skill·가짜 설정/인증·이전 기록을 포함한 업데이트→복원→제거를 실증한다.
현재 사용자 홈 적용은 NOT_RUN이며 별도 사용자 승인이 필요하다. 임의의 전원 장애/프로세스 중단을 자동 복구하는 새 updater를 구현한 것은 아니다.

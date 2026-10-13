# AI Harness v7.0 — 병합/릴리스 필수 검증 매트릭스

**결정 규칙:** `NOT_RUN`, `EVIDENCE_CONSISTENT_UNATTESTED`, `PASS_STATIC_ONLY`, `PASS_LOCAL_TOOLS_ONLY`는 실제 Studio 통합 검증 `PASS`가 아닙니다. 이 중 하나라도 라이브 필수 항목으로 남으면 **NO_GO**입니다.

| ID | 단계 | 실행 명령·조작 | 합격 증거 | 현재 검증 상태 |
|---|---|---|---|---|
| R01 | 정본 불변성 | HARNESS_VERSION / manifest / index / plugin / tag 대조 | 버전 일치 | 소스 7.0.0 일치; 태그는 병합 후 대조 |
| R02 | v6.2 호환성 | Node + PowerShell 회귀검사 | 전체 Exit 0 | GitHub CI 검증 가능 |
| R03 | Roblox capability 구조 | `node scripts/validate-roblox-v7.mjs` | 스키마·기본 DENY PASS | GitHub CI 검증 가능 |
| R04 | 명세·보안 테스트 | `node --test scripts/roblox/test-v7.mjs scripts/roblox/test-live-v7.mjs` | 오류 0 | GitHub CI 검증 가능 |
| R05 | 공식 MCP 등록 | `codex mcp list --json` | 단일 Roblox_Studio 항목 | PASS — 실제 등록 확인 |
| R06 | 실제 Studio 접속 | `list_roblox_studios` + `get_studio_state` | 실제 Place와 Session ID | PASS — 비공개 로컬 원본 확인 |
| R07 | 편집 전 복구점 | Studio Test Place 저장·Git commit | 실제 저장 버전/커밋 | PASS — 백업 및 소스 체크포인트 |
| R08 | Studio 편집 | 실제 `multi_edit`와 임시 객체 | 원본 MCP 결과 및 객체 조회 | PASS — 생성·수정·다시 읽기 |
| R09 | Studio Playtest | `start_stop_play` | 실행 결과, 종료 처리 | PASS — 실제 실행·종료 |
| R10 | 콘솔·시각 | `get_console_output`, `screen_capture` | 오류 내역·스크린샷 | PASS — 원본 로그·화면 검토 |
| R11 | Source Sync/복원 | Rojo·Git 비교/테스트 Place 복구 | Before/After Diff | PASS — 기록된 인벤토리·소스·저장 파일 일치 |
| R12 | 2클라이언트 | StudioTestService 또는 Studio 다중 플레이 | 실제 2플레이어 결과 | PASS — 2플레이어·서로 다른 클라이언트 핸드셰이크 |
| R13 | Local Tools | StyLua + Selene + Rojo build | 도구별 성공과 산출물 | PASS — 로컬 고정 버전 실행; 최종 CI 재검증 |
| R14 | 권한·보안 | 타인 세션·Unknown 도구·미승인 에셋 요청 거부 | 실제 거부 증거 | PASS — 범위 제한 검증 드라이버; 전체 대화형 통제 보장 아님 |
| R15 | 릴리스 | 별도 사용자 최종 승인 및 Main Merge → Tag | 태그가 병합 커밋을 가리킴 | R01–R14 이후 |

현재 7.0 릴리즈에서는 R05–R14의 실제 로컬 검증이 완료됐으며 사용자가 원본을 검토했습니다. 상세 범위는 [실기 검증 요약](LIVE_VERIFICATION_SUMMARY.md)과 [릴리즈 검토 기록](RELEASE_ACCEPTANCE.json)에 있습니다. R01–R04는 최종 7.0 버전 커밋의 CI에서 다시 검증하고, R15는 main 병합 후 태그/릴리즈를 대조합니다.

검증 단계별 제출 내용: 수행 PC의 OS/Node/Codex/Studio/Toolchain 버전, 테스트 Place 여부, Studio ID, 실제 도구 호출에 대한 **비공개 원본 증거 참조**, 오류·복구 확인, 실패/미실행 설명. 공개 PR에는 민감한 데이터와 원본 로컬 로그를 포함하지 않습니다.

기존 `verify-session.mjs`와 `verify-live-evidence.mjs`는 구조 검증기입니다. 원본 MCP 이벤트와 사용자의 실제 Studio 화면을 독립적으로 검증하지 못하기 때문에 `LIVE_STUDIO_VERIFIED`를 반환하지 않습니다.

### 자동 CI / 실제 PC 검증의 분리

로컬 실기 결과가 없는 상태에서 PR Actions가 녹색이어도 R05–R14를 통과했다고 판단하지 않습니다. **최종 병합은 명시적 사용자 승인과 현장 검증 완료 후에만** 실시합니다.

### v7.0 릴리스 업데이트 체계

v6.2.0 코어(26정책·JIT·Jev/토큰·안전한 설치/스냅샷)를 유지합니다. 릴리스 직전 단일 변경에서 버전/Manifest/Index/Claude Plugin/Marketplace를 `7.0.0`으로 동기화하고, v7 Validator의 버전 가드를 릴리스 상태로 전환합니다. 변경된 정확한 HEAD에서 다시 Windows·Linux CI를 실행해 통과를 확인한 뒤 병합합니다. 릴리스 태그 `v7.0.0`은 최종 main merge SHA로 생성합니다. 기존 태그를 덮어쓰지 않습니다.

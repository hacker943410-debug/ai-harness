# J Harness Core 실행 구조와 보장 범위

기존 v7·PR 원본·v8 Broker/MSI/OS 격리 소스는 그대로 보존한다. 이 Core는 별도 Node 모듈이며 해당 보안 실험을 설치하거나 기본 의존성으로 삼지 않는다. 기존 26개 정책은 원본 그대로 배포해 JIT 참고하고, 9개 범주·짧은 요약·원문 해시를 추가한다. v7의 beginner/briefing/project-mode/verification/token 노하우와 dashboard-builder를 재사용한다.

Codex 공식 글로벌 지침 선택 순서(CODEX_HOME의 nonempty AGENTS.override.md → AGENTS.md)를 따라 선택된 파일에 식별 가능한 관리 블록만 덧붙인다. config.toml, MCP 등록, 인증, 프로젝트 AGENTS는 바꾸지 않는다. OFF/해제는 정확히 자신의 블록만 제거한다. 내용이 편집돼 경계를 확인할 수 없으면 원문을 보존하고 오류로 중단한다. 큰 글로벌 지침은 설치를 거부하며, 세부 context limit/프로젝트 override에 의한 동작 차이는 doctor와 실제 세션 관측으로 구분해야 한다.

상태는 configured ON/OFF, effective CONNECTED/OFF/NOT_CONNECTED/BROKEN, model application 미관측을 구분한다. 파일 연결만으로 실제 모델이 절차를 수행했다고 주장하지 않는다. 지침은 새 세션 시작에 로드되므로 기존 세션의 즉시 소멸을 보장하지 않는다. cooperative Core에서는 AI가 같은 사용자 권한으로 파일을 고의 수정하거나 일반 CLI를 직접 실행하는 것을 완전 차단하지 않는다. 이것은 이전 Windows 보안 제품의 실패 게이트와 별개의 수용 범위다.

워크플로는 analysis → plan → implement → verify → handoff다. 실패한 검증에서 implement로 돌아가는 복구 루프를 허용한다. 검증은 shell 문자열 대신 argv로 실행하고 timeout/종료 코드/대상 전후 해시/stdout·stderr 해시를 기록한다. 중요한 shell/download 명령은 verifier의 대상이 아니다. arbitrary test script의 모든 부작용을 OS 수준으로 차단하는 장치는 아니므로 기존 CLI 승인 정책과 사용자 범위 결정을 유지한다.

project fingerprint는 .git/node_modules/data/환경·인증·개인키 이름을 제외한 코드/문서 범위다. 데이터 디렉터리나 제외한 환경 파일까지 검증됐다고 주장하지 않는다. record 저장소는 사용자 권한의 로컬 폴더이며 독립 Vault가 아니다. provider token 사용량은 미계측이면 null, bytes/4는 ESTIMATE다.

Skills 허브는 내장·재사용·설치 발견·명시적 검토 등록을 구분한다. 검색/metadata 조회는 원격 실행이 아니다. 등록은 HTTPS 출처 참조 + 로컬 콘텐츠 hash + 명시적 CLI 검토 플래그가 필요하고 자동 다운로드/스크립트 실행이 없다. content 조회·Agent APPLIED 주장·실제 검증 명령을 별도 이벤트로 남긴다. generic Skill 엔진이나 원격 MCP 실행기를 새로 만들지 않는다.

Codex만 구현했다. Claude Code와 AGY는 NOT_IMPLEMENTED이며 동일한 메뉴/정책을 적용했다고 표시하지 않는다. Codex에서 실제 모델 수용 검증 이후 각 CLI 공식 지침/Skills/인증 지원을 확인해 별도 어댑터를 구현해야 한다. 현재 CLI 자동 선택 메뉴, 모델 선택, 정책 편집 메뉴는 없다.

공식 확인 근거:

- [글로벌 AGENTS 지침과 override/새 세션](https://learn.chatgpt.com/docs/agent-configuration/agents-md)
- [Skills의 점진적 로딩과 발견 위치](https://learn.chatgpt.com/docs/build-skills)
- [Codex exec JSON 이벤트·usage·인증](https://learn.chatgpt.com/docs/non-interactive-mode)
- [커스텀 provider 설정](https://learn.chatgpt.com/docs/config-file/config-advanced)
- [로컬 provider의 무인증 설정](https://learn.chatgpt.com/docs/auth)

로컬 진단은 실제 Codex 0.166.0을 실행하지만 모델 transport는 loopback 모의 응답이다. 인증·외부 모델 호출·비용 없이 실제 글로벌 지침이 요청에 들어가는지만 검증한다. 이 mock usage 0을 실제 token 사용량으로 기록하지 않는다. 진단은 도구 호출을 반환하지 않으며 임시 홈만 사용한다. 실제 모델 A~E는 사용자 선택에 따라 NOT_RUN이다.

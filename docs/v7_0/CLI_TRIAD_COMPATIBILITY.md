# AI Harness v7.0.1 Candidate — Codex / Claude / AGY 3-CLI 호환성 계약

**기준:** 2026-10-16. 정식 안정 버전은 `v7.0.0`이며 `fix/v7.0.1-cli-triad`는 미병합 패치 후보입니다.

## 현재 소스의 사실과 개선점

- `settings/clients/codex.client.json`, `claude.client.json`, `agy.client.json` 3개가 이미 존재하며 `gemini.client.json`은 존재하지 않습니다.
- Codex와 AGY는 프로젝트의 공통 `AGENTS.md` 및 `.agents/skills/`를 사용합니다. Claude Code는 `CLAUDE.md`와 `.claude/skills/`를 사용합니다.
- v7.0은 `CLAUDE.md`가 **이미 존재하면 관리 블록을 갱신하지만**, 존재하지 않으면 새로 만들지 않습니다. 세 CLI 동시 사용에는 명시적인 생성 경로가 필요합니다.
- `PROJECT_INIT.md`의 맨 아래 v5 호환성 참고 자료에 `Gemini CLI → GEMINI.md`가 남아 있습니다. 이는 현재 운영 전략이 아니라 **레거시 진단용 문서**입니다. 기존 `GEMINI.md`의 사용자 고유 규칙을 자동 삭제하지 않습니다.
- Codex 관리형 `harness-guard-v6-2.mjs`는 **Codex 전용**입니다. Claude와 AGY가 동일 수준의 토큰 예산 강제, 실행 후 게이트, Model 자동 전환을 제공한다고 주장하지 않습니다.
- 모델은 CLI와 다릅니다. AGY에서도 Gemini 모델을 사용할 수 있지만 Gemini CLI 실행 파일은 사용하지 않습니다.

## 이 패치에서 구현한 내용

- 선택형 `--clients codex,claude,agy` 프로젝트 계획 옵션 추가.
- 요청된 세 CLI 조합이 있을 때 새 `CLAUDE.md`에 **얇은 관리 블록**을 생성. 기본 계획에는 영향이 없으며 `AGENTS.md`는 기존처럼 생성.
- 설치 파일/기존 사용자 규칙을 보존하고, 해시·변경 계획·롤백 검사에 `CLAUDE.md` 추가를 반영.
- `gemini`를 새 클라이언트 대상으로 지정하면 사전 차단. **기존** `GEMINI.md`는 유지.
- 오프라인 CLI 어댑터 검사와 실제 설치 프로젝트를 사용하는 Node 회귀 테스트 추가.

## 안전한 프로젝트 적용 명령 (별도 앱 프로젝트에서만)

```powershell
# 정식 릴리스 전 후보를 운영 프로젝트에 적용하지 마세요.
# 미배포 브랜치에서는 검증용 임시 프로젝트만 사용하세요.

# 승인된 불변 릴리스 Snapshot이 마련되면:
node scripts/harness-v6.mjs inspect --project C:/Projects/YourProject

node scripts/harness-v6.mjs plan \
  --project C:/Projects/YourProject \
  --request "AI Harness 3개 CLI 연결" \
  --clients codex,claude,agy \
  --out C:/Projects/YourProject/.ai/cli-triad-plan.json

# 출력된 계획/검증 명령/기존 변경사항/복구점을 검토하고 승인한 이후에만:
node scripts/harness-v6.mjs apply --plan C:/Projects/YourProject/.ai/cli-triad-plan.json
node scripts/harness-v6.mjs verify --project C:/Projects/YourProject
```

PowerShell에서는 위의 줄 연결 `\` 표기가 아닌 **백틱** (`\`가 아니라 역따옴표)을 사용하거나, 아래처럼 한 줄로 실행하세요.

```powershell
node scripts/harness-v6.mjs plan --project C:/Projects/YourProject --request "AI Harness 3개 CLI 연결" --clients codex,claude,agy --out C:/Projects/YourProject/.ai/cli-triad-plan.json
```

**이 작업은 CLI 설치/로그인 또는 유료 모델 호출이 아닙니다.** 각 CLI의 실제 인증과 실행 여부는 PC에서 확인해야 합니다.

## 프로젝트에서 CLI별 실사용 검증 (실제 PC, 읽기 우선)

| 검사 | Codex | Claude Code | AGY CLI |
|---|---|---|---|
| 설치/버전 | `codex --version` | `claude --version` | `agy --version` |
| 프로젝트 진입 | `codex` | `claude` | `agy` |
| 규칙 진입 | `AGENTS.md` | `CLAUDE.md` | `AGENTS.md` |
| Skill 경로 | `.agents/skills/` | `.claude/skills/` | `.agents/skills/` |
| MCP 등록 조회 | `codex mcp list --json` | `claude mcp list` | `agy mcp list` |
| 실제 모델·권한 | 직접 세션 내 확인 필수 | 직접 세션 내 확인 필수 | 직접 세션 내 확인 필수 |
| 기존 Harness 관리형 Guard | Codex `exec` 경로에만 존재 | 미지원 | 미지원 |

검증 시점의 CLI 버전, 로그인 여부, 관리 지침 인식 여부, Skill 발견, MCP 실제 호출, 설치한 도구의 권한 거부 동작을 각 CLI에서 별도 기록하십시오. 정적 Descriptor PASS는 실행 중인 모델의 정책 준수 PASS가 아닙니다.

### AGY 주의사항
1. **Gemini CLI 설정을 그대로 복사하지 않습니다.** AGY는 별도 CLI이고 인증/모델/MCP 설정 스키마가 다릅니다.
2. 현재 Harness AGY Descriptor는 MCP의 도구별 deny/approve를 강제할 수 없다고 기록합니다(2026-08-23 검증). 서버 단위 비활성화/격리 프로필을 우선 적용하고 `--dangerously-skip-permissions`는 사용하지 않습니다. CLI 버전별 실제 지원 범위를 다시 확인하십시오.
3. 기존 사용자 설정이나 `GEMINI.md`를 자동 변환/삭제하지 않습니다. **`agy plugin import gemini` 역시 사용자가 별도로 검토하고 승인한 경우에만** 실행합니다.
4. AGY에 대해 `AGENTS.md` 자동 인식과 하위 문서 JIT 로딩이 매 턴 보장된다고 가정하지 않습니다. 읽은 파일 경로를 실제 세션 출력으로 증빙합니다.
5. Google의 공식 Codelab에서 AGY 프로젝트 Skill 경로 `.agents/skills`를 확인할 수 있습니다.
   https://codelabs.developers.google.com/antigravity/how-to-create-agent-skills-for-antigravity-cli

## 릴리스 전 검증·GO/NO-GO

- `node scripts/check-cli-triad-v7.mjs` → `STATIC_PASS` (소스 계약만).
- `node --test scripts/test-cli-triad-v7.mjs` → 신규·기존 프로젝트 및 원본 보존 테스트.
- `node --test scripts/test-harness-v6.mjs`, `node scripts/validate-harness-v6.mjs`, `node scripts/validate-release-v7.mjs` → 기존 v7.0.0 호환성.
- `scripts/Test-HarnessRelease.ps1` 및 `scripts/Test-ProjectSkillInstall.ps1` → Windows 실제 Powershell 설치/Skill 무결성 검증.
- 마지막으로 실제 PC에서 **Codex/Claude/AGY 각 CLI가** 해당 지침을 읽고 무해한 테스트 요청에 답하는지 확인. MCP 등록 성공은 실제 호출을 의미하지 않습니다.
- 현재는 소스/테스트 패치 후보일 뿐, 실제 CLI 3종 E2E를 완료한 것이 아니므로 정식 3/3 호환성 GO를 선언하지 않습니다.
- 정식 릴리스 전 `7.0.1` 버전·manifest/index/plugin/marketplace 태그를 한 번에 정합시킨 후, 최종 HEAD CI 통과 및 명시적 병합 승인 필요. 기존 `v7.0.0`은 변경 금지.

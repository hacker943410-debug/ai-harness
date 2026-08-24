# ai-harness — Claude Code 플러그인

이 플러그인은 **정본이 아니다.** 저장소 루트(Layer A)의 파일을 가리키는 얇은 진입점이다.

```
HARNESS_ROOT = ${CLAUDE_PLUGIN_ROOT}/../..
```

## 설치

```text
/plugin marketplace add <owner>/ai-harness
/plugin install ai-harness@ai-harness
```

## 제공하는 것

| 이름 | 하는 일 | 가리키는 정본 |
|---|---|---|
| `/harness-init` | 현재 프로젝트 초기화 (최초 1회) | `PROJECT_INIT.md` |
| `/harness-doctor` | Read-only 운영 진단 | `HARNESS_DOCTOR.md` |
| `/harness-status` | 저장소·이 PC 상태 점검 (읽기 전용) | `scripts/*.ps1` |
| Skill `harness-runtime` | 공용 런타임 수명주기 | `workflows/SHARED_RUNTIME.md` |
| Skill `harness-capability` | Capability 획득 절차 | `workflows/CAPABILITY_ACQUISITION.md` |

## 설계 제약

1. **정책 원문을 복사하지 않는다.** 26개 정책은 `policies/` 에만 있고 JIT 로 읽는다.
   플러그인이 원문을 담으면 마스터가 둘로 갈라진다.

2. **플러그인은 `PROJECT_INIT.md` 를 대체하지 않는다.**
   Codex 와 AGY 에는 이 메커니즘이 없다. 플러그인이 정본이 되면 그 사용자들이 뒤처진다.
   플러그인은 "Claude Code 사용자만 한 단계 더 편해지는 추가 채널"이다.

3. **`.mcp.json` 을 넣지 않는다.**
   공용 런타임의 실체는 Layer B(`%LOCALAPPDATA%\AI-Tools`)에 있고 경로가 PC 마다 다르다.
   플러그인에서 등록하려면 절대경로가 필요하고, 무엇보다 등록 경로가
   `Register-HarnessRuntimeClient.ps1` 과 둘로 갈라져 **"적용하는 문은 하나" 규칙이 깨진다.**
   등록은 계속 하네스 스크립트가 담당한다.

4. **절대경로를 쓰지 않는다.** 모든 참조는 `${CLAUDE_PLUGIN_ROOT}` 기준 상대 경로다.

## 버전

`plugin.json` 의 `version` 은 하네스 버전을 따라간다.
하네스 버전의 Canonical Source 는 `POLICY_INDEX.yaml` 의 `harness_version` 이다.
두 곳을 함께 올린다.

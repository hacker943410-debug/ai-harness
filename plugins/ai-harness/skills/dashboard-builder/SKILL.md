---
name: dashboard-builder
description: AI Harness v5의 공용 dashboard-builder Skill을 Claude Code에서 호출하는 얇은 wrapper.
---

# Dashboard Builder — Harness Wrapper

이 파일은 정본을 복제하지 않는다.

현재 플러그인 루트를 기준으로 저장소 루트의 다음 파일을 읽고 그대로 따른다.

```text
${CLAUDE_PLUGIN_ROOT}/../../skills/dashboard-builder/SKILL.md
```

그 Skill이 JIT로 요구하는 `references/`, `templates/`, `scripts/`도 같은 저장소 루트 `skills/dashboard-builder/` 아래의 정본을 사용한다.

상위 `CORE.md`, `ROUTER.md`, 현재 프로젝트 규칙과 충돌하면 상위 계약을 따른다.

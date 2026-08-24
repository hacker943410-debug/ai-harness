---
description: 쓸 수 있는 도구를 하나씩 설명받고 깔지 말지 직접 고른다 (설치 에스코트)
argument-hint: "[프로필 id — 생략 시 질문부터]"
allowed-tools: Bash, Read
---

# 설치 에스코트

```
HARNESS_ROOT = ${CLAUDE_PLUGIN_ROOT}/../..
```

## 할 일

에스코트는 **대화형 PowerShell 스크립트**다. AI 가 대신 답하지 않는다.
사용자가 직접 답해야 하므로, 이 명령은 스크립트를 실행하는 것이 아니라 **어떻게 실행할지 안내**한다.

1. `<HARNESS_ROOT>/workflows/ESCORT.md` 를 읽어 흐름을 파악한다.
2. 사용자에게 아래 명령을 그대로 제시하고, 터미널에서 직접 실행하도록 안내한다.
   Claude Code 라면 `!` 접두사로 이 세션에서 바로 돌릴 수 있다고 알려준다.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File '<HARNESS_ROOT>\scripts\Invoke-HarnessEscort.ps1' -SavePlan .\escort.json
```

3. 사용자 추가 지시가 있으면 `-ProfileId` 로 넘긴다: $ARGUMENTS

## 읽기 전용으로 먼저 보여줄 수 있는 것

사용자가 "일단 뭐가 있는지만 보자" 라고 하면 이건 AI 가 직접 돌려서 보여줘도 된다.

```powershell
... -File '<HARNESS_ROOT>\scripts\Invoke-HarnessEscort.ps1' -List
... -File '<HARNESS_ROOT>\scripts\Invoke-HarnessEscort.ps1' -Explain <번호 또는 id>
... -File '<HARNESS_ROOT>\scripts\Invoke-HarnessEscort.ps1' -Tips
```

## 끝난 뒤

에스코트는 계획 파일만 만든다. 적용은 별개다.

```powershell
... -File '<HARNESS_ROOT>\scripts\Install-Harness.ps1' -Plan .\escort.json -DryRun   # 실행될 명령 확인
... -File '<HARNESS_ROOT>\scripts\Install-Harness.ps1' -Plan .\escort.json           # 확인 후 적용
```

**사용자 대신 설치 여부를 결정하지 않는다.** 에스코트의 목적이 "사용자가 알고 고르는 것"이므로,
AI 가 대신 y 를 눌러주면 기능 자체가 무의미해진다.

---
description: 하네스 저장소와 이 PC 의 상태를 읽기 전용으로 점검한다
allowed-tools: Bash, Read, Glob, Grep
---

# Harness Status — 읽기 전용

아래 명령은 **전부 읽기 전용**이다. 아무것도 바꾸지 않는다.
바꾸는 것은 `Install-Harness.ps1` 하나뿐이며 그것은 이 명령이 부르지 않는다.

```
HARNESS_ROOT = ${CLAUDE_PLUGIN_ROOT}/../..
```

## 할 일

`HARNESS_ROOT` 를 위 식으로 확정한 뒤, 다음을 순서대로 실행하고 결과를 요약한다.

```powershell
# 1. Layer A — 저장소 계약 (11개 규칙군)
powershell -NoProfile -ExecutionPolicy Bypass -File '<HARNESS_ROOT>\scripts\Test-HarnessRepo.ps1'

# 2. Layer B — 이 PC 의 실체
powershell -NoProfile -ExecutionPolicy Bypass -File '<HARNESS_ROOT>\scripts\Get-HarnessEnvironment.ps1'
powershell -NoProfile -ExecutionPolicy Bypass -File '<HARNESS_ROOT>\scripts\Sync-HarnessClients.ps1'

# 3. git
git -C '<HARNESS_ROOT>' status --short
git -C '<HARNESS_ROOT>' log --oneline -5
```

Windows 가 아니면 PowerShell 스크립트는 건너뛰고 그 사실을 명시한다. 통과했다고 말하지 않는다.

## 보고 방법

- `installed` / `registered` / `authenticated` / `verified` 를 **구분해서** 보고한다.
  넷은 다른 상태다. 파일이 있다는 것은 `verified` 가 아니다.
- 무언가 어긋나 있으면 **무엇을 어떻게 바꾸면 되는지**까지 쓰되, **바꾸지는 않는다.**
  적용은 계획 파일 → 사용자 검토 → `Install-Harness.ps1` 순서를 반드시 거친다.
- 이미 사용자가 거절한 제안은 다시 올리지 않는다. 진단기가 계속 제시하더라도 그대로 넘긴다.

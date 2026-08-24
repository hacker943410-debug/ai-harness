---
name: harness-runtime
description: AI Harness 공용 런타임(MCP 서버 등)을 설치·인증·검증·등록하거나 문제를 고칠 때 쓴다. "MCP 서버가 안 뜬다", "google-workspace 인증이 풀렸다", "새 PC 에 런타임을 깔아야 한다", "클라이언트 등록이 어긋났다", 런타임 버전 변경·롤백·권한 취소 상황에 사용한다.
---

# 공용 런타임 수명주기

```
HARNESS_ROOT = ${CLAUDE_PLUGIN_ROOT}/../..
```

## 먼저 읽는다

- `<HARNESS_ROOT>/workflows/SHARED_RUNTIME.md` — 수명주기 정본
- 해당 런타임의 `<HARNESS_ROOT>/runtimes/<id>.runtime.json` — 무엇을 어떤 버전으로

이 SKILL 은 절차를 **요약**할 뿐 정본이 아니다. 충돌하면 위 파일이 이긴다.

## 순서

```
install → auth → verify → sync → restart
```

| 단계 | 스크립트 | 성격 |
|---|---|---|
| 해석 | `Resolve-HarnessRuntime.ps1` | 읽기 전용 |
| 설치 / 채택 | `Install-HarnessRuntime.ps1` (`-Adopt`) | 변경 |
| 인증 | `Connect-HarnessRuntimeAuth.ps1` | 변경 |
| 검증 | `Test-HarnessRuntime.ps1` | 읽기 전용. 전송 검증과 인증 검증을 분리한다 |
| 등록 정합 | `Sync-HarnessClients.ps1` | 읽기 전용 + 계획 생성 |
| 등록 | `Register-HarnessRuntimeClient.ps1` | 변경. 등록 후 **되읽어** 확인한다 |
| 사고 대응 | `Disconnect-HarnessRuntime.ps1` | 권한취소 → 토큰삭제 → 등록제거 → state 되돌림 |

## 반드시 지킬 것

1. **Layer 를 섞지 않는다.**
   - `runtimes/*.runtime.json`(Layer A)에는 **설치 위치를 적지 않는다.** 무엇을·어떤 버전으로만.
   - 실제 설치 경로·토큰·지문은 Layer B(`<tools_root>` 의 `runtimes.json` / `clients.json`)에 있다.
   - 이 두 파일은 **커밋 대상이 아니다.** pre-commit 훅이 경로 이름으로 차단한다.

2. **바꾸는 문은 하나다.**
   진단이 계획 파일(`harness-change-plan v1.0`)을 내고, 사용자가 `enabled` 를 편집하고,
   `Install-Harness.ps1` 이 확인 후 적용하며 롤백 저널을 남긴다.
   이 순서를 건너뛰는 경로를 새로 만들지 않는다.

3. **상태를 주장하지 않고 증명한다.**
   `installed ≠ registered ≠ authenticated ≠ verified`.
   파일이 존재한다는 것은 인증됐다는 뜻이 아니다. 사용자가 콘솔에서 권한을 취소해도 파일은 남는다.
   실제 API 를 한 번 호출한 증거만 `verified` 로 인정한다.

4. **살아있는 도구 설정은 확인 없이 바꾸지 않는다.**
   AI CLI 의 MCP 등록, 사용자 환경변수, 공용 도구 루트가 여기 해당한다.
   진단(읽기 전용) → 무엇이 어떻게 바뀌는지 제시 → 확인 → 적용.

5. **완화를 적용했으면 이미 떠 있는 세션도 센다.**
   `disable` 류 명령은 대개 **새 세션에만** 적용된다. 살아 있는 세션은 계속 노출된 상태다.

## 롤백

설치 디렉터리를 버전별로 두고 `command_rel` 이 활성 버전을 가리킨다.
롤백은 재다운로드가 아니라 **포인터 전환**이다.

토큰 스냅샷은 기본적으로 만들지 않는다. 사본 하나가 늘면 유출 표면이 하나 는다.
토큰 포맷이 실제로 바뀌는 런타임만 매니페스트에 `credentials.state_format_version` 을 선언하고,
맞지 않으면 `verified` 를 쓰지 않고 **재인증을 명시적으로 요구**한다.

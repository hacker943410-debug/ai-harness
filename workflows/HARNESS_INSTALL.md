# AI Harness — 최초 설치 가이드 (PC 환경별)

Document Version: 1.0
Layer: A (git 추적)
대상: 이 하네스를 **처음 받는 PC**에 설치하는 사람
소요: 진단 1분 / 적용 2~5분 / 런타임 설치는 별도 (npm 다운로드 수 분)

> **이 문서의 원칙: 진단 → 확인 → 적용.**
> 설치 스크립트가 이 PC 환경을 먼저 읽고, **무엇을 바꿀지 제안만** 한다.
> 사용자가 보고 결정한 뒤에 적용한다. 확인 없이 바뀌는 것은 없다.

---

## 0. 무엇이 바뀌는가 — 전체 목록

적용을 시작하기 전에 이 표 하나로 영향 범위를 다 볼 수 있어야 한다.

| 대상 | 변경 | 되돌리기 |
|---|---|---|
| `<도구 루트>` (기본 `%LOCALAPPDATA%\AI-Tools`) | 디렉터리 생성 + ACL 제한 | 디렉터리 삭제 |
| 사용자 환경변수 `AI_HARNESS_TOOLS_ROOT` | 설정 | 삭제 또는 이전 값 복원 |
| 사용자 환경변수 `AI_HARNESS_GOOGLE_MCP_COMMAND` | **설정하지 않는다** (v2.2 에서 은퇴). 값이 남아 있으면 삭제를 제안 | 이전 값 복원 (롤백 저널) |
| `<도구 루트>\runtimes.json` / `clients.json` | 생성·갱신 | 파일 삭제 |
| `<도구 루트>\<런타임>\<버전>\` | npm 패키지 설치 (수십~수백 MB) | 디렉터리 삭제 |
| 각 AI CLI 의 MCP 설정 | 서버 1개 등록 | `<cli> mcp remove <이름>` |
| 하네스 저장소의 `core.hooksPath` | `.githooks` 로 설정 | `git config --unset core.hooksPath` |
| **OAuth 토큰** | 설치는 만들지 않음. 별도 로그인 단계에서 생성 | 계정에서 권한 취소 + 파일 삭제 |

**설치가 건드리지 않는 것:** 프로젝트 소스 코드, 기존 프로젝트 설정, 시스템 전역 설정, 다른 Windows 사용자 계정.

**관리자 권한은 필요 없다.** 전부 사용자 범위다.

**하네스가 대신 해 줄 수 없는 것도 있다.** 어떤 CLI 는 우리가 선언한 도구 통제를
강제할 수단 자체가 없다. 그런 것은 숨기지 않고 진단 단계에서 선택지와 함께 제시하며,
진행 여부는 사용자가 정한다 (§4.7).

**무슨 도구를 쓸지는 이 표에 없다.** 위 표는 하네스 자체를 이 PC 에 맞추는 범위다.
어떤 MCP·Skill 을 쓸지는 별개의 결정이고, 카탈로그에 109개가 있다.
목록만 보고 고르기 어려우면 설치 에스코트가 하나씩 설명하고 물어본다 — **§5.0b**.

---

## 1. 사전 조건

| 항목 | 요구 | 확인 |
|---|---|---|
| Windows | 10/11 | — |
| PowerShell | Windows PowerShell **5.1 이상**이면 충분 | `$PSVersionTable.PSVersion` |
| Node.js | **22 이상** | `node --version` |
| npm | Node 동봉 | `npm.cmd --version` |
| git | 필요 (클론·갱신·비밀값 가드) | `git --version` |

> **macOS / Linux 는 현재 지원하지 않는다.** 스크립트는 PowerShell 로 작성돼 있고 PowerShell 7 에서의 동작이 검증되지 않았다. 매니페스트의 `platforms` 도 `["windows"]` 로 정직하게 선언돼 있다.

---

## 2. STEP 0 — 하네스 받기

### 2.1 폴더 선택이 중요하다

클론 위치를 아무 데나 잡으면 나중에 원인 찾기 어려운 문제가 생긴다.

| 피할 것 | 이유 |
|---|---|
| 경로에 **비ASCII 문자** (한글 등) | 콘솔 코드페이지에 따라 경로가 깨진다. `.cmd` 런처 생성은 아예 거부된다 |
| 경로에 `& ( ) ^ % !` | `.cmd` 래퍼에서 깨진다 |
| **OneDrive / Dropbox 동기화 폴더** | 설정·상태 파일이 의도치 않게 동기화된다 |
| 매우 깊은 경로 | `node_modules` 는 경로가 깊다. MAX_PATH 에 걸린다 |
| 네트워크 드라이브 / UNC | npm 설치가 느리거나 실패한다 |

권장: `%LOCALAPPDATA%\AI-Harness` 또는 `C:\dev\ai-harness` 같은 **짧고 ASCII 인** 경로.

### 2.2 받기 — 한 줄이면 된다

```powershell
irm https://raw.githubusercontent.com/hacker943410-debug/ai-harness/main/install.ps1 | iex
```

`install.ps1` 이 사전 조건 확인 → 경로 검증(§2.1 규칙) → 클론 → 비밀값 가드 → 저장소 검사까지 한다.
**받기만 한다.** 도구 루트를 만들거나 MCP 를 설치·등록·인증하지 않는다. 그건 STEP 2 다.

위치를 바꾸려면 (`irm | iex` 는 인자를 못 넘긴다):

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/hacker943410-debug/ai-harness/main/install.ps1))) -Path 'C:\dev\ai-harness'
```

기본 위치는 `%LOCALAPPDATA%\AI-Harness` 다.

> 실행 전에 내용을 보고 싶으면 위 URL 을 브라우저로 열면 된다. 그게 이 방식을 쓰는 이유다.
> 받은 것을 실행하기 전에 읽을 수 있어야 한다.

**같은 한 줄이 업데이트다.** 이미 있으면 clone 대신 갱신한다.

| 상태 | 동작 |
|---|---|
| 없음 | 최신 태그로 clone (detached) |
| 있음, detached | fetch 후 최신 태그로 이동 |
| 있음, 브랜치 위 | `--ff-only` 로 fast-forward. **태그로 옮기지 않는다** — 작업용 클론이므로 |
| 커밋 안 한 변경 있음 | **아무것도 하지 않고 멈춘다** |
| origin 보다 앞서 있음 | **아무것도 하지 않고 멈춘다** (개발 중인 PC) |

#### 손으로 하려면

```powershell
git -c core.autocrlf=false -c core.longpaths=true clone `
    --branch v3.0.0 `
    https://github.com/hacker943410-debug/ai-harness.git `
    "$env:LOCALAPPDATA\AI-Harness"

git -C "$env:LOCALAPPDATA\AI-Harness" config core.hooksPath .githooks
```

> **태그를 지정한다.** 핀 고정을 강제하는 도구가 정작 자기 자신은 떠다니는 HEAD 로 받으면 앞뒤가 맞지 않는다.
> 최신 태그는 `git ls-remote --tags` 로 확인한다. `install.ps1` 은 이것을 원격에서 읽으므로 버전이 박혀 있지 않다.
> 받은 뒤 `git -C <경로> rev-parse HEAD` 로 커밋 SHA 를 기록해 두면 나중에 문제 추적이 쉽다.

---

## 3. STEP 1 — 환경 진단 (읽기 전용)

```powershell
powershell -NoProfile -ExecutionPolicy Bypass `
    -File "$env:LOCALAPPDATA\AI-Harness\scripts\Get-HarnessEnvironment.ps1"
```

**이 명령이 하는 일:** 읽기만 한다. 파일을 만들지도, 환경변수를 바꾸지도, 네트워크를 쓰지도 않는다.
(`-Detailed` 를 붙이면 `npm config get` 을 호출하므로 npm 이 캐시 디렉터리를 만들 수 있다.)

### 3.1 왜 `-NoProfile -ExecutionPolicy Bypass` 인가

- 신규 Windows 는 `LocalMachine` 정책이 **Restricted** 다. `.\script.ps1` 은 바로 실패한다.
- 명령줄의 `-ExecutionPolicy Bypass` 는 정책을 **영구 변경하지 않는다.** 이 프로세스에만 적용된다.
- `-NoProfile` 은 사용자 프로필 스크립트가 환경을 오염시키는 것을 막는다.

**단, 조직 정책(GPO)이 걸려 있으면 `Bypass` 자체가 무시된다.** 진단 출력의 `ExecutionPolicy(범위별)`에서 `MachinePolicy` 또는 `UserPolicy` 가 `Undefined` 가 아니면 그 경우다. → §11 참고.

### 3.2 종료 코드

| 코드 | 뜻 |
|---|---|
| 0 | 바로 진행 가능 |
| 2 | 경고 있음. 진행 가능하지만 §4 를 읽을 것 |
| 3 | 차단 요소 있음. 해결 전에는 진행 불가 |

---

## 4. 진단 결과별 대응

진단이 출력하는 항목과, 그 값에 따라 해야 할 일이다.

### 4.1 host

| 항목 | 값 | 대응 |
|---|---|---|
| `PowerShell` | `Desktop 5.1.x` | 정상. 그대로 진행 |
| `pwsh (PS7)` | 없음 | Windows 전용으로 동작. 문제 없음 |
| `LanguageMode` | `FullLanguage` 아님 | **차단.** 제한 언어 모드에서는 설치 스크립트가 동작하지 않는다. 조직 정책 확인 필요 |
| `ExecutionPolicy` | `Restricted`/`AllSigned` | 위 방식(`-ExecutionPolicy Bypass`)으로 실행하면 된다 |
| `관리자 권한` | False | 정상. 필요 없다 |

### 4.2 encoding

| 항목 | 값 | 대응 |
|---|---|---|
| `ANSI 코드페이지` | `949`, `1252` 등 (65001 아님) | 하네스가 모든 `.ps1` 을 UTF-8 BOM 으로 관리하므로 문제 없다. **단 직접 스크립트를 추가할 때 BOM 없이 저장하면 한글이 깨진다** |
| `OEM 코드페이지` | 65001 아님 | 네이티브 CLI 출력 캡처 시 영향. 하네스 스크립트는 `Initialize-HarnessConsole` 로 처리한다 |

> **직접 파일을 만들 때:** JSON 은 **BOM 없이**, `.ps1` 은 **BOM 있게**. 반대로 하면 각각 npm/Node 가 거부하거나 한글이 깨진다.
> PowerShell 의 `Set-Content`/`Out-File` 은 이 규칙을 지키지 못한다. `Write-HarnessJson` / `Write-HarnessText` 를 쓸 것.

### 4.3 path

| 항목 | 값 | 대응 |
|---|---|---|
| `USERPROFILE` / `LOCALAPPDATA` | 비ASCII 포함 | 도구 루트를 ASCII 경로로 지정: `-ToolsRoot 'C:\AI-Tools-Local'` 같이. `.cmd` 런처 생성은 거부된다 |
| `OneDrive 리디렉션` | 표시됨 | 홈이 클라우드 동기화 아래다. **자격증명 파일이 동기화될 수 있으므로** 프로필 경로를 반드시 확인 |
| `긴 경로 지원` | False | 도구 루트를 **짧은 경로**에 둔다. 깊은 경로에서는 `npm install` 이 조용히 불완전하게 끝날 수 있다 |

> 긴 경로 미지원 + 깊은 도구 루트 조합은 특히 위험하다. `New-Item` 은 MAX_PATH 를 넘어도 **예외 없이 성공한 것처럼 보인다.** 하네스는 설치 후 `node_modules` 존재를 실제로 확인한다.

### 4.4 toolchain

| 항목 | 대응 |
|---|---|
| `Node.js` 없음 또는 22 미만 | **차단.** 설치/업그레이드 후 재실행 |
| `npm` 없음 | **차단** |
| `git` 없음 | 경고. 하네스 갱신과 비밀값 가드를 쓸 수 없다 |
| `npm proxy` 표시됨 | 사내 프록시 환경. §11 의 `E401`/`E404` 항목 참고 |

> **`npm` 은 PATH 에서 `npm.ps1` 로 먼저 잡힌다.** `.ps1` 은 ExecutionPolicy 의 지배를 받으므로 Restricted 환경에서 `npm -v` 는 `PSSecurityException` 으로 죽고 `npm.cmd -v` 는 정상 동작한다. 하네스 스크립트는 항상 `.cmd`/`.exe` 를 우선 해석한다. **수동으로 명령을 칠 때도 `npm.cmd` 를 쓰는 편이 안전하다.**

### 4.5 tools_root

| 항목 | 대응 |
|---|---|
| `기존 디렉터리: C:\AI-Tools` + `위험: Authenticated Users` | **중요.** `C:\` 바로 아래 폴더는 다른 로컬 사용자가 쓸 수 있는 권한을 상속받는다. 그 폴더의 MCP 실행 파일이 교체되면 다음 실행 때 사용자 권한으로 실행된다. 진단이 ACL 제한을 제안한다 |
| 기존 설치 존재 | §7 (업그레이드) 로 |

### 4.6 client

| 항목 | 대응 |
|---|---|
| `미설치` | 그 CLI 는 건너뛴다. 나중에 설치한 뒤 `Register-HarnessRuntimeClient.ps1` 만 실행하면 된다 |
| `이미 등록된 하네스 서버: ...` | 정상 |
| `원장에는 등록, 실제로는 없음` | **등록이 외부 요인으로 사라졌다.** 재등록 필요 |
| `관리형 설정 홈` 경고 | 외부 도구가 그 CLI 의 설정 파일을 소유한다. **하네스가 넣은 등록이 나중에 지워질 수 있다.** 작업 시작 시 등록 상태를 다시 확인해야 한다 |
| `CODEX_HOME` 등 설정 홈 재정의 | 설정 파일 경로를 가정하는 어떤 검사도 이 환경에서는 틀린 답을 준다. 항상 CLI 에게 물어야 한다 |
| `도구 통제 미검증` | 그 CLI 에서 위험 도구 차단/승인 메커니즘이 **아직 조사되지 않았다** |
| `도구 단위 차단 불가` | 조사했고 **수단이 없다는 것이 확인됐다.** 아래 §4.7 을 읽고 선택할 것 |

### 4.7 제약 고지 — 기술적으로 불가능한 것

진단 마지막에 이런 블록이 나온다.

```
이 PC 에서 기술적으로 불가능한 것 — 진행 여부는 사용자가 정합니다

  [high] agy — 도구 단위 차단·승인 수단이 없다
      왜   : ...
      결과 : 매니페스트의 tool_policy.deny 가 강제되지 않는다 ...
      선택지:
        - 등록은 하되 평소에는 꺼 둔다   <- 권장
            agy mcp disable google-workspace
            => 평소 노출이 0 이 된다 ...
        - 이 클라이언트에는 등록하지 않는다
            ...
```

**이것은 경고가 아니라 갈림길이다.** 하네스가 대신 막아 줄 수 없는 것이므로,
무엇을 감수할지는 사람이 정해야 한다. 그래서 등록한 뒤가 아니라 **아무것도 바뀌지 않은
이 시점에** 보여 준다.

읽는 법:

| 필드 | 뜻 |
|---|---|
| `severity` | `high` 면 적용 시 별도 동의(`LIMITS` 입력)를 받는다. `medium` 이하는 고지만 한다 |
| `왜` | 왜 불가능한지. 추측이 아니라 확인한 근거다 |
| `결과` | 그대로 진행하면 실제로 무엇이 통제되지 않는지 |
| `선택지` | 각각 실행할 명령(`how`)과 그 결과(`=>`)가 붙어 있다. 하나에 `<- 권장` 이 붙는다 |

선택을 실행에 반영하는 방법:

```powershell
# 1) 계획 파일을 만든다
.\scripts\Get-HarnessEnvironment.ps1 -SavePlan .\plan.json

# 2) "등록하지 않는다" 를 골랐다면 그 단계의 enabled 를 false 로 바꾼다
#    plan.json 에서 client.register:<client>:<runtime> 를 찾아 "enabled": false

# 3) 적용. high 제약이 남아 있으면 LIMITS 를 입력해야 진행된다
.\scripts\Install-Harness.ps1 -Plan .\plan.json
```

`LIMITS` 를 입력하지 않으면 **아무것도 적용되지 않는다.** 되돌릴 것도 없다.

#### 선택을 적용한 뒤에는 확인한다

완화를 골라 실행했으면 진단을 다시 돌려 **판정이 바뀌는지** 본다.
바뀌지 않으면 그 완화는 적용되지 않았거나 하네스가 못 보고 있는 것이다.

```powershell
.\scripts\Get-HarnessEnvironment.ps1 | Select-String '도구 통제'
```

| 판정 | 뜻 |
|---|---|
| `WARN  차단 불가 — 노출 중` | risk=high 런타임이 **켜져 있고** 도구 단위로 막을 수 없다 |
| `OK    차단 불가 — 꺼 둠` | 완화가 적용됐다. 지금은 노출이 없다 |
| `INFO  차단 불가 — 미등록` | 애초에 등록돼 있지 않다 |

`Sync-HarnessClients.ps1` 의 DETAIL 에도 `꺼져 있음 (mcp disable)` 로 나온다.
**등록돼 있다와 켜져 있다는 다르다.** 꺼 둔 서버도 목록에는 남으므로,
이 구분이 보이지 않으면 "왜 도구가 안 보이지" 를 한참 찾게 된다.

> 완화를 적용해도 경고가 그대로면 사용자는 경고를 무시하도록 훈련된다.
> 그래서 진단은 "수단이 없다" 가 아니라 **"지금 실제로 노출돼 있는가"** 를 보고한다.

> 제약은 클라이언트 디스크립터(`settings/clients/<id>.client.json`)의 `limitations` 에
> 데이터로 선언한다. 새 제약을 추가하는 데 스크립트를 고칠 필요가 없다.
> 저장소 검사기가 "선택지가 2개 이상이고 각각 `how` 가 있으며 권장이 정확히 1개"인지 강제한다.
> **선택지 없는 고지는 통보이지 선택이 아니기 때문이다.**

---

## 5. STEP 2 — 적용

> **먼저 열려 있는 AI CLI 세션을 모두 닫는다.**
> 이유 두 가지:
> 1. 사용자 환경변수 변경은 **이미 실행 중인 프로세스에 전달되지 않는다.** 열려 있는 세션은 옛 값을 계속 쓴다.
> 2. 일부 CLI 는 종료할 때 자기 설정 파일을 다시 쓴다. 그때 하네스가 넣은 등록이 덮여 사라질 수 있다.
>
> 확인:
> ```powershell
> Get-Process claude,codex,agy -ErrorAction SilentlyContinue |
>     Select-Object Id, ProcessName, StartTime
> ```

### 5.0 권장 경로 — 계획 파일로 한 번에

아래 §5.1~5.7 은 각 단계를 손으로 실행하는 방법이다. 무엇이 일어나는지 보려면 유용하지만,
실제 설치는 **계획 파일 한 번**으로 하는 편이 낫다. 확인 절차와 롤백 저널이 딸려 오기 때문이다.

```powershell
# 1) 진단이 이 PC 에 맞는 계획을 만든다 (아무것도 바꾸지 않음)
.\scripts\Get-HarnessEnvironment.ps1 -SavePlan .\plan.json

# 2) 계획을 읽고 빼고 싶은 단계의 enabled 를 false 로 바꾼다 (§4.7 의 선택을 여기서 반영)
notepad .\plan.json

# 3) 실행될 명령을 먼저 본다
.\scripts\Install-Harness.ps1 -Plan .\plan.json -DryRun

# 4) 적용. 제약 동의(LIMITS) -> REMOVE 동의 -> APPLY 순으로 확인을 받는다
.\scripts\Install-Harness.ps1 -Plan .\plan.json

# 되돌리기 (저널 경로는 적용이 끝날 때 출력된다)
.\scripts\Install-Harness.ps1 -Rollback '<저널경로>'
```

적용자는 **재탐지하지 않는다.** 계획 파일에서 뺀 단계를 되살리지 않으며,
선행 단계를 빼면 그것에 의존하는 단계도 아예 제시하지 않는다.

`선택` 으로 표시된 단계는 기본적으로 실행되지 않는다. 넣으려면 `-IncludeOptional`
또는 `-Only <step_id>` 를 쓴다.

### 5.0b 무슨 도구를 깔지 모르겠다면 — 설치 에스코트

§5.0 의 계획은 **하네스 자체를 이 PC 에 맞추는** 것이다.
그와 별개로 **어떤 MCP·Skill 을 쓸지**는 사람이 골라야 한다. 카탈로그에 109개가 있다.

목록만 던지면 아무도 안 고른다. 그래서 물어보고 설명해 주는 경로가 따로 있다.

```powershell
.\scripts\Invoke-HarnessEscort.ps1 -SavePlan .\escort.json
```

에스코트가 하는 일:

```
"이 프로젝트에서 주로 뭘 하실 건가요?"  → 추천 세트와 그 이유
카탈로그를 번호로 훑어보기               → 번호를 치면 쉬운 말로 자세히
항목마다 설치할까요? [y/n/나중에]
   y → 자동?  계획에 담고 Install-Harness.ps1 이 확인받고 실행
       직접?  명령을 순서대로 안내하고 기록만 남김
```

`g` 로 목표를 다시 고를 수 있고, `r` 로 추천을 다시 본다. 아무것도 안 고르고 나가도 된다.

**대화형이므로 사람이 직접 실행해야 한다.** AI CLI 안에서 `! powershell ...` 로 부르면
입력이 연결되지 않아 종료 코드 `3` 으로 빠진다. 그때는 읽기 전용 모드를 쓴다.

```powershell
.\scripts\Invoke-HarnessEscort.ps1 -List              # 전체 목록 (번호 붙여서)
.\scripts\Invoke-HarnessEscort.ps1 -Explain 62        # 한 항목만 쉬운 말로
.\scripts\Invoke-HarnessEscort.ps1 -Tips              # 카탈로그 보는 법
```

에스코트도 **적용하지 않는다.** 계획 파일을 내고 §5.0 과 같은 문(`Install-Harness.ps1`)으로 넘긴다.

```powershell
.\scripts\Install-Harness.ps1 -Plan .\escort.json -DryRun
.\scripts\Install-Harness.ps1 -Plan .\escort.json
```

`discovery_only` 처럼 좌표가 확정되지 않은 항목은 **자동 설치를 막고 이유를 말한 뒤**
직접 설치 가이드로 넘어간다. 자세한 것은 `workflows/ESCORT.md`.

> 순서 참고: 에스코트는 §5.1~5.2(도구 루트·가드)가 끝난 뒤가 자연스럽다.
> 공용 런타임을 고르면 §5.3~5.7 이 그 뒤에 이어진다.

### 5.1 도구 루트 준비 (수동 경로)

아래부터는 §5.0 을 쓰지 않고 손으로 할 때의 절차다.
적용은 **한 번에 하나씩** 한다. 각 단계는 독립적이고, 하지 않아도 나머지가 동작한다.

```powershell
$Tools = "$env:LOCALAPPDATA\AI-Tools"          # 비ASCII 홈이면 ASCII 경로로 바꿀 것
New-Item -ItemType Directory -Force -Path $Tools | Out-Null

# 소유자 / SYSTEM / Administrators 만 쓰기 가능하게 제한
$me = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
icacls $Tools /inheritance:r /grant:r "*${me}:(OI)(CI)F" "*S-1-5-18:(OI)(CI)F" "*S-1-5-32-544:(OI)(CI)F"

[Environment]::SetEnvironmentVariable('AI_HARNESS_TOOLS_ROOT', $Tools, 'User')
$env:AI_HARNESS_TOOLS_ROOT = $Tools
```

**바뀌는 것:** 디렉터리 1개, ACL, 사용자 환경변수 1개.
**되돌리기:** 디렉터리 삭제 + `[Environment]::SetEnvironmentVariable('AI_HARNESS_TOOLS_ROOT',$null,'User')`

### 5.2 비밀값 가드 활성화 (권장)

```powershell
git -C "$env:LOCALAPPDATA\AI-Harness" config core.hooksPath .githooks
powershell -NoProfile -ExecutionPolicy Bypass -File "$env:LOCALAPPDATA\AI-Harness\scripts\Test-HarnessRepo.ps1"
```

`PASS` 가 나와야 한다. `SECRET_GUARD_UNENFORCED` 가 나오면 git 저장소가 아니다.

> **이 훅은 하네스 저장소에만 설치된다.** 프로젝트 저장소의 `core.hooksPath` 는 건드리지 않는다. 기존 프로젝트가 자체 훅(lint·테스트·서명)을 쓰고 있을 수 있고, 그것을 덮으면 프로젝트 방어가 사라지기 때문이다.

### 5.3 공용 런타임 설치 (필요할 때만)

**Google 작업을 쓰지 않으면 이 단계를 통째로 건너뛴다.** 하네스는 런타임 없이 완전히 동작한다.

```powershell
$H = "$env:LOCALAPPDATA\AI-Harness\scripts"

# 이미 설치된 것이 있으면 재다운로드 없이 채택
powershell -NoProfile -ExecutionPolicy Bypass -File "$H\Install-HarnessRuntime.ps1" `
    -RuntimeId google-workspace -Adopt
```

**바뀌는 것:** `<도구 루트>\google-workspace\<버전>\` 에 npm 패키지, `runtimes.json` 기록.
**소요:** 신규 설치는 의존성이 크고 Defender 실시간 검사까지 겹쳐 **수 분** 걸린다. 멈춘 것이 아니다.

### 5.4 전송 검증 (인증 전에도 가능)

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "$H\Test-HarnessRuntime.ps1" `
    -RuntimeId google-workspace -TransportOnly
```

`state: reachable`, `tool_count > 0` 이면 **경로·인코딩·실행·런타임이 전부 정상**이라는 뜻이다.
아직 인증은 안 됐지만 설치는 성공한 것이다.

### 5.5 인증 (Google 을 쓸 때만)

→ **`workflows/GOOGLE_WORKSPACE_SETUP.md`** 를 따른다.

Google Cloud 프로젝트 생성부터 OAuth 동의, `credentials.json` 배치, `auth` 실행까지의 전체 절차다.
**설치와 인증은 별개 단계이고, 인증은 브라우저 동의가 필요한 대화형 작업이다.**

### 5.6 AI 클라이언트 등록

> ⚠ **여기서 부여되는 것은 "파일 접근"이 아니라 "계정 권한"이다.**
> `google-workspace` 는 `risk: high` 이며 메일 발송·파일 삭제·공유 권한을 AI 에이전트가 쓸 수 있게 된다.
> 등록 전에 매니페스트의 `tool_policy` 를 확인하라:
> - **기본 차단**: `delete_email`(영구 삭제) `empty_trash` `batch_delete` `remove_permission`
> - **호출 직전 승인**: `send_email` `share_file` `batch_share` `delete_item` `delete_event` `create_filter`

```powershell
# 무엇이 실행될지 먼저 본다 (아무것도 바꾸지 않음)
powershell -NoProfile -ExecutionPolicy Bypass -File "$H\Register-HarnessRuntimeClient.ps1" `
    -RuntimeId google-workspace -Client claude -WhatIf

# 확인 후 실제 등록 (-IAcceptRisk 없이는 risk=high 등록이 거부된다)
powershell -NoProfile -ExecutionPolicy Bypass -File "$H\Register-HarnessRuntimeClient.ps1" `
    -RuntimeId google-workspace -Client claude -IAcceptRisk
```

`-Client all` 로 감지된 모든 CLI 에 한 번에 등록할 수도 있다.

**등록 후 스크립트가 자동으로 되읽어 확인한다.** `status: registered` 이고 `detail` 에 올바른 경로가 보여야 한다.

### 5.7 최종 검증

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "$H\Test-HarnessRuntime.ps1" -RuntimeId google-workspace
```

| 결과 | 뜻 |
|---|---|
| `state: verified` / `auth_state: authorized` | 완료 |
| `state: reachable` / `auth_state: not_authorized` | 설치는 정상, 인증만 남음 → §5.5 |
| `state: reachable` / `auth_state: auth_failed` | 토큰이 만료·폐기됨 → 재인증 |
| `state: installed` / `transport_ok: False` | 서버가 뜨지 않음 → §11 |

**그리고 AI CLI 를 재시작한 뒤** 실제로 한 번 시켜 본다: *"내 Google Drive에서 최근 파일 5개만 보여줘"*

---

## 6. 새 프로젝트에 하네스 연결

설치는 PC 당 1회, 아래는 프로젝트당 1회다.

```
cd <프로젝트 폴더>
claude          (또는 codex / agy)

  "<하네스 경로>\PROJECT_INIT.md 를 읽고 이 프로젝트에 AI Harness 를 초기화해줘"
```

`.ai/HARNESS.md`, `.ai/harness.yaml`, `.ai/current-state.md` 와 현재 CLI 의 어댑터 블록만 생성된다.
**정책 26개는 복사되지 않는다.** 프로젝트는 사본이 아니라 포인터를 갖는다.

---

## 7. 이미 설치된 PC (업그레이드)

### 7.1 기존 설치 판별

```powershell
[Environment]::GetEnvironmentVariable('AI_HARNESS_TOOLS_ROOT','User')
[Environment]::GetEnvironmentVariable('AI_HARNESS_GOOGLE_MCP_COMMAND','User')   # 값이 있으면 v2.2 잔재
Test-Path 'C:\AI-Tools'                    # 레거시 위치
Get-Content "$env:LOCALAPPDATA\AI-Tools\runtimes.json" -ErrorAction SilentlyContinue
```

### 7.2 절차

1. 진단 실행 → 제안 목록 확인
2. **AI CLI 세션 전부 종료**
3. 하네스 갱신: `git -C <하네스> pull`
4. `Install-HarnessRuntime.ps1 -Adopt` — 기존 설치를 재다운로드 없이 채택한다
5. `Register-HarnessRuntimeClient.ps1` — 경로가 바뀌었으면 재등록
6. `Test-HarnessRuntime.ps1` — 검증
7. 레거시 도구 루트 정리는 **맨 마지막에**, 모든 CLI 재시작 후

> **토큰은 도구 루트 밖(`%USERPROFILE%\.config\...`)에 있다.** 도구 루트를 옮겨도 **재로그인이 필요 없다.**

### 7.3 레거시 도구 루트 정리

```powershell
# 그 경로에서 실행 중인 프로세스가 없는지 먼저 확인
Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -match 'C:\\AI-Tools' } |
    Select-Object ProcessId, Name

# 없으면 삭제
Remove-Item -Recurse -Force 'C:\AI-Tools'
```

---

## 8. 제거 / 되돌리기

> **하네스가 적용한 변경은 `Install-Harness.ps1 -Rollback <저널경로>` 로 되돌린다.** (§12)
> 아래는 하네스를 **통째로 제거**할 때의 수동 체크리스트다. 저널이 없거나 하네스가 만들지 않은 것까지 지울 때 쓴다.

```powershell
# 1. 클라이언트 등록 제거
claude.cmd mcp remove google-workspace -s user
codex.cmd  mcp remove google-workspace
agy        mcp remove google-workspace

# 2. 도구 루트 삭제 (실행 중 프로세스 없는지 확인 후)
Remove-Item -Recurse -Force "$env:LOCALAPPDATA\AI-Tools"

# 3. 환경변수 제거
[Environment]::SetEnvironmentVariable('AI_HARNESS_TOOLS_ROOT', $null, 'User')
[Environment]::SetEnvironmentVariable('AI_HARNESS_GOOGLE_MCP_COMMAND', $null, 'User')

# 4. 하네스 저장소 삭제
Remove-Item -Recurse -Force "$env:LOCALAPPDATA\AI-Harness"
```

**위 절차가 지우지 않는 것 — 반드시 별도로 처리한다:**

| 남는 것 | 처리 |
|---|---|
| OAuth 토큰 `%USERPROFILE%\.config\google-workspace-mcp\` | **먼저** https://myaccount.google.com/permissions 에서 앱 권한 취소 → 그 다음 폴더 삭제 |
| Google Cloud 의 OAuth 클라이언트 | Console 에서 삭제 |
| npm 캐시 | `npm.cmd cache clean --force` (선택) |
| 프로젝트의 `.ai/` 디렉터리 | 프로젝트별로 직접 삭제 |

> 권한 취소를 건너뛰고 파일만 지우면 **토큰은 서버 쪽에서 여전히 유효하다.**

---

## 9. 클라이언트별 참조

| CLI | 설정 위치 | 형식 | scope | 재시작 필요 |
|---|---|---|---|---|
| Claude Code | `~/.claude.json` (user/local), `<project>/.mcp.json` (project) | JSON `mcpServers` | `local`/`project`/`user` | 예 |
| Codex CLI | `$CODEX_HOME/config.toml` (기본 `~/.codex/`) | TOML `[mcp_servers.<id>]` | 없음 (항상 전역) | 예 |
| AGY (Antigravity) | `~/.gemini/config/mcp_config.json` | JSON `mcpServers` (원격은 `serverUrl`) | 없음 | 예 |
| *Gemini CLI (별개 제품)* | `~/.gemini/settings.json` | JSON `mcpServers` (원격은 `httpUrl`) | `user`/`project` | 예 |

> ⚠ **AGY 와 Gemini CLI 는 서로 다른 제품이고 설정이 호환되지 않는다.** 경로도 원격 서버 키 이름도 다르다.
> ⚠ **설정 파일 경로를 가정하지 말 것.** `CODEX_HOME` 처럼 환경변수로 재정의될 수 있고, 다계정 래퍼가 그렇게 한다. 상태를 알고 싶으면 `<cli> mcp list` 로 CLI 에게 물어야 한다.

---

## 10. 도구 통제 (등록 후 권장)

`risk: high` 런타임은 등록만으로 끝내지 않는다.

**Claude Code** — `.claude/settings.json`
```jsonc
{
  "permissions": {
    "deny": ["mcp__google-workspace__delete_email", "mcp__google-workspace__empty_trash"],
    "ask":  ["mcp__google-workspace__send_email", "mcp__google-workspace__share_file"]
  }
}
```
Google 과 무관한 프로젝트에서는 `/mcp` 토글로 서버 자체를 끄면 토큰도 절약된다.

**Codex CLI** — `$CODEX_HOME/config.toml`
```toml
[mcp_servers.google-workspace]
disabled_tools = ["delete_email", "empty_trash", "batch_delete", "remove_permission"]
default_tools_approval_mode = "writes"   # 읽기는 자유, 쓰기는 승인
```

**AGY** — 도구 통제 메커니즘 미검증.

---

## 11. 문제 해결 (에러 문자열 기준)

| 보이는 메시지 | 원인 | 해결 |
|---|---|---|
| `... cannot be loaded because running scripts is disabled` | ExecutionPolicy | 명령을 `powershell -NoProfile -ExecutionPolicy Bypass -File "<절대경로>"` 형태로 실행 |
| `PSSecurityException` 인데 `npm` 실행 중 발생 | `npm` 이 `npm.ps1` 로 잡힘 | `npm.cmd` 를 쓴다 |
| `-ExecutionPolicy Bypass` 를 줬는데도 차단됨 | 조직 정책(GPO)이 `MachinePolicy`/`UserPolicy` 를 설정 | `Get-ExecutionPolicy -List` 로 확인. GPO 는 우회 불가 → 관리자에게 문의하거나 `node` 를 직접 호출하는 경로로 진행 |
| `Unexpected token '﻿' ... is not valid JSON` | JSON 파일에 BOM | BOM 없이 다시 쓴다. `Set-Content -Encoding utf8` / `Out-File` 사용 금지 |
| 경로가 `?덈룄???명똿怨듦컙` 처럼 깨짐 | 인코딩 미지정으로 읽음 | 명시적 UTF-8 로 읽는다. 하네스 스크립트는 `Read-HarnessText` 사용 |
| `ENOENT` / 설치했는데 `node_modules` 없음 | MAX_PATH 초과 | 도구 루트를 짧은 경로로 옮긴다 |
| `E404` (npm) | 사내 레지스트리에 패키지 없음 | `npm.cmd config get registry` 확인. 공개 레지스트리 필요 |
| `E401` / npm 이 멈춤 | 프록시 인증 | `npm.cmd config get proxy` 확인 후 사내 절차대로 인증 |
| CLI 시작 시 `MCP server failed to connect` | 등록된 경로가 없거나 실행 불가 | `Resolve-HarnessRuntime.ps1` 로 실제 경로 확인 후 재등록 |
| 인증했는데 그 세션에서 계속 실패 | 실행 중인 서버가 옛 상태 | **AI CLI 를 재시작한다** |
| 등록했는데 다음에 보면 사라짐 | 외부 도구가 그 CLI 설정을 소유 | 진단의 `관리형 설정 홈` 경고 참고. 작업 시작 시 등록 상태 재확인 필요 |
| 같은 이름 도구가 두 벌 보임 | 다른 Google 커넥터와 중복 | 한쪽을 비활성화. 서로 다른 계정일 수 있다 |
| `npm install` 이 몇 분째 멈춘 듯함 | Defender 실시간 검사 | 정상이다. 기다린다 |

### 지원 요청용 정보 모으기

```powershell
$H = "$env:LOCALAPPDATA\AI-Harness\scripts"
powershell -NoProfile -ExecutionPolicy Bypass -File "$H\Get-HarnessEnvironment.ps1" -Json > env.json
powershell -NoProfile -ExecutionPolicy Bypass -File "$H\Resolve-HarnessRuntime.ps1" -All -Json > runtimes.json
powershell -NoProfile -ExecutionPolicy Bypass -File "$H\Test-HarnessRepo.ps1" -Json > repo.json
```

이 세 파일에는 비밀값이 들어가지 않는다(자격증명은 **존재 여부만** 기록된다). 공유 전에 경로에 개인정보가 없는지 한 번 확인할 것.

---

## 12. 무엇이 자동화됐고 무엇이 안 됐나 (정직하게)

| 항목 | 현재 | 비고 |
|---|---|---|
| 통합 적용 스크립트 | **있다.** `Install-Harness.ps1` (계획 파일 소비) | §5.0 |
| 롤백 저널 | **있다.** 변경 전 상태를 기록하고 `-Rollback` 으로 역재생 | undo 를 모르는 exec 는 "수동 확인 필요"로 남는다 |
| 적용 전 3-way diff | **있다.** 선언 / 원장 / 실제 비교 후 ADD·CHANGE·**REMOVE** | REMOVE 는 별도 동의 |
| 실행 중 세션 자동 차단 | **있다.** 적용 직전 재확인 후 거부 | `-AllowRunningClients` 로만 통과 |
| 제약 고지 | **있다.** 디스크립터의 `limitations` 를 선택지와 함께 제시 | §4.7 |
| macOS / Linux | **미지원** | 실제 요구가 생기면. `platforms` 에 검증한 것만 적는다 |
| 프로젝트별 도구 정책 자동 적용 | **수동.** §10 의 설정을 사람이 넣는다 | 클라이언트마다 파일·키가 달라 아직 데이터화하지 않았다 |
| Drive 스냅샷 | **있다.** `Publish-HarnessSnapshot.ps1` (불변, 추적 파일만) | 정본은 GitHub. Drive 는 라벨 붙은 사본 |

---

## 관련 문서

- `workflows/ESCORT.md` — 설치 에스코트. 어떤 도구를 쓸지 설명받고 고르는 절차 (§5.0b)
- `workflows/SHARED_RUNTIME.md` — 공용 런타임 수명주기 (install → auth → verify → sync → restart)
- `workflows/GOOGLE_WORKSPACE_SETUP.md` — Google 최초 로그인 (자기 계정으로)
- `workflows/GOOGLE_WORKSPACE_MCP.md` — 설치 후 운영 규칙과 권한 경계
- `workflows/CAPABILITY_ACQUISITION.md` — 필요할 때만 MCP/Skill 획득
- `PROJECT_INIT.md` — 프로젝트에 하네스 연결
- `HARNESS_DOCTOR.md` — 운영 중 진단

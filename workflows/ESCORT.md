# 설치 에스코트

Document Version: 1.0
목적: 하네스를 처음 세팅하는 사람이 **무슨 도구가 있고, 나한테 뭐가 필요하고, 이걸 깔면 무엇을 감수하는지**를
알고 결정하게 한다.

> 아는 사람만 쓸 수 있는 도구는 설치되지 않은 것과 같다.
> 카탈로그에 109개가 있어도 그게 뭔지 모르면 0개다.

---

## 1. 부르는 법

```powershell
.\scripts\Invoke-HarnessEscort.ps1                          # 대화형 (기본)
.\scripts\Invoke-HarnessEscort.ps1 -SavePlan .\escort.json  # 결정을 계획 파일로 남긴다
.\scripts\Invoke-HarnessEscort.ps1 -List                    # 전체 목록만 (읽기 전용)
.\scripts\Invoke-HarnessEscort.ps1 -Explain playwright      # 한 항목만 쉬운 말로
.\scripts\Invoke-HarnessEscort.ps1 -Tips                    # 카탈로그 보는 법
```

Claude Code 플러그인을 설치했다면 `/harness-escort` 로도 부를 수 있다.

**AI 없이 돌아간다.** 이것이 설계 조건이었다. 하네스를 처음 까는 사람에게는 아직 AI 가 연결돼 있지 않을 수 있다.

---

## 2. 흐름

```
0  인사 + 지금 상태 (아무것도 안 깔고 나가도 된다고 먼저 말한다)
        ↓
1  "이 프로젝트에서 주로 뭘 하실 건가요?"   ← 9개 프로필, 복수 선택 가능
        ↓
2  추천 세트 + 왜 이걸 권하는지
        ↓
3  열람 루프
     번호       → 그 도구를 쉬운 말로 자세히
     a          → 전체 카탈로그
     d <분야>   → 분야별
     s <검색어> → 이름·기능으로 찾기
     ?          → 카탈로그 보는 법
     p          → 지금까지 담은 것
     q          → 마치기
        ↓
4  항목마다:  설치할까요?  [y] / [n] / [l 나중에]
             y → 어떻게?  [1] 자동  [2] 직접
                 자동 → 계획에 exec 단계로 담는다
                 직접 → 상세 가이드를 출력하고 manual 단계로 기록만 한다
        ↓
5  계획 파일 저장 + 다음 명령 안내
```

---

## 3. 지키는 규칙

### 3.1 에스코트는 아무것도 적용하지 않는다

계획 파일(`harness-change-plan v1.0`)을 낼 뿐이다. 적용은 `Install-Harness.ps1` 이 한다.

```
Invoke-HarnessEscort.ps1  ─┐
Get-HarnessEnvironment.ps1 ├─> 계획 파일 ─> Install-Harness.ps1
Sync-HarnessClients.ps1   ─┘                확인 → 적용 → 롤백 저널
```

계획을 **만드는** 스크립트는 셋이 됐다. **적용하는** 스크립트는 여전히 하나다.
둘이 되는 순간 확인 절차를 우회하는 길이 생긴다.

### 3.2 설명은 코드가 아니라 데이터에 있다

| 파일 | 담는 것 |
|---|---|
| `catalogs/escort-glossary.json` | 분야·위험도·상태·설치방식·능력을 쉬운 말로 옮기는 사전 |
| `catalogs/escort-profiles.json` | "뭘 하려고 하는지" → 추천 세트 |

**새 도구가 늘어도 `Invoke-HarnessEscort.ps1` 을 고치지 않는다.**
사전에 없는 항목은 조용히 넘어가지 않고 "아직 쉬운 말 설명이 없다"고 밝힌 뒤 공식 문서를 가리킨다.

`Test-HarnessRepo.ps1` 이 매번 검사한다.

- `ESCORT_UNKNOWN_ID` — 카탈로그에 없는 id 를 추천하면 **FAIL**.
  존재하지 않는 도구를 권유하는 것은 사용자를 막다른 길로 보내는 일이다
- `ESCORT_DUPLICATE_PROFILE` — 프로필 id 중복이면 FAIL
- `ESCORT_UNKNOWN_INSTALL_KIND` — 카탈로그가 쓰는 설치 방식인데 사전에 없으면 WARN

### 3.3 자동 설치를 하지 않는 경우

| 조건 | 왜 |
|---|---|
| `status: discovery_only` | 어디서 받는지가 확정돼 있지 않다. 이름이 같아도 만든 사람이 다른 가짜가 있다 |
| `install.kind: registry_lookup` | 위와 같다. 좌표부터 확정해야 한다 |
| `remote` / `remote_or_client` | 설치가 아니라 로그인과 권한 결정이다. 자동으로 넘길 일이 아니다 |
| `oci` / `docker_or_source` / `nuget` / `upm` | 준비물(Docker·SDK·에디터)이 먼저 있어야 한다 |
| npm/pypi 인데 정확한 버전을 못 정한 경우 | `latest` 를 영구 설정에 남기지 않는다 |

이 경우 에스코트는 **왜 자동이 안 되는지 말하고** 직접 설치 가이드로 넘어간다.
막는 것과 이유 없이 안 되는 것은 다르다.

### 3.4 결정 하나가 다른 결정을 끌고 오지 않는다

설치 승인 / 로그인 연결 / 실서비스 변경 승인은 **서로 다른 결정**이다.
에스코트는 설치 결정만 받는다. 인증은 `Connect-HarnessRuntimeAuth.ps1` 이 따로 묻는다.

### 3.5 비대화 환경에서 매달리지 않는다

빈 입력이 3번 연속이면 종료 코드 `3` 으로 빠지면서 `-List` / `-Explain` 를 안내한다.
CI 나 스크립트에서 실수로 부르면 조용히 멈춰 있는 대신 즉시 알린다.

---

## 4. 사전을 늘리는 법

새 도구를 카탈로그에 넣었는데 설명이 밋밋하면 사전을 늘린다. 스크립트는 건드리지 않는다.

```jsonc
// catalogs/escort-glossary.json
"capability_terms": {
  "my_new_capability": "무엇을 할 수 있는지 한 줄로, 전문 용어 없이"
}
```

패턴으로 한꺼번에 처리할 수도 있다.

```jsonc
"capability_patterns": [
  { "match": "_write$", "plain": "{term} 을(를) 실제로 바꿀 수 있어요", "danger": true }
]
```

새 추천 세트는 `escort-profiles.json` 에 프로필을 하나 더 넣으면 끝난다.
단, `recommend` / `consider` 의 id 는 카탈로그에 실재해야 한다. 검사가 막는다.

---

## 5. 이어지는 문서

- `workflows/HARNESS_INSTALL.md` — PC 환경별 최초 설치. 에스코트는 그 안의 "도구 고르기" 단계다
- `workflows/SHARED_RUNTIME.md` — 공용 런타임 수명주기 (install → auth → verify → sync → restart)
- `workflows/CAPABILITY_ACQUISITION.md` — 작업 도중 도구가 부족해졌을 때의 획득 절차

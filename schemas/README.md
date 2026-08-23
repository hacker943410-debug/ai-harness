# schemas/ — 기계가 읽는 계약

이 폴더의 파일들은 문서가 아니라 **검사**다.
돌리지 않는 스키마는 며칠 만에 실제와 갈라지고, 갈라진 스키마는 없는 것보다 나쁘다.
틀린 계약을 사실처럼 읽게 만들기 때문이다.

| 스키마 | 대상 | 계층 | git |
|---|---|---|---|
| `runtime-manifest.schema.json` | `runtimes/<id>.runtime.json` | A 하네스 | ✅ |
| `client-descriptor.schema.json` | `settings/clients/<id>.client.json` | A 하네스 | ✅ |
| `runtime-index.schema.json` | `<tools_root>/runtimes.json` | B 머신 | ❌ |
| `client-index.schema.json` | `<tools_root>/clients.json` | B 머신 | ❌ |
| `change-plan.schema.json` | 진단이 낸 계획 파일 (`-SavePlan`) | 경계 | ❌ |
| `capability-lock.schema.json` | 프로젝트 `.ai/capability-lock.json` | C 프로젝트 | ✅ |

## 자동으로 검증되는 것

`Test-HarnessRepo.ps1` 이 Layer A 파일(런타임 매니페스트, 클라이언트 디스크립터)을 매번 검증한다.
node 가 없으면 통과가 아니라 `SCHEMA_UNCHECKED` (UNENFORCED) 로 보고한다.

## 손으로 검증하는 것

Layer B 와 계획 파일은 저장소 밖에 있으므로 필요할 때 직접 돌린다.

```powershell
$v = 'C:\AI-Harness\scripts\harness-schema-validate.mjs'
$s = 'C:\AI-Harness\schemas'

node $v --schema "$s\runtime-index.schema.json"  "$env:LOCALAPPDATA\AI-Tools\runtimes.json"
node $v --schema "$s\client-index.schema.json"   "$env:LOCALAPPDATA\AI-Tools\clients.json"

# 손으로 편집한 계획 파일은 적용 전에 확인하는 것이 좋다
node $v --schema "$s\change-plan.schema.json" .\plan.json
```

종료 코드: `0` 전부 통과 / `1` 위반 있음 / `2` 사용법·입출력 오류.

## 검증기에 대해

`scripts/harness-schema-validate.mjs` 는 **의존성이 0** 이다.
외부 라이브러리를 쓰면 "검사기를 돌리려면 먼저 `npm install` 을 하라"가 되고, 그 순간 아무도 안 돌린다.
대신 스키마가 실제로 쓰는 어휘만 구현한다. 모르는 키워드는 조용히 무시하지 않고
`UNSUPPORTED` 로 보고한다 — 검사하지 않은 것을 통과로 세지 않기 위해서다.

지원 어휘: `$ref`(로컬 `#/$defs`) `type` `enum` `const` `required` `properties`
`patternProperties` `additionalProperties` `propertyNames` `items` `minItems` `maxItems`
`uniqueItems` `pattern` `minLength` `maxLength` `minimum` `maximum` `allOf` `anyOf` `oneOf` `not`.

## 스키마가 표현하지 못하는 것

이 어휘로는 못 적는 규칙이 있다. 그것들은 `Test-HarnessRepo.ps1` 이 강제한다.

- 제약의 `options` 중 `recommended` 가 **정확히 1개**
- 매니페스트의 `runtime_id` 가 **파일명과 일치**
- Layer A 에 **절대경로 금지**
- `credentials.never_sync` 가 `required_files` + `auth_state_files` 를 **모두 포함**
- 계획 단계의 `payload` 가 **`kind` 마다 다른 모양** (적용자가 kind 별로 다시 검사한다)

스키마와 검사기 중 어느 쪽에 규칙을 둘지 헷갈리면, **표현할 수 있으면 스키마**에 둔다.
스키마는 다른 도구도 읽을 수 있고, 검사기는 이 저장소 안에서만 산다.

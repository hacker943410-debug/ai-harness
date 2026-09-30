# AI Harness v5.1 — 설치·업데이트 안정성 수정

출시 버전: 5.1.0 / 2026-09-30

## 공통 업데이트

- 기본 채널은 GitHub `main`. 새 설치와 detached 설치는 fetch한 원격 커밋을 확인한 뒤 detached HEAD로 적용한다.
- `-Ref v5.1.0`으로 출시 태그를 고정할 수 있다. 원격 브랜치·태그·전체 40자리 SHA도 지원한다.
- 작업용 브랜치는 같은 원격 브랜치로만 fast-forward한다. 로컬 선행·분기·dirty 상태에서는 중단한다.
- fetch, merge, checkout, hooks 설정, 저장소 검사 실패를 성공으로 표시하지 않는다. 검사 파일이 없어도 중단한다.
- `Test-HarnessRelease.ps1`은 임시 로컬 Git 원격과 임시 프로젝트에서 성공·실패 경로를 검증하며 외부 AI를 호출하지 않는다.

## Native Skill

| CLI | 프로젝트 설치 위치 |
|---|---|
| Codex CLI | `.agents/skills/<id>/` |
| AGY | `.agents/skills/<id>/` |
| Claude Code | `.claude/skills/<id>/` |

Codex 경로는 [공식 Skills 문서](https://learn.chatgpt.com/docs/build-skills)의 현재 검색 위치에 맞췄다. Codex와 AGY의 동일 목적지는 한 번만 설치한다.

- `-WhatIf`는 폴더나 잠금 파일을 생성하지 않는다.
- 기존 Skill과 내용이 다르면 중단한다. 검토 후 `-Force`를 명시하면 교체한다.
- 모든 목적지에 복사본을 준비하고 전체 파일 SHA-256을 검증한 뒤 교체한다.
- 교체 실패 시 기존 Skill을 복원하며 잠금 파일은 변경하지 않는다. 복구에 실패하면 임시 백업 경로를 알린다.
- 잠금 파일은 마지막에 원자적으로 교체한다. 전체 트리의 `bundle_hash`, `hash_algorithm`, `files`를 기록한다.
- 트리 해시는 상대 경로를 ordinal 순서로 정렬한 `path<TAB>sha256<LF>` UTF-8 목록의 SHA-256이다. 기존 `content_hash`는 SKILL.md 한 파일의 해시로 유지한다.
- 검사기는 추가·삭제·변조 파일과 중복 capability를 검출한다. 기존 단일 파일 해시는 호환되며 전체 검증이 없음을 INFO로 알린다.
- 프로젝트 밖 경로, links/junctions, 겹치는 목적지를 거부한다.

### 기존 Codex Skill 이동

예전 `.codex/skills/<id>/`는 자동 삭제하지 않는다. 사용자 수정본이 있으면 먼저 보존하고 새 `.agents/skills/<id>/` 설치와 검증을 마친 뒤 중복 폴더를 정리한다.

## 잠금 파일과 버전

`project_root`는 필수 필드에서 제외한다. 이식 가능한 프로젝트 잠금 파일에 머신 절대경로를 기록하지 않는다. scope는 실제 지원 범위인 `project`, `machine_user`, `client_user`와 일치시킨다.

`POLICY_INDEX.yaml`은 5.1, README는 5.1, Claude marketplace/plugin metadata는 5.1.0이다. P01~P26 정책과 Jev 기본 활성화 상태는 그대로 유지한다.

## 검증 명령

Windows PowerShell 5.1 검증 결과: 회귀 시험 **28/28 PASS**, Jev 오프라인 **22/22 PASS**, 저장소 검사 **PASS_WITH_WARNING** (실패 0건). 기존 markitdown `0.0.1a4` 프리릴리스 고정 경고 1건은 유지한다. 실제 외부 AI 호출은 0건이다.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Test-HarnessRepo.ps1 -Json
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Test-HarnessRelease.ps1
node .\scripts\test-jev-scenarios.mjs
```

Native 설치의 복구 보장은 `bundled_path`를 가진 하네스 번들에 적용한다. 외부 `npx skills add`의 동작·복구는 해당 CLI가 관리한다.

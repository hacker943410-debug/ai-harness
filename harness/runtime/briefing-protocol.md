# Continuous briefing
Brief at phase start, before material decision, when choice needed, major implementation result, test result/failure/block, before and after deployment. Explain current stage, purpose, status, next action and relevant impact in short plain language.
Maintenance example: “현재는 기존 동작을 확인하는 단계입니다. 이번 수정과 직접 관련된 코드부터 확인하고, 변경 기능과 기존 기능을 함께 검증하겠습니다.”
Verification example: “구현은 끝났고 검증 중입니다. 필수 테스트 하나가 실패하여 다음 단계로 넘어갈 수 없습니다. 실패한 저장 흐름을 수정한 뒤 다시 검증하겠습니다.”
Token example: “이미 확인한 구조를 재사용하고 관련 파일만 읽겠습니다. 필요한 테스트는 모두 수행합니다.”
Failure briefing states failure, likely cause (as inference), impact, safe recovery, decision need and next step. Save raw stack trace artifact; don't dump it as the entire explanation or retry without new evidence.
Update briefing includes current/target version, state/phase/progress, H1/H2/H3, immediate versus next-checkpoint effects, recommendation and rollback. Deferred update names reason and revisit milestone. Preserve beginner/expert preference across migration; expert brevity only on explicit request.

/**
 * test-jev-scenarios.mjs — Jev Phase 2 오프라인 음성검사 및 Canary 시나리오 검사기 (Harness 3.1 R1)
 * 의존성 없음 (Node 24 ESM)
 *
 * 계약:
 * - 기본 실행은 완전 오프라인 (인자 없이 실행 시 실제 API 키/외부 fetch 미사용)
 * - 환경 변수 및 globalThis.fetch는 테스트 후 반드시 원상 복구
 * - 입력 차단 9건 (fetch 0회) + Provider 응답 검증 13건 (건별 fetch 1회)
 * - 라이브 Canary는 명시적 이중 관문 (--live 및 JEV_ALLOW_LIVE_CANARY=1) 필요
 * - 상태 문장, 질문 전문, 가짜 원시 응답 출력 금지, 검사 ID와 PASS/FAIL 집계만 출력
 */

import { evaluateJevDecision } from './jev-decision.mjs';

async function runOfflineTestSuite() {
  const originalApiKey = process.env.AI_GATEWAY_API_KEY;
  const originalFetch = globalThis.fetch;

  let totalTests = 0;
  let passedTests = 0;
  let totalFetchCalls = 0;

  try {
    // 1. 오프라인 환경 설정
    process.env.AI_GATEWAY_API_KEY = 'mock-offline-canary-key';

    let currentMockResponse = null;
    let currentFetchCount = 0;

    globalThis.fetch = async (url, options) => {
      totalFetchCalls++;
      currentFetchCount++;
      if (typeof currentMockResponse === 'function') {
        return currentMockResponse(url, options);
      }
      return currentMockResponse;
    };

    // Helper: 검사 실행 및 단언
    async function assertTest(id, name, runFn) {
      totalTests++;
      currentFetchCount = 0;
      let ok = false;
      let detail = '';
      try {
        const res = await runFn();
        if (res.ok) {
          ok = true;
        } else {
          detail = res.reason || 'Assertion failed';
        }
      } catch (err) {
        detail = 'Exception: ' + (err.message || String(err));
      }

      if (ok) {
        passedTests++;
        console.log(`[${id}] ${name}: PASS (fetch: ${currentFetchCount})`);
      } else {
        console.error(`[${id}] ${name}: FAIL (${detail}) (fetch: ${currentFetchCount})`);
      }
      return ok;
    }

    console.log('=== [1] 오프라인 입력 차단 검사 (기대: fetch 0회, 고정 오류) ===');

    // T01: customer_operational 분류 거부
    await assertTest('T01', 'customer_operational 분류 사전 차단', async () => {
      const res = await evaluateJevDecision({
        decision_type: 'task_route',
        data_classification: 'customer_operational',
        state: '테스트 상태',
        questions: {
          q1: { type: 'choice', instructions: '질문', criteria: { opt1: '설명1', opt2: '설명2' } }
        }
      });
      const noLeak = !JSON.stringify(res).includes('customer_operational');
      const pass = res.ok === false && res.fallback_used === true && res.error_type === 'DATA_CLASSIFICATION_NOT_NON_SENSITIVE' && currentFetchCount === 0 && noLeak;
      return { ok: pass, reason: `res=${res.error_type}, fetch=${currentFetchCount}, noLeak=${noLeak}` };
    });

    // T02: 중첩된 api_key 키 거부
    await assertTest('T02', '중첩된 민감 키(api_key) 사전 차단', async () => {
      const res = await evaluateJevDecision({
        decision_type: 'task_route',
        data_classification: 'non_sensitive',
        state: '테스트 상태',
        questions: {
          q1: { type: 'choice', instructions: '질문', criteria: { opt1: '설명1', opt2: '설명2' } }
        },
        meta: { nested: { api_key: 'dummy' } }
      });
      const noLeak = !JSON.stringify(res).includes('api_key');
      const pass = res.ok === false && res.fallback_used === true && res.error_type === 'SENSITIVE_KEY_DETECTED' && currentFetchCount === 0 && noLeak;
      return { ok: pass, reason: `res=${res.error_type}, fetch=${currentFetchCount}` };
    });

    // T03: 알 수 없는 최상위 필드 거부
    await assertTest('T03', '알 수 없는 최상위 필드 거부', async () => {
      const res = await evaluateJevDecision({
        decision_type: 'task_route',
        data_classification: 'non_sensitive',
        state: '테스트 상태',
        unauthorized_custom_field: 'leak_value',
        questions: {
          q1: { type: 'choice', instructions: '질문', criteria: { opt1: '설명1', opt2: '설명2' } }
        }
      });
      const noLeak = !JSON.stringify(res).includes('unauthorized_custom_field') && !JSON.stringify(res).includes('leak_value');
      const pass = res.ok === false && res.fallback_used === true && res.error_type === 'UNAUTHORIZED_FIELD' && currentFetchCount === 0 && noLeak;
      return { ok: pass, reason: `res=${res.error_type}, noLeak=${noLeak}` };
    });

    // T04: expected 필드 거부
    await assertTest('T04', 'expected 필드 거부', async () => {
      const res = await evaluateJevDecision({
        decision_type: 'task_route',
        data_classification: 'non_sensitive',
        state: '테스트 상태',
        expected: 'opt1',
        questions: {
          q1: { type: 'choice', instructions: '질문', criteria: { opt1: '설명1', opt2: '설명2' } }
        }
      });
      const pass = res.ok === false && res.fallback_used === true && res.error_type === 'UNAUTHORIZED_FIELD' && currentFetchCount === 0;
      return { ok: pass, reason: `res=${res.error_type}` };
    });

    // T05: 숫자 설명이 든 Choice criteria 거부
    await assertTest('T05', '숫자 설명이 포함된 Choice criteria 거부', async () => {
      const res = await evaluateJevDecision({
        decision_type: 'task_route',
        data_classification: 'non_sensitive',
        state: '테스트 상태',
        questions: {
          q1: { type: 'choice', instructions: '질문', criteria: { opt1: 12345, opt2: '정상설명' } }
        }
      });
      const pass = res.ok === false && res.fallback_used === true && res.error_type === 'INVALID_CHOICE_CRITERIA' && currentFetchCount === 0;
      return { ok: pass, reason: `res=${res.error_type}` };
    });

    // T06: 길이 또는 원소가 잘못된 Score criteria 거부
    await assertTest('T06', '길이 부족(1개) Score criteria 거부', async () => {
      const res = await evaluateJevDecision({
        decision_type: 'risk_assessment',
        data_classification: 'non_sensitive',
        state: '테스트 상태',
        questions: {
          q1: { type: 'score', instructions: '점수 질문', criteria: ['단계1만있음'] }
        }
      });
      const pass = res.ok === false && res.fallback_used === true && res.error_type === 'INVALID_SCORE_CRITERIA' && currentFetchCount === 0;
      return { ok: pass, reason: `res=${res.error_type}` };
    });

    // T07: true/false가 아닌 Boolean criteria 거부
    await assertTest('T07', 'true/false 외 키를 가진 Boolean criteria 거부', async () => {
      const res = await evaluateJevDecision({
        decision_type: 'check',
        data_classification: 'non_sensitive',
        state: '테스트 상태',
        questions: {
          q1: { type: 'boolean', instructions: '참/거짓 질문', criteria: { yes: '예', no: '아니오' } }
        }
      });
      const pass = res.ok === false && res.fallback_used === true && res.error_type === 'INVALID_BOOLEAN_CRITERIA' && currentFetchCount === 0;
      return { ok: pass, reason: `res=${res.error_type}` };
    });

    // T08: question과 instructions가 동시에 존재하는 질문 거부
    await assertTest('T08', 'question과 instructions 동시 존재 질문 거부', async () => {
      const res = await evaluateJevDecision({
        decision_type: 'task_route',
        data_classification: 'non_sensitive',
        state: '테스트 상태',
        questions: {
          q1: { type: 'choice', question: '질문1', instructions: '설명1', criteria: { opt1: '설명1', opt2: '설명2' } }
        }
      });
      const pass = res.ok === false && res.fallback_used === true && res.error_type === 'INVALID_QUESTION_SCHEMA' && currentFetchCount === 0;
      return { ok: pass, reason: `res=${res.error_type}` };
    });

    // T09: 순환 객체 입력 거부
    await assertTest('T09', '순환 객체 안전 거부', async () => {
      const circularReq = {
        decision_type: 'task_route',
        data_classification: 'non_sensitive',
        state: '테스트 상태',
        questions: {
          q1: { type: 'choice', instructions: '질문', criteria: { opt1: '설명1', opt2: '설명2' } }
        }
      };
      circularReq.self = circularReq;
      const res = await evaluateJevDecision(circularReq);
      const pass = res.ok === false && res.fallback_used === true && (res.error_type === 'INVALID_REQUEST_OBJECT' || res.error_type === 'JSON_STRINGIFY_FAILED') && currentFetchCount === 0;
      return { ok: pass, reason: `res=${res.error_type}` };
    });

    console.log('=== [2] 오프라인 Provider 응답 표본 검사 (기대: fetch 1회) ===');

    // T10: 정상 Choice 응답
    await assertTest('T10', '정상 Choice 응답 검증 및 안전 투영', async () => {
      currentMockResponse = new Response(JSON.stringify({
        answers: {
          q1: { type: 'choice', choice: 'opt1', probabilities: { opt1: 0.9, opt2: 0.1 } }
        },
        usage: { inputTokens: 50, outputTokens: 10, totalTokens: 60, cost: 0 }
      }), { status: 200, headers: { 'Content-Type': 'application/json' } });

      const res = await evaluateJevDecision({
        decision_type: 'task_route',
        data_classification: 'non_sensitive',
        state: '테스트 상태',
        existing_route: 'opt1',
        questions: {
          q1: { type: 'choice', instructions: '질문', criteria: { opt1: '설명1', opt2: '설명2' } }
        }
      });

      const pass = res.ok === true &&
        res.answers?.q1?.choice === 'opt1' &&
        res.answers?.q1?.probabilities?.opt1 === 0.9 &&
        res.usage?.total_tokens === 60 &&
        res.agreement === true &&
        res.fallback_used === false &&
        currentFetchCount === 1;
      return { ok: pass, reason: `ok=${res.ok}, ans=${JSON.stringify(res.answers)}, agree=${res.agreement}` };
    });

    // T11: 정상 Score 응답
    await assertTest('T11', '정상 Score 응답 검증 및 안전 투영', async () => {
      currentMockResponse = new Response(JSON.stringify({
        answers: {
          q1: { type: 'score', score: 2, probabilities: { '0': 0.1, '1': 0.2, '2': 0.7 } }
        },
        usage: { inputTokens: 40, outputTokens: 8 }
      }), { status: 200, headers: { 'Content-Type': 'application/json' } });

      const res = await evaluateJevDecision({
        decision_type: 'risk_assessment',
        data_classification: 'non_sensitive',
        state: '테스트 상태',
        existing_route: 2,
        questions: {
          q1: { type: 'score', instructions: '점수 질문', criteria: ['낮음', '중간', '높음'] }
        }
      });

      const pass = res.ok === true &&
        res.answers?.q1?.score === 2 &&
        res.usage?.total_tokens === 48 &&
        res.agreement === true &&
        currentFetchCount === 1;
      return { ok: pass, reason: `ok=${res.ok}, score=${res.answers?.q1?.score}` };
    });

    // T12: 정상 Boolean 응답
    await assertTest('T12', '정상 Boolean 응답 검증 및 안전 투영', async () => {
      currentMockResponse = new Response(JSON.stringify({
        answers: {
          q1: { type: 'boolean', probability: 0.85 }
        },
        usage: { inputTokens: 30, outputTokens: 5, totalTokens: 35 }
      }), { status: 200, headers: { 'Content-Type': 'application/json' } });

      const res = await evaluateJevDecision({
        decision_type: 'check',
        data_classification: 'non_sensitive',
        state: '테스트 상태',
        questions: {
          q1: { type: 'boolean', instructions: '참거짓 질문' }
        }
      });

      const pass = res.ok === true &&
        res.answers?.q1?.probability === 0.85 &&
        res.agreement === null &&
        currentFetchCount === 1;
      return { ok: pass, reason: `ok=${res.ok}, prob=${res.answers?.q1?.probability}` };
    });

    // T13: answers 필드 없는 응답 거부 (B1)
    await assertTest('T13', 'answers 필드 누락 응답 거부', async () => {
      currentMockResponse = new Response(JSON.stringify({
        message: 'ok status but no answers object',
        result: 'something'
      }), { status: 200, headers: { 'Content-Type': 'application/json' } });

      const res = await evaluateJevDecision({
        decision_type: 'task_route',
        data_classification: 'non_sensitive',
        state: '테스트 상태',
        questions: {
          q1: { type: 'choice', instructions: '질문', criteria: { opt1: '설명1', opt2: '설명2' } }
        }
      });

      const pass = res.ok === false && res.fallback_used === true && res.error_type === 'INVALID_RESPONSE_SCHEMA' && currentFetchCount === 1;
      return { ok: pass, reason: `res=${res.error_type}` };
    });

    // T14: 질문 답 누락 응답 거부
    await assertTest('T14', '요청 질문 키 누락 응답 거부', async () => {
      currentMockResponse = new Response(JSON.stringify({
        answers: {
          q1: { type: 'choice', choice: 'opt1' }
        }
      }), { status: 200, headers: { 'Content-Type': 'application/json' } });

      const res = await evaluateJevDecision({
        decision_type: 'task_route',
        data_classification: 'non_sensitive',
        state: '테스트 상태',
        questions: {
          q1: { type: 'choice', instructions: '질문1', criteria: { opt1: '설명1', opt2: '설명2' } },
          q2: { type: 'choice', instructions: '질문2', criteria: { optA: '설명A', optB: '설명B' } }
        }
      });

      const pass = res.ok === false && res.fallback_used === true && res.error_type === 'INVALID_RESPONSE_SCHEMA' && currentFetchCount === 1;
      return { ok: pass, reason: `res=${res.error_type}` };
    });

    // T15: 질문 답 추가 응답 거부
    await assertTest('T15', '요청하지 않은 추가 답 키 포함 응답 거부', async () => {
      currentMockResponse = new Response(JSON.stringify({
        answers: {
          q1: { type: 'choice', choice: 'opt1' },
          extra_q: { type: 'choice', choice: 'unknown' }
        }
      }), { status: 200, headers: { 'Content-Type': 'application/json' } });

      const res = await evaluateJevDecision({
        decision_type: 'task_route',
        data_classification: 'non_sensitive',
        state: '테스트 상태',
        questions: {
          q1: { type: 'choice', instructions: '질문1', criteria: { opt1: '설명1', opt2: '설명2' } }
        }
      });

      const pass = res.ok === false && res.fallback_used === true && res.error_type === 'INVALID_RESPONSE_SCHEMA' && currentFetchCount === 1;
      return { ok: pass, reason: `res=${res.error_type}` };
    });

    // T16: 답 type 불일치 거부
    await assertTest('T16', '답 type 불일치 응답 거부', async () => {
      currentMockResponse = new Response(JSON.stringify({
        answers: {
          q1: { type: 'score', score: 1 }
        }
      }), { status: 200, headers: { 'Content-Type': 'application/json' } });

      const res = await evaluateJevDecision({
        decision_type: 'task_route',
        data_classification: 'non_sensitive',
        state: '테스트 상태',
        questions: {
          q1: { type: 'choice', instructions: '질문1', criteria: { opt1: '설명1', opt2: '설명2' } }
        }
      });

      const pass = res.ok === false && res.fallback_used === true && res.error_type === 'INVALID_RESPONSE_SCHEMA' && currentFetchCount === 1;
      return { ok: pass, reason: `res=${res.error_type}` };
    });

    // T17: Choice 후보 객체의 상속 속성을 후보로 오인하지 않는지 검사
    await assertTest('T17', 'Choice 상속 속성 선택값 응답 거부', async () => {
      currentMockResponse = new Response(JSON.stringify({
        answers: {
          q1: { type: 'choice', choice: 'toString' }
        }
      }), { status: 200, headers: { 'Content-Type': 'application/json' } });

      const res = await evaluateJevDecision({
        decision_type: 'task_route',
        data_classification: 'non_sensitive',
        state: '테스트 상태',
        questions: {
          q1: { type: 'choice', instructions: '질문1', criteria: { opt1: '설명1', opt2: '설명2' } }
        }
      });

      const pass = res.ok === false && res.fallback_used === true && res.error_type === 'INVALID_RESPONSE_SCHEMA' && currentFetchCount === 1;
      return { ok: pass, reason: `res=${res.error_type}` };
    });

    // T18: Score 범위 밖 값 거부
    await assertTest('T18', 'Score 범위 밖(3개 criteria에 score 5) 응답 거부', async () => {
      currentMockResponse = new Response(JSON.stringify({
        answers: {
          q1: { type: 'score', score: 5 }
        }
      }), { status: 200, headers: { 'Content-Type': 'application/json' } });

      const res = await evaluateJevDecision({
        decision_type: 'risk_assessment',
        data_classification: 'non_sensitive',
        state: '테스트 상태',
        questions: {
          q1: { type: 'score', instructions: '점수 질문', criteria: ['낮음', '중간', '높음'] }
        }
      });

      const pass = res.ok === false && res.fallback_used === true && res.error_type === 'INVALID_RESPONSE_SCHEMA' && currentFetchCount === 1;
      return { ok: pass, reason: `res=${res.error_type}` };
    });

    // T19: Boolean 확률 범위 밖 값 거부
    await assertTest('T19', 'Boolean probability 범위 밖(1.5) 응답 거부', async () => {
      currentMockResponse = new Response(JSON.stringify({
        answers: {
          q1: { type: 'boolean', probability: 1.5 }
        }
      }), { status: 200, headers: { 'Content-Type': 'application/json' } });

      const res = await evaluateJevDecision({
        decision_type: 'check',
        data_classification: 'non_sensitive',
        state: '테스트 상태',
        questions: {
          q1: { type: 'boolean', instructions: '참거짓 질문' }
        }
      });

      const pass = res.ok === false && res.fallback_used === true && res.error_type === 'INVALID_RESPONSE_SCHEMA' && currentFetchCount === 1;
      return { ok: pass, reason: `res=${res.error_type}` };
    });

    // T20: 잘못된 probabilities(음수 확률) 거부
    await assertTest('T20', '잘못된 probabilities(음수 확률) 응답 거부', async () => {
      currentMockResponse = new Response(JSON.stringify({
        answers: {
          q1: { type: 'choice', choice: 'opt1', probabilities: { opt1: -0.2, opt2: 1.2 } }
        }
      }), { status: 200, headers: { 'Content-Type': 'application/json' } });

      const res = await evaluateJevDecision({
        decision_type: 'task_route',
        data_classification: 'non_sensitive',
        state: '테스트 상태',
        questions: {
          q1: { type: 'choice', instructions: '질문1', criteria: { opt1: '설명1', opt2: '설명2' } }
        }
      });

      const pass = res.ok === false && res.fallback_used === true && res.error_type === 'INVALID_RESPONSE_SCHEMA' && currentFetchCount === 1;
      return { ok: pass, reason: `res=${res.error_type}` };
    });

    // T21: usage가 있으면 입력·출력 토큰이 모두 필수인지 검사
    await assertTest('T21', '필수 토큰이 없는 usage 응답 거부', async () => {
      currentMockResponse = new Response(JSON.stringify({
        answers: {
          q1: { type: 'choice', choice: 'opt1' }
        },
        usage: {}
      }), { status: 200, headers: { 'Content-Type': 'application/json' } });

      const res = await evaluateJevDecision({
        decision_type: 'task_route',
        data_classification: 'non_sensitive',
        state: '테스트 상태',
        questions: {
          q1: { type: 'choice', instructions: '질문1', criteria: { opt1: '설명1', opt2: '설명2' } }
        }
      });

      const pass = res.ok === false && res.fallback_used === true && res.error_type === 'INVALID_RESPONSE_SCHEMA' && currentFetchCount === 1;
      return { ok: pass, reason: `res=${res.error_type}` };
    });

    // T22: 추가 원시 필드가 성공 출력에서 완전히 격리되는지 검증
    await assertTest('T22', '추가 원시 필드 격리 투영 검증', async () => {
      currentMockResponse = new Response(JSON.stringify({
        answers: {
          q1: { type: 'choice', choice: 'opt1', raw_leak_prop: 'confidential_answer_prop' }
        },
        leak_root: 'confidential_root_prop',
        providerMetadata: { gateway: { internal_trace: 'trace_12345' } },
        usage: { inputTokens: 10, outputTokens: 5 }
      }), { status: 200, headers: { 'Content-Type': 'application/json' } });

      const res = await evaluateJevDecision({
        decision_type: 'task_route',
        data_classification: 'non_sensitive',
        state: '테스트 상태',
        questions: {
          q1: { type: 'choice', instructions: '질문1', criteria: { opt1: '설명1', opt2: '설명2' } }
        }
      });

      const resStr = JSON.stringify(res);
      const noLeak = !resStr.includes('raw_leak_prop') &&
        !resStr.includes('confidential_answer_prop') &&
        !resStr.includes('leak_root') &&
        !resStr.includes('confidential_root_prop') &&
        !resStr.includes('internal_trace');

      const pass = res.ok === true && noLeak && res.answers?.q1?.choice === 'opt1' && currentFetchCount === 1;
      return { ok: pass, reason: `ok=${res.ok}, noLeak=${noLeak}` };
    });

    console.log('---');
    console.log(`오프라인 검사 종합: ${passedTests}/${totalTests} PASS (모의 fetch 호출: ${totalFetchCalls})`);

    const allOk = passedTests === totalTests && totalTests >= 22;
    return allOk;
  } finally {
    // 환경 및 fetch 원상 복구
    if (originalApiKey !== undefined) {
      process.env.AI_GATEWAY_API_KEY = originalApiKey;
    } else {
      delete process.env.AI_GATEWAY_API_KEY;
    }
    globalThis.fetch = originalFetch;
  }
}

// 실제 Canary 실행 (명시적 이중 관문: --live 인자 + JEV_ALLOW_LIVE_CANARY === '1')
async function runLiveCanary() {
  console.log('=== [3] 실제 Live Canary 시나리오 3건 순차 실행 ===');

  const scenarios = [
    {
      id: 'S1',
      name: '문서 업무 분류',
      expected: 'documentation',
      existing_route: 'documentation',
      qKey: 'domain',
      request: {
        decision_type: 'task_route',
        data_classification: 'non_sensitive',
        state: '작업 요청은 운영 절차서의 표현과 문서 사이 참조만 고치는 것이다. 프로그램 소스 변경은 없다.',
        existing_route: 'documentation',
        questions: {
          domain: {
            type: 'choice',
            instructions: '이 작업의 주 처리 영역은 무엇인가?',
            criteria: {
              documentation: '문서 내용, 표현, 구조, 문서 간 참조를 다룬다.',
              code: '프로그램 소스나 실행 로직을 바꾼다.',
              testing: '검사 코드나 검증 절차를 바꾼다.',
              security: '권한, 인증, 비밀 또는 보안 위험을 다룬다.'
            }
          }
        }
      }
    },
    {
      id: 'S2',
      name: '복구 불가능 작업 위험 분류',
      expected: 'critical',
      existing_route: 'critical',
      qKey: 'risk_level',
      request: {
        decision_type: 'risk_assessment',
        data_classification: 'non_sensitive',
        state: '운영 중인 고객 데이터 전체를 복구 불가능하게 삭제하려는 작업이다.',
        existing_route: 'critical',
        questions: {
          risk_level: {
            type: 'choice',
            instructions: '이 작업의 위험 등급은 무엇인가?',
            criteria: {
              low: '되돌리기 쉽고 영향이 작다.',
              medium: '제한된 범위에 영향이 있고 복구 절차가 있다.',
              high: '큰 영향이 있거나 별도 승인과 복구 준비가 필요하다.',
              critical: '운영 데이터의 복구 불가능한 손실이나 심각한 보안 영향을 일으킬 수 있다.'
            }
          }
        }
      }
    },
    {
      id: 'S3',
      name: '일시 오류 다음 행동',
      expected: 'retry',
      existing_route: 'retry',
      qKey: 'next_action',
      request: {
        decision_type: 'error_recovery',
        data_classification: 'non_sensitive',
        state: '외부 시험 서비스 호출이 한 번 시간 초과되었다. 입력값과 설정은 유효하고 허용된 재시도는 1회 남아 있다.',
        existing_route: 'retry',
        questions: {
          next_action: {
            type: 'choice',
            instructions: '다음 행동으로 가장 적절한 것은 무엇인가?',
            criteria: {
              continue: '현재 결과를 성공으로 보고 다음 단계로 간다.',
              retry: '정해진 한도 안에서 같은 호출을 한 번 더 시도한다.',
              stop: '추가 시도 없이 작업을 종료한다.',
              human_review: '사람의 판단이나 새 승인이 있어야 진행한다.'
            }
          }
        }
      }
    }
  ];

  let matchCount = 0;
  let validFormatCount = 0;
  let fallbackCount = 0;
  const latencies = [];
  let totalInputTokens = 0;
  let totalOutputTokens = 0;
  let totalTokens = 0;
  let totalCost = null;

  for (const sc of scenarios) {
    const res = await evaluateJevDecision(sc.request);
    const latency = res.latency_ms || 0;
    latencies.push(latency);

    let actualVal = undefined;
    let formatValid = false;

    if (res.ok && res.answers && !res.fallback_used) {
      const ansObj = res.answers[sc.qKey];
      if (ansObj && ansObj.type === 'choice' && typeof ansObj.choice === 'string') {
        actualVal = ansObj.choice;
        formatValid = true;
      }
    }

    if (formatValid) validFormatCount++;
    if (res.fallback_used) fallbackCount++;

    const isMatch = actualVal === sc.expected;
    if (isMatch) matchCount++;

    let inTok = 0, outTok = 0, totTok = 0;
    if (res.usage) {
      inTok = res.usage.input_tokens || 0;
      outTok = res.usage.output_tokens || 0;
      totTok = res.usage.total_tokens || (inTok + outTok);
      totalInputTokens += inTok;
      totalOutputTokens += outTok;
      totalTokens += totTok;
      if (res.usage.cost != null) {
        totalCost = (totalCost || 0) + res.usage.cost;
      }
    }

    const costStr = res.usage && res.usage.cost != null ? ` | 비용: $${res.usage.cost}` : '';

    console.log(
      `[${sc.id}] 일치: ${isMatch ? 'TRUE' : 'FALSE'} | 형식: ${formatValid ? 'VALID' : 'INVALID'} | ` +
      `응답시간: ${latency}ms | 토큰: in=${inTok} out=${outTok} tot=${totTok}${costStr} | 복귀: ${res.fallback_used ? 'YES' : 'NO'}`
    );
  }

  const avgLatency = Math.round(latencies.reduce((a, b) => a + b, 0) / latencies.length);
  const sortedLatencies = [...latencies].sort((a, b) => a - b);
  const mid = Math.floor(sortedLatencies.length / 2);
  const medianLatency = sortedLatencies.length % 2 !== 0 ? sortedLatencies[mid] : Math.round((sortedLatencies[mid - 1] + sortedLatencies[mid]) / 2);
  const maxLatency = Math.max(...latencies);
  const costSummary = totalCost != null ? `$${totalCost.toFixed(6)}` : 'N/A (비용 정보 미제공)';

  console.log('---');
  console.log(`Live Canary 요약: 일치 ${matchCount}/${scenarios.length} · 형식 ${validFormatCount}/${scenarios.length} · 복귀 ${fallbackCount}/${scenarios.length}`);
  console.log(`응답시간: 평균 ${avgLatency}ms · 중앙값 ${medianLatency}ms · 최대 ${maxLatency}ms`);
  console.log(`합계 토큰: in=${totalInputTokens} out=${totalOutputTokens} tot=${totalTokens}`);
  console.log(`합계 비용: ${costSummary}`);

  const allPassed = matchCount === scenarios.length && validFormatCount === scenarios.length && fallbackCount === 0;
  return allPassed;
}

async function main() {
  const allowLive = process.argv.includes('--live') && process.env.JEV_ALLOW_LIVE_CANARY === '1';

  // 1. 오프라인 테스트 스위트 실행
  const offlinePassed = await runOfflineTestSuite();
  if (!offlinePassed) {
    console.error('오프라인 검사 실패로 종료합니다.');
    process.exit(1);
  }

  // 2. 라이브 Canary 실행 여부 판단
  if (allowLive) {
    const livePassed = await runLiveCanary();
    process.exit(livePassed ? 0 : 1);
  } else {
    console.log('오프라인 모드 검사 완료 (라이브 관문 미지정으로 실제 외부 호출 0건 유지).');
    process.exit(0);
  }
}

main().catch(err => {
  console.error('테스트 실행 중 예외 발생:', err.message || err);
  process.exit(1);
});

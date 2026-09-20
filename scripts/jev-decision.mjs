/**
 * jev-decision.mjs — Vercel AI Gateway typesafe-ai/jev 최소 실행 연결 (Harness 3.1 R1)
 * 의존성 없음 (Node 24 ESM 기본 내장 기능만 사용)
 *
 * 계약:
 * - data_classification은 오직 'non_sensitive'만 허용
 * - 허용 최상위 키 5개만 허용: decision_type, data_classification, state, questions, existing_route
 * - expected 필드 제거
 * - 비밀/키/인증 관련 필드명 사전 차단 (순환 객체 안전)
 * - 요청 최대 24,000자, 질문 1~8개 제한
 * - 질문 형식 엄격 검증 (choice: 2~255, score: 2~10, boolean: true/false 2개)
 * - 고정 오류 코드만 반환 (입력값/필드명/질문ID 미노출)
 * - Provider 응답의 엄격한 검증 및 안전 투영 (원시 응답·추가 필드 제거)
 * - 타임아웃 8초, 재시도 0회 (최대 1회 호출)
 * - CLI 실행 시 성공=0, Router 복귀=2
 */

import { fileURLToPath } from 'node:url';
import path from 'node:path';
import { execSync } from 'node:child_process';

const ALLOWED_TOP_KEYS = new Set([
  'decision_type',
  'data_classification',
  'state',
  'questions',
  'existing_route'
]);

const SAFE_ID_REGEX = /^[a-zA-Z][a-zA-Z0-9_-]{0,63}$/;
const SENSITIVE_WORDS = ['secret', 'password', 'credential', 'api_key', 'apikey', 'token'];

function checkSensitiveAndCircular(obj, seen = new WeakSet()) {
  if (!obj || typeof obj !== 'object') return false;
  if (seen.has(obj)) {
    throw new Error('CIRCULAR_STRUCTURE');
  }
  seen.add(obj);

  if (Array.isArray(obj)) {
    for (const item of obj) {
      if (typeof item === 'object' && item !== null) {
        if (checkSensitiveAndCircular(item, seen)) return true;
      }
    }
    return false;
  }

  for (const key of Object.keys(obj)) {
    const normalizedKey = key.toLowerCase().replace(/[-_]/g, '');
    if (SENSITIVE_WORDS.some(w => normalizedKey.includes(w.replace(/[-_]/g, '')))) {
      return true;
    }
    if (typeof obj[key] === 'object' && obj[key] !== null) {
      if (checkSensitiveAndCircular(obj[key], seen)) return true;
    }
  }
  return false;
}

function makeFallbackResult(decisionType, errorType, statusCode, latencyMs, existingRoute = null) {
  return {
    ok: false,
    decision_type: decisionType,
    provider: 'vercel_ai_gateway',
    model: 'typesafe-ai/jev',
    latency_ms: latencyMs,
    fallback_used: true,
    error_type: errorType,
    status_code: statusCode,
    answers: null,
    usage: null,
    agreement: null,
    existing_route: existingRoute
  };
}

export async function evaluateJevDecision(request) {
  const t0 = Date.now();
  let decisionType = 'task_route';

  // 1. 객체 기본 검증
  if (!request || typeof request !== 'object' || Array.isArray(request)) {
    return makeFallbackResult(decisionType, 'INVALID_REQUEST_OBJECT', null, Date.now() - t0);
  }

  if (typeof request.decision_type === 'string' && SAFE_ID_REGEX.test(request.decision_type)) {
    decisionType = request.decision_type;
  }

  // 2. 순환 객체 및 민감 키 검사
  try {
    if (checkSensitiveAndCircular(request)) {
      return makeFallbackResult(decisionType, 'SENSITIVE_KEY_DETECTED', null, Date.now() - t0);
    }
  } catch (err) {
    if (err.message === 'CIRCULAR_STRUCTURE') {
      return makeFallbackResult(decisionType, 'INVALID_REQUEST_OBJECT', null, Date.now() - t0);
    }
    return makeFallbackResult(decisionType, 'INVALID_REQUEST_OBJECT', null, Date.now() - t0);
  }

  // 3. data_classification = 'non_sensitive' 엄격 검증
  if (request.data_classification !== 'non_sensitive') {
    return makeFallbackResult(decisionType, 'DATA_CLASSIFICATION_NOT_NON_SENSITIVE', null, Date.now() - t0);
  }

  // 4. 허용 필드 검증 (알 수 없는 필드, expected 등 거부)
  for (const k of Object.keys(request)) {
    if (!ALLOWED_TOP_KEYS.has(k)) {
      return makeFallbackResult(decisionType, 'UNAUTHORIZED_FIELD', null, Date.now() - t0);
    }
  }

  // 5. 전체 직렬화 크기 검사 (24,000자 초과 거부)
  let reqJson;
  try {
    reqJson = JSON.stringify(request);
  } catch {
    return makeFallbackResult(decisionType, 'JSON_STRINGIFY_FAILED', null, Date.now() - t0);
  }
  if (reqJson.length > 24000) {
    return makeFallbackResult(decisionType, 'REQUEST_TOO_LARGE', null, Date.now() - t0);
  }

  // 6. decision_type 형식 검사
  if (typeof request.decision_type !== 'string' || !SAFE_ID_REGEX.test(request.decision_type)) {
    return makeFallbackResult(decisionType, 'INVALID_REQUEST_OBJECT', null, Date.now() - t0);
  }

  // 7. state 형식 검사
  if (typeof request.state !== 'string' || !request.state.trim()) {
    return makeFallbackResult(decisionType, 'INVALID_REQUEST_OBJECT', null, Date.now() - t0);
  }

  // 8. existing_route 검사 (선택적)
  let safeExistingRoute = null;
  if (request.existing_route !== undefined && request.existing_route !== null) {
    if (typeof request.existing_route === 'string') {
      if (!SAFE_ID_REGEX.test(request.existing_route)) {
        return makeFallbackResult(decisionType, 'INVALID_REQUEST_OBJECT', null, Date.now() - t0);
      }
      safeExistingRoute = request.existing_route;
    } else if (typeof request.existing_route === 'number') {
      if (!Number.isFinite(request.existing_route)) {
        return makeFallbackResult(decisionType, 'INVALID_REQUEST_OBJECT', null, Date.now() - t0);
      }
      safeExistingRoute = request.existing_route;
    } else {
      return makeFallbackResult(decisionType, 'INVALID_REQUEST_OBJECT', null, Date.now() - t0);
    }
  }

  // 9. questions 유효성 검사
  if (!request.questions || typeof request.questions !== 'object' || Array.isArray(request.questions)) {
    return makeFallbackResult(decisionType, 'INVALID_QUESTION_SCHEMA', null, Date.now() - t0, safeExistingRoute);
  }

  const qKeys = Object.keys(request.questions);
  if (qKeys.length < 1 || qKeys.length > 8) {
    return makeFallbackResult(decisionType, 'INVALID_QUESTION_COUNT', null, Date.now() - t0, safeExistingRoute);
  }

  const allowedQKeys = new Set(['type', 'question', 'instructions', 'criteria']);

  for (const qk of qKeys) {
    if (!SAFE_ID_REGEX.test(qk)) {
      return makeFallbackResult(decisionType, 'INVALID_QUESTION_SCHEMA', null, Date.now() - t0, safeExistingRoute);
    }
    const q = request.questions[qk];
    if (!q || typeof q !== 'object' || Array.isArray(q)) {
      return makeFallbackResult(decisionType, 'INVALID_QUESTION_SCHEMA', null, Date.now() - t0, safeExistingRoute);
    }

    // 허용 키 외 다른 키 차단
    for (const key of Object.keys(q)) {
      if (!allowedQKeys.has(key)) {
        return makeFallbackResult(decisionType, 'INVALID_QUESTION_SCHEMA', null, Date.now() - t0, safeExistingRoute);
      }
    }

    // type 검사
    if (typeof q.type !== 'string' || !['choice', 'score', 'boolean'].includes(q.type)) {
      return makeFallbackResult(decisionType, 'UNSUPPORTED_QUESTION_TYPE', null, Date.now() - t0, safeExistingRoute);
    }

    // question / instructions 검사: 둘 중 정확히 하나만 비어 있지 않은 문자열
    const hasQuestion = typeof q.question === 'string' && q.question.trim().length > 0;
    const hasInstructions = typeof q.instructions === 'string' && q.instructions.trim().length > 0;
    if (q.question !== undefined && !hasQuestion) {
      return makeFallbackResult(decisionType, 'MISSING_QUESTION_TEXT', null, Date.now() - t0, safeExistingRoute);
    }
    if (q.instructions !== undefined && !hasInstructions) {
      return makeFallbackResult(decisionType, 'MISSING_QUESTION_TEXT', null, Date.now() - t0, safeExistingRoute);
    }
    if (hasQuestion && hasInstructions) {
      return makeFallbackResult(decisionType, 'INVALID_QUESTION_SCHEMA', null, Date.now() - t0, safeExistingRoute);
    }
    if (!hasQuestion && !hasInstructions) {
      return makeFallbackResult(decisionType, 'MISSING_QUESTION_TEXT', null, Date.now() - t0, safeExistingRoute);
    }

    // criteria 검사
    if (q.type === 'choice') {
      if (!q.criteria || typeof q.criteria !== 'object' || Array.isArray(q.criteria)) {
        return makeFallbackResult(decisionType, 'INVALID_CHOICE_CRITERIA', null, Date.now() - t0, safeExistingRoute);
      }
      const cKeys = Object.keys(q.criteria);
      if (cKeys.length < 2 || cKeys.length > 255) {
        return makeFallbackResult(decisionType, 'INVALID_CHOICE_CRITERIA', null, Date.now() - t0, safeExistingRoute);
      }
      for (const ck of cKeys) {
        if (!SAFE_ID_REGEX.test(ck)) {
          return makeFallbackResult(decisionType, 'INVALID_CHOICE_CRITERIA', null, Date.now() - t0, safeExistingRoute);
        }
        const desc = q.criteria[ck];
        if (typeof desc !== 'string' || !desc.trim()) {
          return makeFallbackResult(decisionType, 'INVALID_CHOICE_CRITERIA', null, Date.now() - t0, safeExistingRoute);
        }
      }
    } else if (q.type === 'score') {
      if (!Array.isArray(q.criteria) || q.criteria.length < 2 || q.criteria.length > 10) {
        return makeFallbackResult(decisionType, 'INVALID_SCORE_CRITERIA', null, Date.now() - t0, safeExistingRoute);
      }
      for (const step of q.criteria) {
        if (typeof step !== 'string' || !step.trim()) {
          return makeFallbackResult(decisionType, 'INVALID_SCORE_CRITERIA', null, Date.now() - t0, safeExistingRoute);
        }
      }
    } else if (q.type === 'boolean') {
      if (q.criteria !== undefined && q.criteria !== null) {
        if (typeof q.criteria !== 'object' || Array.isArray(q.criteria)) {
          return makeFallbackResult(decisionType, 'INVALID_BOOLEAN_CRITERIA', null, Date.now() - t0, safeExistingRoute);
        }
        const bKeys = Object.keys(q.criteria).sort();
        if (bKeys.length !== 2 || bKeys[0] !== 'false' || bKeys[1] !== 'true') {
          return makeFallbackResult(decisionType, 'INVALID_BOOLEAN_CRITERIA', null, Date.now() - t0, safeExistingRoute);
        }
        if (typeof q.criteria.true !== 'string' || !q.criteria.true.trim() ||
            typeof q.criteria.false !== 'string' || !q.criteria.false.trim()) {
          return makeFallbackResult(decisionType, 'INVALID_BOOLEAN_CRITERIA', null, Date.now() - t0, safeExistingRoute);
        }
      }
    }
  }

  // 10. API 키 획득
  let apiKey = (process.env.AI_GATEWAY_API_KEY || '').trim();
  if (!apiKey && process.platform === 'win32') {
    try {
      apiKey = execSync(
        'powershell -NoProfile -Command "[System.Environment]::GetEnvironmentVariable(\'AI_GATEWAY_API_KEY\', \'User\')"',
        { encoding: 'utf8', stdio: ['pipe', 'pipe', 'ignore'] }
      ).trim();
    } catch {}
  }

  if (!apiKey) {
    return makeFallbackResult(decisionType, 'AUTHENTICATION_FAILED', null, Date.now() - t0, safeExistingRoute);
  }

  // 11. Gateway questions 페이로드 생성
  const gatewayQuestions = {};
  for (const qk of qKeys) {
    const q = request.questions[qk];
    gatewayQuestions[qk] = {
      type: q.type,
      instructions: q.instructions || q.question || '',
      criteria: q.criteria
    };
  }

  // 12. HTTP 호출 (타임아웃 8초, 재시도 0회)
  const controller = new AbortController();
  const timeoutTimer = setTimeout(() => controller.abort(), 8000);
  const reqStart = Date.now();
  let res;

  try {
    res = await fetch('https://ai-gateway.vercel.sh/v4/ai/evaluation-model', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${apiKey}`,
        'Content-Type': 'application/json',
        'ai-gateway-protocol-version': '0.0.1',
        'ai-gateway-auth-method': 'api-key',
        'ai-evaluation-model-specification-version': '4',
        'ai-model-id': 'typesafe-ai/jev'
      },
      body: JSON.stringify({
        state: request.state,
        questions: gatewayQuestions
      }),
      signal: controller.signal
    });
  } catch (err) {
    clearTimeout(timeoutTimer);
    const latencyMs = Date.now() - reqStart;
    const isTimeout = controller.signal.aborted || err?.name === 'AbortError';
    return makeFallbackResult(decisionType, isTimeout ? 'TIMEOUT' : 'GATEWAY_ERROR', null, latencyMs, safeExistingRoute);
  }

  if (!res.ok) {
    clearTimeout(timeoutTimer);
    const latencyMs = Date.now() - reqStart;
    const errorType = (res.status === 401 || res.status === 403) ? 'AUTHENTICATION_FAILED' : 'GATEWAY_ERROR';
    return makeFallbackResult(decisionType, errorType, res.status, latencyMs, safeExistingRoute);
  }

  // 13. 응답 파싱 및 엄격 검증
  let data;
  try {
    data = await res.json();
  } catch (err) {
    clearTimeout(timeoutTimer);
    const latencyMs = Date.now() - reqStart;
    const isTimeout = controller.signal.aborted || err?.name === 'AbortError';
    return makeFallbackResult(decisionType, isTimeout ? 'TIMEOUT' : 'INVALID_RESPONSE_SCHEMA', res.status, latencyMs, safeExistingRoute);
  }
  clearTimeout(timeoutTimer);
  const latencyMs = Date.now() - reqStart;

  // 13.1 최상위 응답 검사
  if (!data || typeof data !== 'object' || Array.isArray(data)) {
    return makeFallbackResult(decisionType, 'INVALID_RESPONSE_SCHEMA', res.status, latencyMs, safeExistingRoute);
  }

  // 13.2 answers 객체 검사
  if (!data.answers || typeof data.answers !== 'object' || Array.isArray(data.answers)) {
    return makeFallbackResult(decisionType, 'INVALID_RESPONSE_SCHEMA', res.status, latencyMs, safeExistingRoute);
  }

  // 13.3 answers 키 집합 대조
  const reqQKeySorted = [...qKeys].sort();
  const ansQKeySorted = Object.keys(data.answers).sort();
  if (reqQKeySorted.length !== ansQKeySorted.length || !reqQKeySorted.every((k, i) => k === ansQKeySorted[i])) {
    return makeFallbackResult(decisionType, 'INVALID_RESPONSE_SCHEMA', res.status, latencyMs, safeExistingRoute);
  }

  // 13.4 각 답의 엄격한 유효성 검증 및 안전 투영
  const projectedAnswers = {};
  for (const qk of reqQKeySorted) {
    const q = request.questions[qk];
    const ans = data.answers[qk];
    if (!ans || typeof ans !== 'object' || Array.isArray(ans)) {
      return makeFallbackResult(decisionType, 'INVALID_RESPONSE_SCHEMA', res.status, latencyMs, safeExistingRoute);
    }
    if (ans.type !== q.type) {
      return makeFallbackResult(decisionType, 'INVALID_RESPONSE_SCHEMA', res.status, latencyMs, safeExistingRoute);
    }

    if (q.type === 'choice') {
      if (typeof ans.choice !== 'string' || !Object.hasOwn(q.criteria, ans.choice)) {
        return makeFallbackResult(decisionType, 'INVALID_RESPONSE_SCHEMA', res.status, latencyMs, safeExistingRoute);
      }
      projectedAnswers[qk] = { type: 'choice', choice: ans.choice };
    } else if (q.type === 'score') {
      if (typeof ans.score !== 'number' || !Number.isFinite(ans.score) || ans.score < 0 || ans.score > (q.criteria.length - 1)) {
        return makeFallbackResult(decisionType, 'INVALID_RESPONSE_SCHEMA', res.status, latencyMs, safeExistingRoute);
      }
      projectedAnswers[qk] = { type: 'score', score: ans.score };
    } else if (q.type === 'boolean') {
      if (typeof ans.probability !== 'number' || !Number.isFinite(ans.probability) || ans.probability < 0 || ans.probability > 1) {
        return makeFallbackResult(decisionType, 'INVALID_RESPONSE_SCHEMA', res.status, latencyMs, safeExistingRoute);
      }
      projectedAnswers[qk] = { type: 'boolean', probability: ans.probability };
    }

    // probabilities 검증 (선택적)
    if (ans.probabilities !== undefined && ans.probabilities !== null) {
      if (typeof ans.probabilities !== 'object' || Array.isArray(ans.probabilities)) {
        return makeFallbackResult(decisionType, 'INVALID_RESPONSE_SCHEMA', res.status, latencyMs, safeExistingRoute);
      }
      let expectedProbKeys = null;
      if (q.type === 'choice') {
        expectedProbKeys = Object.keys(q.criteria).sort();
      } else if (q.type === 'score') {
        expectedProbKeys = q.criteria.map((_, idx) => String(idx)).sort();
      }

      if (expectedProbKeys) {
        const pKeys = Object.keys(ans.probabilities).sort();
        if (pKeys.length !== expectedProbKeys.length || !pKeys.every((k, i) => k === expectedProbKeys[i])) {
          return makeFallbackResult(decisionType, 'INVALID_RESPONSE_SCHEMA', res.status, latencyMs, safeExistingRoute);
        }
        const cleanProbs = {};
        for (const pk of expectedProbKeys) {
          const val = ans.probabilities[pk];
          if (typeof val !== 'number' || !Number.isFinite(val) || val < 0 || val > 1) {
            return makeFallbackResult(decisionType, 'INVALID_RESPONSE_SCHEMA', res.status, latencyMs, safeExistingRoute);
          }
          cleanProbs[pk] = val;
        }
        projectedAnswers[qk].probabilities = cleanProbs;
      }
    }
  }

  // 13.5 usage 검증 및 투영
  let projectedUsage = null;
  if (data.usage !== undefined && data.usage !== null) {
    if (typeof data.usage !== 'object' || Array.isArray(data.usage)) {
      return makeFallbackResult(decisionType, 'INVALID_RESPONSE_SCHEMA', res.status, latencyMs, safeExistingRoute);
    }
    const inTok = data.usage.inputTokens ?? data.usage.input_tokens;
    const outTok = data.usage.outputTokens ?? data.usage.output_tokens;
    if (!Number.isInteger(inTok) || inTok < 0) {
      return makeFallbackResult(decisionType, 'INVALID_RESPONSE_SCHEMA', res.status, latencyMs, safeExistingRoute);
    }
    if (!Number.isInteger(outTok) || outTok < 0) {
      return makeFallbackResult(decisionType, 'INVALID_RESPONSE_SCHEMA', res.status, latencyMs, safeExistingRoute);
    }

    const cleanIn = inTok;
    const cleanOut = outTok;
    let cleanTot;
    const totTok = data.usage.totalTokens ?? data.usage.total_tokens;
    if (totTok !== undefined) {
      if (!Number.isInteger(totTok) || totTok < (cleanIn + cleanOut)) {
        return makeFallbackResult(decisionType, 'INVALID_RESPONSE_SCHEMA', res.status, latencyMs, safeExistingRoute);
      }
      cleanTot = totTok;
    } else {
      cleanTot = cleanIn + cleanOut;
    }

    let cost = null;
    if (typeof data.usage.cost === 'number' && Number.isFinite(data.usage.cost) && data.usage.cost >= 0) {
      cost = data.usage.cost;
    } else if (typeof data.providerMetadata?.gateway?.cost === 'number' && Number.isFinite(data.providerMetadata.gateway.cost) && data.providerMetadata.gateway.cost >= 0) {
      cost = data.providerMetadata.gateway.cost;
    }

    projectedUsage = {
      input_tokens: cleanIn,
      output_tokens: cleanOut,
      total_tokens: cleanTot,
      cost: cost
    };
  }

  // 13.6 agreement 계산 (expected 제거, 1개 질문 + existing_route 엄격 비교)
  let agreement = null;
  if (reqQKeySorted.length === 1 && safeExistingRoute !== null) {
    const singleQk = reqQKeySorted[0];
    const singleQ = request.questions[singleQk];
    const singleAns = projectedAnswers[singleQk];
    if (singleQ.type === 'choice') {
      agreement = singleAns.choice === safeExistingRoute;
    } else if (singleQ.type === 'score') {
      agreement = singleAns.score === safeExistingRoute;
    } else {
      agreement = null;
    }
  }

  return {
    ok: true,
    decision_type: decisionType,
    answers: projectedAnswers,
    usage: projectedUsage,
    agreement: agreement,
    existing_route: safeExistingRoute,
    provider: 'vercel_ai_gateway',
    model: 'typesafe-ai/jev',
    latency_ms: latencyMs,
    fallback_used: false
  };
}

// 직접 CLI 실행 (표준입력에서 1건의 JSON 읽기)
if (process.argv[1] && fileURLToPath(import.meta.url) === path.resolve(process.argv[1])) {
  let inputBuffer = '';
  process.stdin.setEncoding('utf8');
  for await (const chunk of process.stdin) {
    inputBuffer += chunk;
  }

  let parsedReq;
  try {
    parsedReq = JSON.parse(inputBuffer);
  } catch {
    console.log(JSON.stringify(makeFallbackResult('unknown', 'INVALID_REQUEST_OBJECT', null, 0), null, 2));
    process.exit(2);
  }

  const res = await evaluateJevDecision(parsedReq);
  console.log(JSON.stringify(res, null, 2));
  process.exit(res.ok ? 0 : 2);
}

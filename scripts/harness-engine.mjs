/** Pure v6 routing and gates. No IO, dependencies, provider calls, or persisted model IDs.
 * Phase state: {workflow: PHASES, phases:{[id]:contract}, current_phase, goal}.
 * Successful contract: {status:'PASS', goal, acceptance_criteria:[...],
 * verification_method, evidence:[{ref, status:'PASS', environment, simulated:false}]}.
 * Plain evidence artifact references are supported outside production. N/A always
 * requires {status:'N/A', required:false, reason:'specific applicability reason'}.
 * Resume manifest uses the snake_case fields from Bootstrap section 136, plus
 * goal, acceptance_criteria, next_task and preserved decision/rollback references.
 */
export const PHASES = Object.freeze([
  '00_INTAKE', '01_DISCOVERY', '02_REQUIREMENTS', '03_ARCHITECTURE',
  '04_ACCEPTANCE', '05_UX_UI_DESIGN', '06_VISUAL_VERIFICATION',
  '07_VERTICAL_SLICE', '08_FEATURE_IMPLEMENTATION', '09_AUTOMATED_VERIFICATION',
  '10_INDEPENDENT_REVIEW', '11_RELEASE_VERIFICATION', '12_DEPLOY',
  '13_PRODUCTION_VERIFICATION', '14_RETROSPECTIVE', '15_HARNESS_BENCHMARK',
]);
export const PHASE_STATUSES = Object.freeze(['NOT_STARTED', 'READY', 'IN_PROGRESS',
  'WAITING_USER', 'BLOCKED', 'VERIFYING', 'FAILED', 'PASS', 'DEPLOYED', 'VERIFIED_PRODUCTION', 'N/A']);
export const DEVELOPMENT_STATES = Object.freeze(['NOT_STARTED', 'IN_PROGRESS',
  'SAFE_CHECKPOINT', 'FROZEN_FOR_MIGRATION', 'RESUMING', 'STABLE']);
const MODES = ['GREENFIELD', 'MAINTENANCE', 'HOTFIX', 'MIGRATION'];
const SUCCESS = new Set(['PASS', 'DEPLOYED', 'VERIFIED_PRODUCTION']);
const nonempty = value => typeof value === 'string' ? value.trim().length > 0
  : Array.isArray(value) ? value.length > 0 && value.every(nonempty)
    : value !== null && typeof value === 'object' ? Object.keys(value).length > 0 : false;
const fail = message => { throw new Error(message); };
const requireValue = (value, label) => { if (!nonempty(value)) fail(`Missing ${label}`); };
const upper = value => String(value ?? '').toUpperCase();
const meaningfulReason = reason => typeof reason === 'string' && reason.trim().length >= 12
  && !/^(?:n\/?a|not applicable|skip|none|not needed)[.!\s]*$/i.test(reason.trim());
const statusOf = gate => typeof gate === 'string' ? gate : gate?.status;

function validNA(gate, label, explicitlyRequired = false) {
  if (explicitlyRequired || gate?.required !== false || !meaningfulReason(gate?.reason)) {
    fail(`${label}: N/A requires explicit non-applicability, required:false and a specific reason`);
  }
}
function evidence(gate, label, production = false) {
  requireValue(gate?.evidence, `${label} evidence`);
  const records = Array.isArray(gate.evidence) ? gate.evidence : [gate.evidence];
  for (const record of records) {
    if (typeof record === 'string') {
      if (production) fail(`${label}: production needs structured real environment evidence`);
      if (/^(?:PASS|OK|DONE|SUCCESS)$/i.test(record.trim())) fail(`${label}: status text is not evidence`);
      continue;
    }
    if (!record || typeof record !== 'object' || !nonempty(record.ref ?? record.path ?? record.artifact ?? record.command)) {
      fail(`${label}: evidence needs an artifact reference or recorded command`);
    }
    if (Object.hasOwn(record, 'exit_code') && record.exit_code !== 0) fail(`${label}: failed recorded command cannot support a PASS artifact`);
    if (!nonempty(record.ref ?? record.path ?? record.artifact) && record.command
      && record.exit_code !== 0) fail(`${label}: command-only evidence requires recorded exit_code:0`);
    if (record.status && !SUCCESS.has(record.status)) fail(`${label}: failed or incomplete evidence`);
    if (production && (record.simulated !== false || !['production', 'prod'].includes(String(record.environment).toLowerCase())
      || !SUCCESS.has(record.status))) fail(`${label}: production evidence must be PASS, simulated:false, environment:production`);
  }
}
function validateGate(gate, label, {required = false, production = false, phase = false} = {}) {
  if (!gate || typeof gate !== 'object') fail(`${label}: a structured verification contract is required`);
  if (gate.status === 'N/A') { validNA(gate, label, required); return; }
  if (!SUCCESS.has(gate.status)) fail(`${label}: ${gate.status ?? 'missing status'} blocks progress`);
  if (phase) for (const key of ['goal', 'acceptance_criteria', 'verification_method']) requireValue(gate[key], `${label} ${key}`);
  evidence(gate, label, production);
}

const refs = {
  P04: 'policies/04_코드 변경 범위·영향·차이 제어 지침.md',
  P05: 'policies/05_장기 작업 상태 압축·체크포인트·인수인계 지침.md',
  P06: 'policies/06_작업 완료·테스트·회귀·검증 판정 지침.md',
  P15: 'policies/15_의존성 및 외부 계약 관리 지침.md',
  P16: 'policies/16_마이그레이션 및 롤백 관리 지침.md',
  P17: 'policies/17_보안 및 권한 경계 관리 지침.md',
  P18: 'policies/18_설계 결정 기록 및 의사결정 기억 지침.md',
  P19: 'policies/19_AI 하네스 평가 및 지속 개선 지침.md',
  P26: 'policies/26_코드베이스 운영체계 실행 지침.md',
};
const workflowFor = mode => mode === 'GREENFIELD' ? [...PHASES]
  : mode === 'MAINTENANCE' ? PHASES.filter(id => !['05_UX_UI_DESIGN', '06_VISUAL_VERIFICATION', '07_VERTICAL_SLICE'].includes(id))
    : mode === 'HOTFIX' ? PHASES.filter(id => !['03_ARCHITECTURE', '05_UX_UI_DESIGN', '06_VISUAL_VERIFICATION', '07_VERTICAL_SLICE'].includes(id))
      : PHASES.filter(id => !['05_UX_UI_DESIGN', '06_VISUAL_VERIFICATION'].includes(id));

/** Request may be text or {text,intent,project_mode,risk,beginner_mode,update_class,boundaries}.
 * Detection describes observed facts; caller options must not downgrade their risk.
 */
export function routeTask(request, detected = {}, options = {}) {
  const input = typeof request === 'string' ? {text: request} : request ?? {};
  const text = String(input.text ?? input.request ?? '').normalize('NFKC');
  const reasons = [];
  const harness = /(?:harness|하네스)/i.test(text) || /^harness_/.test(input.intent ?? '');
  const update = harness && (/(?:update|upgrade|migrat|latest.?version|최신\s*(?:버전)?|업데이트|업그레이드|전환)/i.test(text) || input.intent === 'harness_update');
  const install = harness && (/(?:install|setup|adopt|설치|적용|도입)/i.test(text) || input.intent === 'harness_install');
  let intent = input.intent ?? (update ? 'harness_update' : install ? 'harness_install' : 'development');
  const installed = nonempty(detected.installed_version);
  if (install && installed) {
    intent = 'harness_update'; reasons.push('Existing harness detected: install request becomes update, preserving existing project work.');
  } else if (install && detected.has_product) {
    intent = 'harness_adoption'; reasons.push('Existing product detected: adopt harness without recreating completed product phases.');
  }
  const security = /(?:auth|permission|payment|security|인증|권한|결제|보안)/i.test(text)
    || (input.boundaries ?? []).some(x => /AUTH|SECURITY|PAYMENT/i.test(x));
  const destructiveData = /(?:(?:data|database|\bdb\b|데이터|레코드).*?(?:delete|drop|truncate|wipe|destroy|삭제|비우|파괴)|(?:delete|drop|truncate|wipe|destroy).*?(?:data|database|\bdb\b))/i.test(text);
  const database = destructiveData || /(?:\bdb\b|database|schema|데이터베이스|스키마)/i.test(text)
    || (input.boundaries ?? []).some(x => /DATABASE|SCHEMA/i.test(x));
  const deployment = /(?:deploy|배포)/i.test(text) || (input.boundaries ?? []).some(x => /DEPLOY/i.test(x));
  const schemaChange = database && (/(?:schema|structure|column|table|스키마|구조|컬럼|열|테이블)/i.test(text)
    && /(?:change|alter|modify|add|remove|delete|drop|바꾸|바꿔|변경|추가|삭제)/i.test(text));
  const frameworkMajor = /(?:(?:framework|runtime|프레임워크|런타임).*?(?:major|메이저|주\s*버전|대규모)|(?:major|메이저).*?(?:framework|runtime|프레임워크|런타임))/i.test(text);
  const migration = destructiveData || schemaChange || frameworkMajor
    || /(?:migrat|major upgrade|runtime upgrade|마이그레이션|대규모.*(?:이전|업그레이드))/i.test(text)
    || database && /(?:변환|이전|migration|transform)/i.test(text);
  const hotfix = /(?:hotfix|outage|incident|긴급|장애|서비스.*중단)/i.test(text);
  let mode = upper(input.project_mode ?? options.project_mode ?? detected.project_mode);
  if (!mode) mode = intent === 'harness_update' || migration ? 'MIGRATION'
    : hotfix ? 'HOTFIX' : detected.has_product ? 'MAINTENANCE' : 'GREENFIELD';
  if (!MODES.includes(mode)) fail(`Unknown project mode: ${mode}`);
  if ((intent === 'harness_update' || migration) && mode !== 'MIGRATION') {
    mode = 'MIGRATION'; reasons.push('Migration boundary overrides ordinary maintenance routing.');
  } else if (hotfix && mode !== 'HOTFIX' && intent !== 'harness_update') {
    mode = 'HOTFIX'; reasons.push('Observed incident/outage overrides prior development mode and requires hotfix verification.');
  }
  const developmentState = upper(detected.development_state || (detected.has_product ? 'IN_PROGRESS' : 'NOT_STARTED'));
  if (!DEVELOPMENT_STATES.includes(developmentState)) fail(`Unknown development state: ${developmentState}`);
  let risk = mode === 'GREENFIELD' || mode === 'MAINTENANCE' ? 2 : 3;
  if (/(?:copy|wording|color|css|오탈자|문구|색상)/i.test(text) && !security && !database && !deployment && ['GREENFIELD','MAINTENANCE'].includes(mode)) risk = 0;
  else if (/(?:\bui\b|button|버튼|화면)/i.test(text) && !security && !database && !deployment && ['GREENFIELD','MAINTENANCE'].includes(mode)) risk = 1;
  if (security || database || deployment) risk = Math.max(risk, 3);
  if (destructiveData || /(?:data migration|destructive|irreversible|security incident|데이터.*(?:변환|이전)|비가역|파괴적|보안.*사고)/i.test(text)) risk = 4;
  if (detected.production === true && /(?:architecture|아키텍처)/i.test(text)) risk = 4;
  for (const requested of [input.risk, options.risk, detected.risk]) {
    if (requested !== undefined && !/^R[0-4]$/.test(requested)) fail(`Unknown risk: ${requested}`);
    if (requested) risk = Math.max(risk, Number(requested.slice(1)));
  }
  let updateClass = null;
  if (['harness_update', 'harness_install', 'harness_adoption'].includes(intent)) {
    const fromMajor = String(detected.installed_version ?? '').match(/\d+/)?.[0];
    const toMajor = String(detected.target_version ?? options.target_version ?? '6.0').match(/\d+/)?.[0];
    updateClass = !installed || fromMajor !== toMajor || /(?:core|phase engine|architecture|directory|코어|구조)/i.test(text) ? 'H3'
      : /(?:routing|router|gate|workflow|verification profile|컨텍스트|라우터|게이트|워크플로)/i.test(text) ? 'H2'
        : /(?:typo|wording|reference|documentation|오탈자|문구|설명|문서)/i.test(text) ? 'H1' : 'H2';
    const asked = input.update_class ?? options.update_class;
    if (asked && !['H1', 'H2', 'H3'].includes(asked)) fail(`Unknown update class: ${asked}`);
    if (asked && asked > updateClass) updateClass = asked;
  }
  let timing = 'NOW';
  const operation = Array.isArray(detected.operation_in_progress) ? detected.operation_in_progress.join(' ')
    : typeof detected.operation_in_progress === 'object'
    ? Object.entries(detected.operation_in_progress ?? {}).filter(([,v]) => v === true || ['IN_PROGRESS','RUNNING','ACTIVE'].includes(upper(v))).map(([k]) => k).join(' ')
    : String(detected.operation_in_progress ?? '');
  const unsafeOperation = detected.operation_in_progress === true
    || /(?:deploy|migration|database|\bdb\b|schema|data.?transform|hotfix|incident|merge.?conflict|배포|변환|장애)/i.test(operation)
    || upper(detected.project_mode) === 'HOTFIX' && developmentState === 'IN_PROGRESS';
  if (updateClass && unsafeOperation) {
    timing = 'DEFERRED'; reasons.push('Active deployment/database/data transformation/incident operation must finish before harness changes.');
  } else if (updateClass && developmentState === 'IN_PROGRESS') {
    timing = 'CHECKPOINT'; reasons.push('Preserve current phase rules; checkpoint active development before updating.');
  }
  if (updateClass && timing === 'NOW' && (detected.known_failures ?? []).length > 0) {
    timing = 'CHECKPOINT'; reasons.push('Known failures require an explicit baseline and safe checkpoint before changing harness rules.');
  }
  // A blocking harness defect permits only a scoped repair. It never permits a full major upgrade mid-phase.
  if (input.blocking_harness_defect === true && input.minimal_repair === true && updateClass && timing !== 'DEFERRED') {
    reasons.push('Minimal blocking-defect repair exception: keep current runtime version and phase rules; major migration remains checkpointed.');
    if (updateClass === 'H1') timing = 'NOW';
  }
  const tier = risk >= 3 || mode === 'MIGRATION' ? 'frontier'
    : risk === 0 || /(?:list files|summari[sz]e logs|format|파일.*목록|로그.*요약)/i.test(text) ? 'economy' : 'balanced';
  const profile = mode === 'GREENFIELD' ? 'PROFILE_GREENFIELD' : mode === 'HOTFIX' ? 'PROFILE_HOTFIX'
    : mode === 'MIGRATION' ? 'PROFILE_MIGRATION' : risk >= 3 ? 'PROFILE_MAINTENANCE_HIGH' : 'PROFILE_MAINTENANCE_LOW';
  const jit = [refs.P06, mode === 'GREENFIELD' ? refs.P18 : refs.P04];
  if (mode === 'MIGRATION' || database) jit.push(refs.P16, 'harness/runtime/transition-audit.md');
  if (security) jit.push(refs.P17);
  if (/(?:sdk|package|external api|dependency|의존성)/i.test(text)) jit.push(refs.P15);
  if (updateClass) jit.push(refs.P05, refs.P19, 'harness/runtime/harness-update-router.md');
  if (intent === 'harness_adoption') jit.push('PROJECT_INIT.md');
  if (mode === 'MAINTENANCE') jit.push(refs.P26);
  const workflow = workflowFor(mode);
  if (/ui|화면|visual|시각/i.test(text) && mode !== 'GREENFIELD') {
    for (const id of ['05_UX_UI_DESIGN', '06_VISUAL_VERIFICATION']) if (!workflow.includes(id)) workflow.push(id);
    workflow.sort((a,b) => PHASES.indexOf(a) - PHASES.indexOf(b));
  }
  reasons.push(`Observed task boundary selects ${mode}, R${risk}, ${profile}; omitted phase ceremonies retain acceptance, verification and review obligations.`);
  return {intent, project_mode: mode, development_state: developmentState, update_class: updateClass,
    risk: `R${risk}`, beginner_mode: input.beginner_mode ?? options.beginner_mode ?? detected.beginner_mode ?? true,
    workflow, verification_profile: profile,
    context_profile: {GREENFIELD:'GREENFIELD_CONTEXT', MAINTENANCE:'MAINTENANCE_DELTA', HOTFIX:'HOTFIX_CRITICAL', MIGRATION:'MIGRATION_COMPATIBILITY'}[mode],
    jit_files: [...new Set(jit)], tier, reasoning: {economy:'low', balanced:'medium', frontier:'high'}[tier], timing, reasons,
    next_action: timing === 'DEFERRED' ? 'Finish active operation; record deferred update and re-evaluate timing.'
      : timing === 'CHECKPOINT' ? 'Record recoverable checkpoint, preserve goal/phase/criteria/next task, then freeze for migration.'
        : developmentState === 'FROZEN_FOR_MIGRATION' && !updateClass ? 'Complete migration validation and resume audit before product changes.'
          : 'Confirm acceptance contract and execute the next required phase with evidence.'};
}

function criticalFindings(state, contract) {
  const findings = [...(state.findings ?? []), ...(contract.findings ?? [])];
  for (const gate of Object.values(state.phases ?? {})) findings.push(...(gate.findings ?? []));
  return findings.some(f => /^(?:critical|blocker)$/i.test(f.severity ?? '')
    && (!['RESOLVED', 'FIXED'].includes(upper(f.status)) || !nonempty(f.resolution_evidence ?? f.evidence)));
}

/** Validates an attempt to enter/update phase. No mutation on rejected transitions. */
export function transitionPhase(state, phaseId, contract) {
  if (!PHASES.includes(phaseId)) fail(`Unknown phase: ${phaseId}`);
  if (!state || typeof state !== 'object' || !contract || typeof contract !== 'object') fail('State and phase contract required');
  if (!PHASE_STATUSES.includes(contract.status)) fail(`Unknown phase status: ${contract.status}`);
  const phases = state.phases ?? {};
  const workflow = state.workflow ?? PHASES;
  if (!Array.isArray(workflow) || workflow.some(id => !PHASES.includes(id)) || new Set(workflow).size !== workflow.length) fail('Invalid phase workflow');
  if (!workflow.includes(phaseId)) fail('Phase is not in the selected workflow');
  const position = PHASES.indexOf(phaseId);
  if (['FROZEN_FOR_MIGRATION'].includes(state.development_state)
    && ['07_VERTICAL_SLICE', '08_FEATURE_IMPLEMENTATION'].includes(phaseId) && state.project_mode !== 'MIGRATION') fail('Feature changes prohibited while frozen for migration');
  const required = new Set(state.required_gates ?? []);
  for (const [id, gate] of Object.entries(phases)) {
    if (PHASES.indexOf(id) < position && ['FAILED', 'BLOCKED'].includes(statusOf(gate))) fail(`Previous gate ${id} blocks progress`);
  }
  for (const id of workflow.filter(id => PHASES.indexOf(id) < position)) {
    validateGate(phases[id], `Previous gate ${id}`, {required: required.has(id), phase:true,
      production: id === '13_PRODUCTION_VERIFICATION' && state.production === true});
  }
  for (const id of required) if (!PHASES.includes(id)) fail(`Unknown required gate: ${id}`);
  for (const id of required) if (PHASES.indexOf(id) < position && !workflow.includes(id)) {
    validateGate(phases[id], `Required compressed gate ${id}`, {required:true, phase:true});
  }
  // Compressed workflows still require accepted requirements before implementation.
  if (position >= 7) {
    validateGate(phases['04_ACCEPTANCE'] ?? state.acceptance, 'Acceptance before implementation', {required:true, phase:true});
  }
  if (position >= 11) {
    validateGate(phases['09_AUTOMATED_VERIFICATION'] ?? state.verification, 'Automated verification before release', {required:true, phase:true});
    const review = phases['10_INDEPENDENT_REVIEW'] ?? state.review;
    validateGate(review, 'Independent review before release', {required:true, phase:true});
    validateReview(review);
    if (criticalFindings(state, contract)) fail('Unresolved critical review finding blocks release');
  }
  if (state.production === true && position >= 12) {
    validateGate(phases['11_RELEASE_VERIFICATION'] ?? state.release, 'Release verification before production deployment', {required:true,phase:true});
  }
  if (state.production === true && position >= 13) {
    validateGate(phases['12_DEPLOY'] ?? state.deployment, 'Deployment before production verification', {required:true,phase:true,production:true});
  }
  if (SUCCESS.has(contract.status)) {
    validateGate(contract, phaseId, {required: required.has(phaseId) || ['04_ACCEPTANCE','09_AUTOMATED_VERIFICATION','10_INDEPENDENT_REVIEW'].includes(phaseId), phase:true,
      production: phaseId === '13_PRODUCTION_VERIFICATION'});
    if (phaseId === '10_INDEPENDENT_REVIEW') validateReview(contract);
    if (contract.status === 'DEPLOYED' && phaseId !== '12_DEPLOY') fail('DEPLOYED is valid only for deploy phase');
    if (contract.status === 'VERIFIED_PRODUCTION' && phaseId !== '13_PRODUCTION_VERIFICATION') fail('VERIFIED_PRODUCTION is valid only for production verification');
  } else if (contract.status === 'N/A') validNA(contract, phaseId, required.has(phaseId)
    || ['04_ACCEPTANCE','09_AUTOMATED_VERIFICATION','10_INDEPENDENT_REVIEW'].includes(phaseId)
    || state.production === true && ['12_DEPLOY','13_PRODUCTION_VERIFICATION'].includes(phaseId));
  if (state.production === true && position > 13) {
    validateGate(phases['13_PRODUCTION_VERIFICATION'], 'Production verification before completion', {required:true, phase:true, production:true});
  }
  const result = structuredClone(state);
  result.phases = {...result.phases, [phaseId]: structuredClone(contract)};
  result.current_phase = phaseId;
  for (const id of Object.keys(result.phases)) {
    if (PHASES.indexOf(id) > position) result.phases[id] = { ...result.phases[id], status: 'NOT_STARTED', invalidated_by: phaseId };
  }
  for (const [alias, id] of Object.entries({ acceptance: '04_ACCEPTANCE', verification: '09_AUTOMATED_VERIFICATION', review: '10_INDEPENDENT_REVIEW', release: '11_RELEASE_VERIFICATION', deployment: '12_DEPLOY' })) {
    if (result[alias] && PHASES.indexOf(id) > position) result[alias] = { ...result[alias], status: 'NOT_STARTED', invalidated_by: phaseId };
  }
  const next = workflow.find(id => PHASES.indexOf(id) > position);
  result.next_action = SUCCESS.has(contract.status) || contract.status === 'N/A'
    ? next ?? 'COMPLETE' : contract.status === 'FAILED' || contract.status === 'BLOCKED' ? 'RESOLVE_BLOCKER' : phaseId;
  return result;
}
function validateReview(review) {
  const builder = review.builder_role ?? review.builder;
  const reviewer = review.reviewer_role ?? review.reviewer;
  requireValue(builder, 'review builder_role'); requireValue(reviewer, 'review reviewer_role');
  if (String(typeof builder === 'object' ? builder.role ?? builder.id : builder).trim().toLowerCase()
    === String(typeof reviewer === 'object' ? reviewer.role ?? reviewer.id : reviewer).trim().toLowerCase()) fail('Builder and reviewer must have distinct logical roles');
  requireValue(review.review_evidence ?? review.evidence, 'review evidence');
}

/** Complete transition preservation and all six resume checks are mandatory. */
export function validateResume(transition, verification) {
  if (!transition || !verification) fail('Transition manifest and resume verification required');
  for (const field of ['from_version','to_version','project_mode','development_state','checkpoint','current_phase',
    'completed_phases','current_work','carry_forward','new_required_gates','deferred_rules','conflicts','resume_from']) {
    if (!Object.hasOwn(transition, field)) fail(`Transition missing ${field}`);
  }
  for (const field of ['from_version','to_version','project_mode','development_state','checkpoint','current_phase','current_work','carry_forward','resume_from']) requireValue(transition[field], `transition ${field}`);
  for (const field of ['completed_phases','new_required_gates','deferred_rules','conflicts']) if (!Array.isArray(transition[field])) fail(`Transition ${field} must be an array`);
  if (!MODES.includes(transition.project_mode) || !DEVELOPMENT_STATES.includes(transition.development_state)) fail('Invalid preserved project mode or development state');
  if (transition.conflicts.some(c => typeof c === 'string' || !['RESOLVED','PRESERVED','ACCEPTED'].includes(upper(c.status)))) fail('Unresolved transition conflicts block resume');
  const checkpoint = transition.checkpoint;
  if (typeof checkpoint !== 'object') fail('Checkpoint must contain preservation and rollback records');
  for (const field of ['goal','acceptance_criteria','phase','next_task','rollback_point']) requireValue(checkpoint[field], `checkpoint ${field}`);
  const resume = transition.resume_from;
  if (typeof resume !== 'object') fail('resume_from must contain restored goal, phase, next_task');
  for (const field of ['goal','phase','next_task']) {
    requireValue(resume[field], `resume_from ${field}`);
    if (JSON.stringify(resume[field]) !== JSON.stringify(checkpoint[field])) fail(`Resume does not preserve ${field}`);
  }
  if (transition.current_phase !== checkpoint.phase) fail('Current phase differs from checkpoint');
  if (Object.hasOwn(resume, 'acceptance_criteria') && JSON.stringify(resume.acceptance_criteria) !== JSON.stringify(checkpoint.acceptance_criteria)) fail('Resume does not preserve acceptance criteria');
  const preserved = transition.preservation ?? transition.carry_forward;
  if (!nonempty(preserved)) fail('Preservation record missing');
  const decisions = Array.isArray(preserved)
    ? preserved.some(ref => /decision|architecture|ADR/i.test(typeof ref === 'string' ? ref : ref?.ref ?? ''))
    : Object.hasOwn(preserved, 'decisions') || Object.hasOwn(checkpoint, 'decisions');
  if (!decisions) fail('Transition must preserve existing decisions or explicitly record an empty decision list');
  for (const key of ['harness_validation','transition_audit','build_baseline','test_baseline','critical_regression','benchmark']) {
    validateGate(verification[key], `Resume ${key}`, {required: !['build_baseline','test_baseline'].includes(key)});
  }
  if (!nonempty(transition.new_required_gates)) fail('New gate adoption timing must be explicit');
  return {valid:true, development_state:'RESUMING', goal:structuredClone(resume.goal),
    current_phase:resume.phase, next_task:structuredClone(resume.next_task),
    acceptance_criteria:structuredClone(checkpoint.acceptance_criteria)};
}

export function evaluateTokenBudget({used, soft_limit, hard_limit} = {}) {
  if (used === null || used === undefined) return {action:'MEASURE', usage_known:false, skip_verification:false, reason:'Actual token usage unavailable; record unknown rather than an invented count.'};
  if (![used,soft_limit,hard_limit].every(Number.isFinite) || used < 0 || soft_limit <= 0 || hard_limit <= soft_limit) fail('Budget needs finite used>=0 and 0<soft_limit<hard_limit');
  return {action:used >= hard_limit ? 'CHECKPOINT' : used >= soft_limit ? 'COMPACT' : 'CONTINUE',
    usage_known:true, remaining:Math.max(0,hard_limit-used), skip_verification:false,
    preserve:['goal','acceptance_criteria','current_phase','decisions','evidence','blockers','next_task'],
    reason:used >= hard_limit ? 'Save recoverable checkpoint and handoff; pending verification stays required.'
      : used >= soft_limit ? 'Release completed phase context and compact state; retain verification obligations.' : 'Continue with JIT context.'};
}

/** Catalog: [{id,description,capabilities?,tier?,available?}]. Resolve only current advertised capability. */
export function resolveModelTier(tier, catalog) {
  if (!['economy','balanced','frontier'].includes(tier)) fail(`Unknown model tier: ${tier}`);
  if (!Array.isArray(catalog)) fail('Current runtime model catalog required');
  const available = catalog.filter(m => m && m.available !== false && nonempty(m.id ?? m.name));
  const pattern = {economy:/fastest|fast|affordable|economy|low.cost|저렴|빠른/i,
    balanced:/balanc|workhorse|general.purpose|균형/i,
    frontier:/strongest|frontier|most capable|complex professional|most demanding|최강|최고/i}[tier];
  const matches = available.filter(m => m.tier === tier || pattern.test([m.description,
    ...(Array.isArray(m.capabilities) ? m.capabilities : [m.capabilities ?? ''])].join(' ')));
  if (!matches.length) return {tier, model:null, reasoning:{economy:'low',balanced:'medium',frontier:'high'}[tier],
    fallback:true, reason:'No advertised matching model available; retain current capable runtime model without inventing a catalog mapping.'};
  const selected = matches.find(m => m.tier === tier) ?? matches[0];
  return {tier, model:selected.id ?? selected.name, reasoning:{economy:'low',balanced:'medium',frontier:'high'}[tier], fallback:false,
    reason:'Resolved from current runtime advertised capabilities; concrete model identity is not persisted in routing policy.'};
}

export function transitionDevelopmentState(current, next, context = {}) {
  if (!DEVELOPMENT_STATES.includes(current) || !DEVELOPMENT_STATES.includes(next)) fail('Unknown development state');
  const allowed = {NOT_STARTED:['IN_PROGRESS','SAFE_CHECKPOINT'], IN_PROGRESS:['SAFE_CHECKPOINT'],
    SAFE_CHECKPOINT:['IN_PROGRESS','FROZEN_FOR_MIGRATION','STABLE'],
    FROZEN_FOR_MIGRATION:['RESUMING','SAFE_CHECKPOINT'], RESUMING:['IN_PROGRESS','SAFE_CHECKPOINT'],
    STABLE:['IN_PROGRESS','SAFE_CHECKPOINT']};
  if (current === next) return {development_state:next};
  if (!allowed[current].includes(next)) fail(`Invalid development transition: ${current} -> ${next}`);
  if (context.operation_in_progress && ['SAFE_CHECKPOINT','FROZEN_FOR_MIGRATION','RESUMING'].includes(next)) fail('Active operation must finish before development transition');
  if (next === 'SAFE_CHECKPOINT' || next === 'FROZEN_FOR_MIGRATION') {
    const checkpoint = context.checkpoint;
    if (!checkpoint || typeof checkpoint !== 'object') fail('Recoverable checkpoint required');
    for (const field of ['goal','phase','acceptance_criteria','next_task','rollback_point','changed_files','git_status','branch','commit','completed_work','unfinished_work','test_results','known_failures','migration_state','environment_changes']) {
      if (!Object.hasOwn(checkpoint,field)) fail(`Checkpoint missing ${field}`);
      if (!['changed_files','completed_work','unfinished_work','known_failures','environment_changes'].includes(field)) requireValue(checkpoint[field], `checkpoint ${field}`);
    }
  }
  if (context.update_class === 'H3' && next === 'IN_PROGRESS' && current !== 'RESUMING') fail('Major migration requires freeze, audit and resume validation');
  if (next === 'RESUMING') return validateResume(context.transition, context.verification);
  if (current === 'RESUMING' && next === 'IN_PROGRESS') validateGate(context.first_task, 'First resumed task', {required:true});
  if (next === 'STABLE') {
    validateGate(context.verification, 'Stable-state verification', {required:true});
    if (context.critical_findings?.length) fail('Critical findings block stable state');
    if (context.production) validateGate(context.production_verification, 'Production stable-state evidence', {required:true,production:true});
  }
  return {development_state:next};
}

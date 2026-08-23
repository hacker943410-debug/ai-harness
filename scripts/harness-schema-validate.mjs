#!/usr/bin/env node
// AI Harness — 최소 JSON Schema 검증기
//
// 왜 직접 만드는가:
//   PS 5.1 에는 JSON Schema 검증기가 없고, 하네스는 설치 없이 클론만으로 동작해야 한다.
//   외부 의존(ajv)을 넣으면 "검사기를 돌리려면 먼저 npm install 을 하라"가 되고,
//   그 순간 아무도 안 돌린다. 그래서 의존 0 으로, 스키마가 실제로 쓰는 어휘만 구현한다.
//
// 지원하는 어휘 (이것 말고는 조용히 무시하지 않고 UNSUPPORTED 로 보고한다):
//   $ref(로컬 #/$defs 만) type enum const
//   required properties patternProperties additionalProperties propertyNames
//   items minItems maxItems uniqueItems
//   pattern minLength maxLength minimum maximum
//   allOf anyOf oneOf not
//
// 사용:
//   node harness-schema-validate.mjs --schema <schema.json> <instance.json> [...]
//   node harness-schema-validate.mjs --schema <schema.json> --json <instance.json>
//
// 종료 코드: 0 = 전부 통과, 1 = 위반 있음, 2 = 사용법/입출력 오류

import { readFileSync } from 'node:fs';

const KNOWN = new Set([
  '$schema', '$id', '$defs', '$comment', 'title', 'description', 'default', 'examples', 'deprecated',
  '$ref', 'type', 'enum', 'const',
  'required', 'properties', 'patternProperties', 'additionalProperties', 'propertyNames',
  'items', 'minItems', 'maxItems', 'uniqueItems',
  'pattern', 'minLength', 'maxLength', 'minimum', 'maximum', 'format',
  'allOf', 'anyOf', 'oneOf', 'not',
]);

function typeOf(v) {
  if (v === null) return 'null';
  if (Array.isArray(v)) return 'array';
  if (Number.isInteger(v)) return 'integer';
  return typeof v; // string number boolean object
}

function typeMatches(actual, want) {
  if (want === 'number') return actual === 'number' || actual === 'integer';
  if (want === 'integer') return actual === 'integer';
  return actual === want;
}

function resolveRef(ref, root) {
  if (!ref.startsWith('#/')) throw new Error(`외부 $ref 는 지원하지 않습니다: ${ref}`);
  let node = root;
  for (const rawSeg of ref.slice(2).split('/')) {
    const seg = rawSeg.replace(/~1/g, '/').replace(/~0/g, '~');
    node = node?.[seg];
    if (node === undefined) throw new Error(`$ref 를 해석할 수 없습니다: ${ref}`);
  }
  return node;
}

// 검증 결과는 "실패 목록"이다. 통과를 주장하지 않고 위반만 모은다.
function validate(schema, data, root, path, errors) {
  if (schema === true || schema === undefined) return;
  if (schema === false) { errors.push({ path, msg: '이 위치에는 어떤 값도 허용되지 않습니다' }); return; }

  for (const k of Object.keys(schema)) {
    if (!KNOWN.has(k)) errors.push({ path, msg: `UNSUPPORTED 스키마 키워드: ${k} (검증되지 않음)` });
  }

  if (schema.$ref !== undefined) {
    validate(resolveRef(schema.$ref, root), data, root, path, errors);
    return;
  }

  const t = typeOf(data);

  if (schema.type !== undefined) {
    const want = Array.isArray(schema.type) ? schema.type : [schema.type];
    if (!want.some((w) => typeMatches(t, w))) {
      errors.push({ path, msg: `타입이 ${want.join('|')} 이어야 하는데 ${t} 입니다` });
      return; // 타입이 틀리면 나머지 검사는 의미가 없다
    }
  }

  if (schema.enum !== undefined) {
    const hit = schema.enum.some((e) => JSON.stringify(e) === JSON.stringify(data));
    if (!hit) errors.push({ path, msg: `허용된 값이 아닙니다: ${JSON.stringify(data)} (허용: ${schema.enum.map((e) => JSON.stringify(e)).join(', ')})` });
  }
  if (schema.const !== undefined && JSON.stringify(schema.const) !== JSON.stringify(data)) {
    errors.push({ path, msg: `${JSON.stringify(schema.const)} 이어야 하는데 ${JSON.stringify(data)} 입니다` });
  }

  if (t === 'string') {
    if (schema.pattern !== undefined && !new RegExp(schema.pattern, 'u').test(data)) {
      errors.push({ path, msg: `패턴에 맞지 않습니다: ${schema.pattern}` });
    }
    if (schema.minLength !== undefined && data.length < schema.minLength) {
      errors.push({ path, msg: `길이가 ${schema.minLength} 이상이어야 합니다` });
    }
    if (schema.maxLength !== undefined && data.length > schema.maxLength) {
      errors.push({ path, msg: `길이가 ${schema.maxLength} 이하여야 합니다` });
    }
  }

  if (t === 'number' || t === 'integer') {
    if (schema.minimum !== undefined && data < schema.minimum) errors.push({ path, msg: `${schema.minimum} 이상이어야 합니다` });
    if (schema.maximum !== undefined && data > schema.maximum) errors.push({ path, msg: `${schema.maximum} 이하여야 합니다` });
  }

  if (t === 'array') {
    if (schema.minItems !== undefined && data.length < schema.minItems) errors.push({ path, msg: `항목이 ${schema.minItems}개 이상이어야 합니다 (현재 ${data.length})` });
    if (schema.maxItems !== undefined && data.length > schema.maxItems) errors.push({ path, msg: `항목이 ${schema.maxItems}개 이하여야 합니다 (현재 ${data.length})` });
    if (schema.uniqueItems === true) {
      const seen = new Set();
      for (const item of data) {
        const key = JSON.stringify(item);
        if (seen.has(key)) { errors.push({ path, msg: `중복 항목: ${key}` }); break; }
        seen.add(key);
      }
    }
    if (schema.items !== undefined) {
      data.forEach((item, i) => validate(schema.items, item, root, `${path}/${i}`, errors));
    }
  }

  if (t === 'object') {
    const keys = Object.keys(data);
    for (const req of schema.required ?? []) {
      if (!Object.prototype.hasOwnProperty.call(data, req)) errors.push({ path, msg: `필수 필드가 없습니다: ${req}` });
    }
    if (schema.propertyNames !== undefined) {
      for (const k of keys) validate(schema.propertyNames, k, root, `${path}/${k}<name>`, errors);
    }
    for (const k of keys) {
      let matched = false;
      if (schema.properties && Object.prototype.hasOwnProperty.call(schema.properties, k)) {
        matched = true;
        validate(schema.properties[k], data[k], root, `${path}/${k}`, errors);
      }
      for (const [pat, sub] of Object.entries(schema.patternProperties ?? {})) {
        if (new RegExp(pat, 'u').test(k)) { matched = true; validate(sub, data[k], root, `${path}/${k}`, errors); }
      }
      if (!matched && schema.additionalProperties !== undefined) {
        if (schema.additionalProperties === false) {
          errors.push({ path, msg: `선언되지 않은 필드: ${k}` });
        } else {
          validate(schema.additionalProperties, data[k], root, `${path}/${k}`, errors);
        }
      }
    }
  }

  for (const sub of schema.allOf ?? []) validate(sub, data, root, path, errors);

  if (schema.anyOf !== undefined) {
    const ok = schema.anyOf.some((sub) => { const e = []; validate(sub, data, root, path, e); return e.length === 0; });
    if (!ok) errors.push({ path, msg: 'anyOf 의 어느 갈래도 만족하지 않습니다' });
  }
  if (schema.oneOf !== undefined) {
    const hits = schema.oneOf.filter((sub) => { const e = []; validate(sub, data, root, path, e); return e.length === 0; }).length;
    if (hits !== 1) errors.push({ path, msg: `oneOf 를 만족하는 갈래가 정확히 1개여야 하는데 ${hits}개입니다` });
  }
  if (schema.not !== undefined) {
    const e = [];
    validate(schema.not, data, root, path, e);
    if (e.length === 0) errors.push({ path, msg: 'not 스키마를 만족해서는 안 됩니다' });
  }
}

// --- CLI ---------------------------------------------------------------------

const argv = process.argv.slice(2);
let schemaPath = null;
let asJson = false;
const targets = [];
for (let i = 0; i < argv.length; i++) {
  if (argv[i] === '--schema') { schemaPath = argv[++i]; }
  else if (argv[i] === '--json') { asJson = true; }
  else { targets.push(argv[i]); }
}

if (!schemaPath || targets.length === 0) {
  console.error('사용: node harness-schema-validate.mjs --schema <schema.json> <instance.json> [...]');
  process.exit(2);
}

// BOM 은 JSON.parse 가 거부한다. PS 5.1 이 붙여 놓은 것을 여기서 조용히 걷어낸다.
function readJson(p) {
  return JSON.parse(readFileSync(p, 'utf8').replace(/^﻿/, ''));
}

let schema;
try {
  schema = readJson(schemaPath);
} catch (err) {
  console.error(`스키마를 읽을 수 없습니다: ${schemaPath}\n  ${err.message}`);
  process.exit(2);
}

const results = [];
for (const target of targets) {
  let data;
  try {
    data = readJson(target);
  } catch (err) {
    results.push({ file: target, ok: false, errors: [{ path: '', msg: `JSON 파싱 실패: ${err.message}` }] });
    continue;
  }
  const errors = [];
  try {
    validate(schema, data, schema, '', errors);
  } catch (err) {
    errors.push({ path: '', msg: `검증기 오류: ${err.message}` });
  }
  results.push({ file: target, ok: errors.length === 0, errors });
}

const failed = results.filter((r) => !r.ok);

if (asJson) {
  console.log(JSON.stringify({ schema: schemaPath, results }, null, 2));
} else {
  for (const r of results) {
    if (r.ok) { console.log(`ok    ${r.file}`); continue; }
    console.log(`FAIL  ${r.file}`);
    for (const e of r.errors) console.log(`        ${e.path || '/'}  ${e.msg}`);
  }
}

process.exit(failed.length ? 1 : 0);

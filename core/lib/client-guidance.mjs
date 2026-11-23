import fs from 'node:fs';
import path from 'node:path';
import {atomic,noLinks} from './io.mjs';

const start = '<!-- J-HARNESS-CLAUDE:START -->';
const end = '<!-- J-HARNESS-CLAUDE:END -->';
const importLine = '@AGENTS.md';
const agentsStart = '<!-- J-HARNESS-PORTABLE:START -->';
const agentsEnd = '<!-- J-HARNESS-PORTABLE:END -->';
const maxBytes = 1024 * 1024;

function guidanceFile(project,name) {
 const file = path.join(project,name);
 try {
  const stat = fs.lstatSync(file);
  noLinks(file);
  if (!stat.isFile() || stat.size > maxBytes) return {state:'REVIEW_REQUIRED'};
  const bytes = fs.readFileSync(file);
  if (bytes.length > maxBytes) return {state:'REVIEW_REQUIRED'};
  const text = new TextDecoder('utf-8',{fatal:true,ignoreBOM:true}).decode(bytes);
  return {state:'PRESENT',bytes,text};
 } catch (error) {
  return {state:error.code === 'ENOENT' ? 'MISSING' : 'REVIEW_REQUIRED'};
 }
}

function hasMarkdownImport(text) {
 const visible = text.replace(/<!--[^]*?(?:-->|$)/g,'');
 let fence = null;
 for (const line of visible.split(/\r?\n/)) {
  const marker = /^ {0,3}(`{3,}|~{3,})(.*)$/.exec(line);
  if (fence) {
   if (marker && marker[1][0] === fence[0] && marker[1].length >= fence.length && !marker[2].trim()) fence = null;
  } else if (marker) {
   fence = marker[1];
  } else if (/^ {0,3}@(?:\.\/)?AGENTS\.md[ \t]*$/.test(line)) {
   return true;
  }
 }
 return false;
}

function claudeState(file) {
 if (file.state !== 'PRESENT') return file.state === 'MISSING' ? 'CONNECT_AVAILABLE' : 'REVIEW_REQUIRED';
 const {text} = file;
 const begin = text.indexOf(start), finish = text.indexOf(end);
 if (begin !== -1 || finish !== -1) {
  const managed = text.slice(begin,finish+end.length).replaceAll('\r\n','\n');
  if (begin === -1 || finish < begin || text.lastIndexOf(start) !== begin || text.lastIndexOf(end) !== finish ||
      managed !== [start,importLine,end].join('\n')) return 'REVIEW_REQUIRED';
 }
 if (hasMarkdownImport(text.replace(/^\uFEFF/,''))) return 'IMPORT_PRESENT';
 return begin === -1 ? 'CONNECT_AVAILABLE' : 'REVIEW_REQUIRED';
}

export function projectGuidance(project,{projectBinding,expectedProjectBridge}) {
 if (projectBinding !== 'BOUND_VERIFIED') return {state:'SETUP_REQUIRED',modelApplication:'NOT_OBSERVED'};
 const {state,text=''} = guidanceFile(project,'AGENTS.md');
 const first = text.indexOf(agentsStart), last = text.indexOf(agentsEnd);
 const bridge = first === -1 ? '' : text.slice(first,last+agentsEnd.length).replaceAll('\r\n','\n');
 const managed = first !== -1 && last > first && text.lastIndexOf(agentsStart) === first &&
  text.lastIndexOf(agentsEnd) === last && bridge === expectedProjectBridge;
 const agents = state === 'PRESENT' ? (managed ? 'MANAGED_BLOCK_PRESENT' : 'REVIEW_REQUIRED') : state;
 const override = guidanceFile(project,'AGENTS.override.md');
 const agy = guidanceFile(project,'GEMINI.md');
 return {
  agents,modelApplication:'NOT_OBSERVED',
  codex:{override:override.text?.trim() ? 'OVERRIDE_PRESENT' : override.state === 'REVIEW_REQUIRED' ? 'REVIEW_REQUIRED' : 'NONE',
   exceedsDefaultGuidanceBudget:Buffer.byteLength(text)>32768},
  claude:{state:claudeState(guidanceFile(project,'CLAUDE.md')),localInstructions:guidanceFile(project,'CLAUDE.local.md').state},
  agy:{additionalGeminiGuidance:agy.state},
 };
}

export function connectClaude(project,context) {
 if (projectGuidance(project,context).agents !== 'MANAGED_BLOCK_PRESENT') throw Error('PROJECT_AGENTS_GUIDANCE_REQUIRES_REVIEW');
 const name = 'CLAUDE.md';
 const file = path.join(project,name);
 const current = guidanceFile(project,name);
 const state = claudeState(current);
 if (state === 'REVIEW_REQUIRED') throw Error('CLAUDE_GUIDANCE_REQUIRES_REVIEW');
 if (state === 'IMPORT_PRESENT') return {result:'CLAUDE_IMPORT_PRESENT',file:name,changed:false,modelApplication:'NOT_OBSERVED'};
 const eol = current.text?.includes('\r\n') ? '\r\n' : '\n';
 const suffix = (current.bytes?.length ? eol+eol : '')+[start,importLine,end,''].join(eol);
 const bytes = Buffer.concat([current.bytes??Buffer.alloc(0),Buffer.from(suffix)]);
 if (bytes.length > maxBytes || !hasMarkdownImport((current.text??'')+suffix)) throw Error('CLAUDE_GUIDANCE_REQUIRES_REVIEW');
 noLinks(file);
 if (current.state === 'MISSING') {
  fs.writeFileSync(file,bytes,{flag:'wx'});
 } else {
  if (!fs.readFileSync(file).equals(current.bytes)) throw Error('CLAUDE_GUIDANCE_CHANGED_RETRY');
  atomic(file,bytes);
 }
 return {result:'CLAUDE_IMPORT_PRESENT',file:name,changed:true,modelApplication:'NOT_OBSERVED'};
}

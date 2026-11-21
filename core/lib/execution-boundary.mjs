import path from 'node:path';
import {readJson} from './io.mjs';
import {examineBoundary} from './supervisor-engine.mjs';

export function executionBoundary(project, requireSupervisor = false) {
  const binding = readJson(path.join(project, '.ai/harness-project.json'));
  const configured = binding?.supervisor?.required;
  if (configured !== undefined && typeof configured !== 'boolean') {
    throw Error('SUPERVISOR_REQUIRED_MUST_BE_BOOLEAN');
  }

  const required = requireSupervisor || configured === true;
  const decision = examineBoundary({desired: required ? 'ON' : 'OFF', entry: 'jh-managed'});
  return {
    mode: required ? 'SUPERVISOR_REQUIRED' : 'LOCAL_COOPERATIVE',
    ...decision,
    verificationEnvironment: 'ALLOWLISTED_HOST_ENVIRONMENT',
    evidenceStorage: 'PROJECT_LOCAL_MUTABLE',
  };
}

export function requireLocalExecution(project, requireSupervisor = false) {
  const boundary = executionBoundary(project, requireSupervisor);
  if (boundary.mode === 'SUPERVISOR_REQUIRED' && !boundary.launchAuthorized) {
    throw Error('SUPERVISOR_REQUIRED_EXECUTION_BLOCKED: ' + boundary.reason);
  }
  return boundary;
}

const verificationVariables = [
  'PATH', 'PATHEXT', 'SystemRoot', 'SystemDrive', 'WINDIR', 'ComSpec',
  'TEMP', 'TMP', 'TMPDIR', 'OS', 'PROCESSOR_ARCHITECTURE', 'NUMBER_OF_PROCESSORS',
  'LANG', 'LC_ALL', 'LC_CTYPE', 'TERM', 'TZ',
];

export function verificationEnvironment() {
  return Object.fromEntries(verificationVariables.flatMap(name => {
    const value = process.env[name];
    return value === undefined ? [] : [[name, value]];
  }));
}

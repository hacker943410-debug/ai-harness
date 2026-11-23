export const bridgeStart = '<!-- J-HARNESS-PORTABLE:START -->';
export const bridgeEnd = '<!-- J-HARNESS-PORTABLE:END -->';
const legacyBridges = new Set(['8.0.0-core-beta.1','8.1.0','8.2.0','8.2.1','8.2.2']);

export function projectBridge(relative, version, bundledNode) {
  const runner = bundledNode
    ? "& './" + relative + "/vendor/win-x64/node.exe' './" + relative + "/portable.mjs'"
    : "node '" + relative + "/portable.mjs'";
  const hasBadge = !legacyBridges.has(version);
  const badge = '[J Harness v' + version + ']';
  return [
    bridgeStart,
    '## J Harness Core ' + version,
    'Read ' + relative + '/PORTABLE.md before development. Run `' + runner + ' --project . ' + (hasBadge?'badge':'status') + '`, ' +
      'then read the jh-guided-development Skill and follow analysis → plan → implement → verify → handoff. ' +
      'Use the project runtime even when a global Codex home is unavailable. Never fall back to v7. ' +
      'Preserve current user instructions and require actual verification and independent review before release.',
    ...(hasBadge ? [
      '',
      'On ordinary conversational turns, display the J Harness label on its own line at the start of a substantive update or reply. Show it once per user turn.',
      'In a new session, run the badge command above before choosing the label. If you must send a progress message before running tools, send that brief progress message without a label, then display the label after the check.',
      'After a successful check, use its exact plain-text output ' + badge + ' as the label and reuse it in the same session while the project and version stay the same.',
      'When tools are unavailable or disallowed for the check, display [J Harness v' + version + ' · 지침 로드]. If the check fails, report the error and stop using any previously confirmed label.',
      'Keep exact-output requests such as JSON or code-only intact. Put the label in separate progress output when available. Use no label when the interface cannot show separate progress and the user requested exact output.',
    ] : []),
    bridgeEnd,
  ].join('\n');
}

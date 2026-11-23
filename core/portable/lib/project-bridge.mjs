export const bridgeStart = '<!-- J-HARNESS-PORTABLE:START -->';
export const bridgeEnd = '<!-- J-HARNESS-PORTABLE:END -->';

export function projectBridge(relative, version, bundledNode) {
  const runner = bundledNode
    ? "& './" + relative + "/vendor/win-x64/node.exe' './" + relative + "/portable.mjs'"
    : "node '" + relative + "/portable.mjs'";
  return [
    bridgeStart,
    '## J Harness Core ' + version,
    'Read ' + relative + '/PORTABLE.md before development. Run `' + runner + ' --project . status`, ' +
      'then read the jh-guided-development Skill and follow analysis → plan → implement → verify → handoff. ' +
      'Use the project runtime even when a global Codex home is unavailable. Never fall back to v7. ' +
      'Preserve current user instructions and require actual verification and independent review before release.',
    bridgeEnd,
  ].join('\n');
}

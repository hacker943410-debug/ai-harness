const privateKey = /-----BEGIN [^-]*PRIVATE KEY-----[\s\S]*?(?:-----END [^-]*PRIVATE KEY-----|$)/g;
const providerToken = /\b(?:sk-[A-Za-z0-9_-]{20,}|gh[pousr]_[A-Za-z0-9_]{20,}|github_pat_[A-Za-z0-9_]{20,}|AIza[A-Za-z0-9_-]{35})(?![A-Za-z0-9_-])/g;
const authHeader = /(\bauthorization["']?[ \t]*[:=][ \t]*["']?(?:Bearer|Basic)[ \t]+)[^\s"',}]+/gi;
const labeledValue = /(\b(?:(?:[a-z0-9]+_)*(?:api_key|auth_token|access_token|refresh_token|client_secret|password)|(?:agy|github|gh|openai|anthropic)_token|api-key)["']?[ \t]*[:=][ \t]*)("(?:\\.|[^"\\\r\n])*"|'(?:\\.|[^'\\\r\n])*'|[^\s"'\x60,;}]+)/gi;

export function redactSecrets(text) {
 return text
  .replace(privateKey,'[REDACTED PRIVATE KEY]')
  .replace(authHeader,'$1[REDACTED]')
  .replace(labeledValue,(_match,label,value)=>{
   const quote = value[0] === '"' || value[0] === "'" ? value[0] : '';
   return label+quote+'[REDACTED]'+quote;
  })
  .replace(providerToken,'[REDACTED TOKEN]');
}

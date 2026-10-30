// Small, non-executing YAML scalar reader for SKILL name/description.
// Supports plain/quoted and folded/literal block scalars, not aliases/tags/collections.
function unsupported(){throw Error('UNSUPPORTED_SKILL_METADATA_SCALAR');}
function folded(lines){
 let result='',i=0;
 while(i<lines.length&&lines[i]===''){result+='\n';i++;}
 while(i<lines.length){
  const line=lines[i];result+=line;let next=i+1;
  while(next<lines.length&&lines[next]==='')next++;
  if(next===lines.length){result+='\n'.repeat(next-i);break;}
  const literalBoundary=/^[ \t]/.test(line)||/^[ \t]/.test(lines[next]);
  result+=literalBoundary?'\n'.repeat(next-i):next===i+1?' ':'\n'.repeat(next-i-1);
  i=next;
 }
 return result;
}
function scalar(raw,continuation){
 const block=raw.match(/^([>|])([1-9+-]{0,2})(?:[ \t]+#.*)?$/);
 if(block){
  const indicators=block[2],digits=indicators.match(/[1-9]/g)??[],signs=indicators.match(/[+-]/g)??[];
  if(digits.length>1||signs.length>1)unsupported();
  const first=continuation.find(line=>line.trim());
  const indent=digits.length?Number(digits[0]):first?.match(/^ */)[0].length??0;
  if(!indent||!first)throw Error('EMPTY_SKILL_DESCRIPTION');
  const lines=continuation.map(line=>{
   if(!line.trim())return '';
   if(!line.startsWith(' '.repeat(indent)))unsupported();
   return line.slice(indent);
  });
  let value=block[1]==='|'?lines.join('\n')+'\n':folded(lines);
  const chomp=signs[0];
  if(chomp==='-')value=value.replace(/\n+$/,'');
  else if(chomp!=='+')value=value.replace(/\n+$/,'')+'\n';
  return value;
 }
 if(/^[>|&*!{[\]]/.test(raw))unsupported();
 // Flow scalars fold physical continuation lines, never truncate them.
 const lines=[raw,...continuation.map(line=>line.trim())];
 while(lines.at(-1)==='')lines.pop();
 const joined=folded(lines).replace(/\n$/,'');
 if(joined.startsWith('"')){
  const quoted=joined.match(/^("(?:[^"\\]|\\.)*")(?:[ \t]+#.*)?$/);
  if(!quoted)unsupported();
  try{return JSON.parse(quoted[1].replace(/\n/g,'\\n'));}catch{unsupported();}
 }
 if(joined.startsWith("'")){
  const quoted=joined.match(/^'((?:[^']|'')*)'(?:[ \t]+#.*)?$/);
  if(!quoted)unsupported();
  return quoted[1].replaceAll("''","'");
 }
 const plain=folded(lines.map(line=>line.replace(/[ \t]+#.*$/,''))).replace(/\n$/,'').trim();
 if(!plain||/:\s|^(?:null|true|false|~|[-+]?\d+(?:\.\d+)?)$/i.test(plain))unsupported();
 return plain;
}
export function skillHeader(text){
 const front=text.replace(/^\uFEFF/,'').replace(/\r\n?/g,'\n').match(/^---[ \t]*\n([\s\S]*?)\n---[ \t]*(?:\n|$)/)?.[1];
 if(front===undefined)throw Error('SKILL_FRONTMATTER_REQUIRED');
 const lines=front.split('\n'),values={};
 for(const key of ['name','description']){
  const matches=lines.flatMap((line,index)=>new RegExp('^'+key+':[ \t]*(.*)$').test(line)?[index]:[]);
  if(matches.length!==1)throw Error('INVALID_OR_DUPLICATE_SKILL_METADATA');
  const index=matches[0],raw=lines[index].slice(lines[index].indexOf(':')+1).trimStart(),continuation=[];
  for(let i=index+1;i<lines.length;i++){
   if(lines[i].trim()&&!/^[ \t]/.test(lines[i]))break;
   if(/^\t/.test(lines[i]))unsupported();
   continuation.push(lines[i]);
  }
  values[key]=scalar(raw,continuation);
 }
 if(!/^[a-z0-9-]{1,64}$/.test(values.name)||!values.description.trim())throw Error('INVALID_SKILL_METADATA');
 return values;
}

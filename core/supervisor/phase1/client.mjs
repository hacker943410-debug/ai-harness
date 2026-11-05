/** Public read-only client, and negative testing for unauthorized requests. */
import net from 'node:net';
import path from 'node:path';
export function request(socket, op, extra={}) {
 return new Promise((resolve,reject)=>{
  const c=net.createConnection(socket);let data='';
  c.setEncoding('utf8');c.setTimeout(2000);
  c.on('connect',()=>c.write(JSON.stringify({op,...extra})+'\n'));
  c.on('data',s=>data+=s);
  c.on('timeout',()=>c.destroy(Error('IPC_TIMEOUT')));
  c.on('error',reject);
  c.on('end',()=>{try{resolve(JSON.parse(data.trim()))}catch(e){reject(e)}});
 });
}
export async function readStatus(root) {
 try {return await request(path.join(root,'public','status.sock'),'status')}
 catch {return {decision:'DENY',state:'BLOCKED',desired:'UNKNOWN',reason:'SUPERVISOR_UNREACHABLE',enforcement:'NOT_ATTESTED',launchAuthorized:false}}
}

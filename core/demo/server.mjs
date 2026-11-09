import http from 'node:http';import fs from 'node:fs';import path from 'node:path';import crypto from 'node:crypto';import {fileURLToPath} from 'node:url';
const here=path.dirname(fileURLToPath(import.meta.url));
export function validateCustomer(input){
 if(!input||typeof input!=='object'||Array.isArray(input)||Object.keys(input).some(k=>!['name','email','note'].includes(k)))throw Error('이름·이메일·메모만 입력해 주세요.');
 const name=typeof input.name==='string'?input.name.trim():'',email=typeof input.email==='string'?input.email.trim().toLowerCase():'',note=typeof input.note==='string'?input.note.trim():'';
 if(name.length<1||name.length>80)throw Error('이름은 1~80자로 입력해 주세요.');
 if(!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)||email.length>200)throw Error('올바른 이메일을 입력해 주세요.');
 if(note.length>1000)throw Error('메모는 1,000자 이내로 입력해 주세요.');return{name,email,note};
}
export function createApp(dataDirectory){
 fs.mkdirSync(dataDirectory,{recursive:true});const file=path.join(dataDirectory,'customers.json');let customers=fs.existsSync(file)?JSON.parse(fs.readFileSync(file,'utf8')):[];
 if(!Array.isArray(customers))throw Error('저장 파일 형식을 확인해 주세요.');
 function save(){const temp=file+'.tmp';fs.writeFileSync(temp,JSON.stringify(customers,null,2)+'\n');fs.renameSync(temp,file);}
 const json=(res,code,value)=>{res.writeHead(code,{'Content-Type':'application/json; charset=utf-8','Cache-Control':'no-store','X-Content-Type-Options':'nosniff'});res.end(JSON.stringify(value));};
 return http.createServer(async(req,res)=>{
  try{
   const url=new URL(req.url,'http://127.0.0.1');
   if(url.pathname==='/api/customers'||url.pathname.startsWith('/api/customers/')){
    if(req.headers.origin&&req.headers.origin!=='http://'+req.headers.host)return json(res,403,{error:'외부 웹 페이지의 변경 요청은 허용하지 않습니다.'});
    const id=url.pathname.slice('/api/customers/'.length),index=customers.findIndex(c=>c.id===id);
    if(req.method==='GET'&&url.pathname==='/api/customers'){const q=(url.searchParams.get('q')??'').toLowerCase();return json(res,200,customers.filter(c=>(c.name+' '+c.email+' '+c.note).toLowerCase().includes(q)));}
    if(req.method==='DELETE'&&index>=0){const before=customers;customers=customers.filter(c=>c.id!==id);try{save();}catch(e){customers=before;throw e;}return json(res,200,{deleted:true});}
    if(req.method==='POST'||req.method==='PUT'){
     if(req.headers['content-type']?.split(';')[0]!=='application/json')return json(res,415,{error:'JSON 형식이 필요합니다.'});
     if(req.method==='PUT'&&index<0)return json(res,404,{error:'고객을 찾지 못했습니다.'});
     if(req.method==='POST'&&url.pathname!=='/api/customers')return json(res,404,{error:'잘못된 주소입니다.'});
     let bytes=0;const chunks=[];for await(const chunk of req){bytes+=chunk.length;if(bytes>16384){json(res,413,{error:'입력 내용이 너무 큽니다.'});req.resume();return;}chunks.push(chunk);}
     let value;try{value=validateCustomer(JSON.parse(Buffer.concat(chunks).toString('utf8')));}catch(e){return json(res,400,{error:e instanceof SyntaxError?'입력 JSON을 확인해 주세요.':e.message});}
     if(customers.some(c=>c.email===value.email&&c.id!==id))return json(res,409,{error:'같은 이메일의 고객이 이미 있습니다.'});
     if(req.method==='POST'&&customers.length>=1000)return json(res,409,{error:'로컬 데모는 고객 1,000명까지 지원합니다.'});
     const before=customers,customer={...value,id:req.method==='POST'?crypto.randomUUID():id};customers=req.method==='POST'?[...customers,customer]:customers.map(c=>c.id===id?customer:c);
     try{save();}catch(e){customers=before;throw e;}return json(res,req.method==='POST'?201:200,customer);
    }
    return json(res,req.method==='DELETE'?404:405,{error:'고객 또는 요청 방법을 확인해 주세요.'});
   }
   if(req.method!=='GET'&&req.method!=='HEAD')return json(res,405,{error:'허용하지 않는 요청입니다.'});
   const files={'/':['index.html','text/html; charset=utf-8'],'/app.js':['app.js','text/javascript; charset=utf-8'],'/style.css':['style.css','text/css; charset=utf-8']},asset=files[url.pathname];if(!asset)return json(res,404,{error:'페이지를 찾지 못했습니다.'});
   res.writeHead(200,{'Content-Type':asset[1],'X-Content-Type-Options':'nosniff','Content-Security-Policy':"default-src 'self'; script-src 'self'; style-src 'self'; connect-src 'self'; frame-ancestors 'none'; base-uri 'none'"});res.end(req.method==='HEAD'?undefined:fs.readFileSync(path.join(here,'public',asset[0])));
  }catch{if(!res.headersSent)json(res,500,{error:'저장 또는 요청 처리에 실패했습니다. 데이터를 확인한 뒤 다시 시도해 주세요.'});else res.end();}
 });
}
if(process.argv[1]&&path.resolve(process.argv[1])===fileURLToPath(import.meta.url)){
 const app=createApp(process.env.JH_DEMO_DATA??path.join(here,'data')),port=Number(process.env.PORT??3848);app.listen(port,'127.0.0.1',()=>console.log('고객 노트: http://127.0.0.1:'+app.address().port+' · 종료 Ctrl+C · 로컬 데모'));
 app.on('error',()=>{console.error('포트를 사용할 수 없습니다. PORT 환경변수로 다른 포트를 지정해 주세요.');process.exitCode=1;});
}

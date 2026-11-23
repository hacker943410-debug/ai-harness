import fs from 'node:fs';
import path from 'node:path';
import {spawn,spawnSync} from 'node:child_process';
import {noLinks} from './io.mjs';

const timeout=120000;
const maxBuffer=4*1024*1024;

export async function runVerification(executable,args,{project,env,logs}){
 const options={cwd:project,env,windowsHide:true,shell:false};
 const result=spawnSync(executable,args,{...options,timeout,maxBuffer});
 // A pipe setup failure has no child PID. Never rerun a test that actually started.
 if(process.platform==='win32'&&result.pid===0&&result.error?.code==='EPERM')
  return runWithFileHandles(executable,args,options,logs);
 return result;
}

async function runWithFileHandles(executable,args,options,logs){
 noLinks(logs);
 fs.mkdirSync(logs,{recursive:true});
 const folder=fs.mkdtempSync(path.join(logs,'.capture-'));
 const opened=[];
 try{
  for(const name of ['stdout','stderr']){
   const file=path.join(folder,name);
   const fd=fs.openSync(file,'wx+',0o600);
   opened.push({fd,file});
   // Keep the handle, without leaving raw output accessible by pathname.
   fs.unlinkSync(file);
  }
  const fds=opened.map(({fd})=>fd);
  const child=spawn(executable,args,{...options,stdio:['ignore',...fds]});
  const overLimit=()=>fds.some(fd=>fs.fstatSync(fd).size>maxBuffer);
  const result=await new Promise(resolve=>{
   let error;
   const stop=code=>{
    if(error)return;
    error={code};
    child.kill();
   };
   const deadline=setTimeout(()=>stop('ETIMEDOUT'),timeout);
   const sizeCheck=setInterval(()=>{if(overLimit())stop('ENOBUFS');},25);
   child.on('error',failure=>{error??=failure;});
   child.once('close',status=>{
    clearTimeout(deadline);
    clearInterval(sizeCheck);
    resolve({status,error:error??(overLimit()?{code:'ENOBUFS'}:undefined)});
   });
  });
  const [stdout,stderr]=fds.map(readBounded);
  return {...result,stdout,stderr,captureMode:'UNLINKED_FILES'};
 }catch(error){
  return {status:null,error,captureMode:'UNLINKED_FILES'};
 }finally{
  for(const {fd,file} of opened){
   fs.closeSync(fd);
   if(fs.existsSync(file))fs.unlinkSync(file);
  }
  fs.rmdirSync(folder);
 }
}

function readBounded(fd){
 const bytes=Buffer.alloc(Math.min(maxBuffer,fs.fstatSync(fd).size));
 let read=0;
 while(read<bytes.length){
  const count=fs.readSync(fd,bytes,read,bytes.length-read,read);
  if(!count)break;
  read+=count;
 }
 return bytes.subarray(0,read);
}

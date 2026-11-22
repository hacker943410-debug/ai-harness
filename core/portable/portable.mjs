#!/usr/bin/env node
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {configurePortable,portableStatus} from './lib/portable-context.mjs';
const root=path.dirname(fileURLToPath(import.meta.url));
try{
 const args=process.argv.slice(2),separator=args.indexOf('--'),head=separator<0?args:args.slice(0,separator);
 if(head.includes('--codex-home'))throw Error('PROJECT_PORTABLE_DOES_NOT_USE_CODEX_HOME');
 if(head.filter(x=>x==='--project').length>1)throw Error('DUPLICATE_PROJECT_OPTION');
 const at=head.indexOf('--project');let project=process.cwd();if(at>=0){project=head[at+1];if(!project||project.startsWith('--'))throw Error('PROJECT_VALUE_REQUIRED');head.splice(at,2);}
 const context=configurePortable(root,path.resolve(project));
 const command=head[0];
 if(command==='--version'){console.log(context.version);}
 else if(command==='--help'||command==='completion'){console.log('J Harness Core '+context.version+' · PROJECT_PORTABLE\nStart with: .\\JHarness.cmd quickstart\nOther commands: status, doctor, connect claude, environment, route, begin, advance, verify, finish, policy, skills, progress, learn, lessons');}
 else if(!command){console.log(JSON.stringify(portableStatus(),null,2));}
 else{if(!['status','doctor','environment','quickstart','connect','supervisor','route','begin','advance','verify','finish','policy','skills','progress','learn','lessons'].includes(command))throw Error('COMMAND_UNAVAILABLE_IN_PROJECT_PORTABLE: '+command);process.argv=[process.execPath,path.join(root,'runtime/core/cli.mjs'),'--project',context.project,...head,...(separator<0?[]:['--',...args.slice(separator+1)])];await import('./runtime/core/cli.mjs');}
}catch(error){console.error(JSON.stringify({product:'J Harness Core',mode:'PROJECT_PORTABLE',result:'BLOCKED',reason:error.message}));process.exitCode=1;}

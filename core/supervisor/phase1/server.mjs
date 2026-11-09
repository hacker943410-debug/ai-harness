#!/usr/bin/env node
import {startLabBroker} from './broker.mjs';
const [root,workspace]=process.argv.slice(2);
if (!root || !workspace) {console.error('Usage: node server.mjs ABSOLUTE_LAB_ROOT ABSOLUTE_WORKSPACE'); process.exit(2);}
try {
 const broker=await startLabBroker(root,workspace);
 console.log(JSON.stringify({ready:true,publicSocket:broker.publicSocket,controlSocket:broker.controlSocket,scope:'LAB_ONLY_NO_OS_INSTALL'}));
 const stop=async()=>{await broker.close();process.exit(0);};
 process.once('SIGTERM',stop);process.once('SIGINT',stop);
} catch(e){console.error(JSON.stringify({ready:false,error:e.message}));process.exit(2);}

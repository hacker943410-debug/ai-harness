// Uses the installed Core's proven unlink/backup routine, without requiring original setup media.
import path from 'node:path';
import {pathToFileURL} from 'node:url';
const home=process.env.CODEX_HOME;
if(!home||!path.isAbsolute(home))throw Error('INSTALLED_CODEX_HOME_REQUIRED');
const modulePath=path.join(home,'j-harness-core','runtime','core','lib','install.mjs');
const {uninstall}=await import(pathToFileURL(modulePath).href);
const result=uninstall(home);
process.stdout.write(JSON.stringify({result:'CORE_UNLINKED',details:result})+'\n');

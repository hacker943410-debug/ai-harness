import fs from 'node:fs';
import path from 'node:path';
import {atomic,json,projectSlot,readJson} from './io.mjs';
import {supportedClient} from '../environment/doctor.mjs';

const selectionPath=context=>path.join(projectSlot(context.project,context.project),'client-selection.json');

export function clientSelection(context) {
 if (context.projectBinding !== 'BOUND_VERIFIED') return {state:'SETUP_REQUIRED',client:null};
 try {
  const file=selectionPath(context);
  const stat=fs.lstatSync(file,{throwIfNoEntry:false});
  if (!stat) return {state:'UNSELECTED',client:null};
  if (stat.isFile() && stat.size<=4096) {
   const saved=readJson(file);
   if (saved?.schema===1 && supportedClient(saved.client)) return {state:'SELECTED',client:saved.client};
  }
 } catch {
  // Report the preference separately from runtime integrity.
 }
 return {state:'REVIEW_REQUIRED',client:null};
}

export function selectClient(context,client) {
 if (context.projectBinding !== 'BOUND_VERIFIED') throw Error('PROJECT_SETUP_REQUIRED: run JHarness.cmd setup');
 if (!supportedClient(client)) throw Error('UNKNOWN_CLIENT: use codex, claude or agy');
 const file=selectionPath(context);
 const stat=fs.lstatSync(file,{throwIfNoEntry:false});
 if (stat && (!stat.isFile()||stat.size>4096)) throw Error('CLIENT_SELECTION_FILE_REQUIRES_REVIEW');
 if (clientSelection(context).client!==client) atomic(file,json({schema:1,client}));
 return {state:'SELECTED',client};
}

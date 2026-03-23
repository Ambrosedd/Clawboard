#!/usr/bin/env node
const fs = require('fs');
const path = require('path');

function usage() {
  console.error('Usage: node tools/runtime-jsonl-to-state.js --input runtime-events.jsonl --output runtime-state.json');
  process.exit(1);
}

function arg(name) {
  const index = process.argv.indexOf(name);
  if (index === -1) return null;
  return process.argv[index + 1] || null;
}

const inputPath = arg('--input');
const outputPath = arg('--output');
if (!inputPath || !outputPath) usage();

const resolvedInput = path.resolve(inputPath);
const resolvedOutput = path.resolve(outputPath);
const raw = fs.readFileSync(resolvedInput, 'utf8');
const lines = raw.split(/\r?\n/).filter(Boolean);

const state = {
  schema_version: 'clawboard.bridge.state.v1',
  generated_at: new Date().toISOString(),
  lobsters: [],
  tasks: [],
  approvals: [],
  alerts: []
};

const indexes = {
  lobsters: new Map(),
  tasks: new Map(),
  approvals: new Map(),
  alerts: new Map()
};

function upsert(kind, item) {
  if (!item || !item.id) return;
  indexes[kind].set(item.id, item);
}

for (const line of lines) {
  let event;
  try {
    event = JSON.parse(line);
  } catch (error) {
    console.error(`Skipping invalid JSONL line: ${error.message}`);
    continue;
  }

  switch (event.type) {
    case 'lobster.upsert':
      upsert('lobsters', event.lobster);
      break;
    case 'task.upsert':
      upsert('tasks', event.task);
      break;
    case 'approval.upsert':
      upsert('approvals', event.approval);
      break;
    case 'alert.upsert':
      upsert('alerts', event.alert);
      break;
    case 'lobster.remove':
      if (event.id) indexes.lobsters.delete(event.id);
      break;
    case 'task.remove':
      if (event.id) indexes.tasks.delete(event.id);
      break;
    case 'approval.remove':
      if (event.id) indexes.approvals.delete(event.id);
      break;
    case 'alert.remove':
      if (event.id) indexes.alerts.delete(event.id);
      break;
    case 'state.snapshot':
      if (event.state && typeof event.state === 'object') {
        indexes.lobsters = new Map((event.state.lobsters || []).map(item => [item.id, item]));
        indexes.tasks = new Map((event.state.tasks || []).map(item => [item.id, item]));
        indexes.approvals = new Map((event.state.approvals || []).map(item => [item.id, item]));
        indexes.alerts = new Map((event.state.alerts || []).map(item => [item.id, item]));
      }
      break;
    default:
      break;
  }

  if (event.time) {
    state.generated_at = event.time;
  }
}

state.lobsters = Array.from(indexes.lobsters.values());
state.tasks = Array.from(indexes.tasks.values());
state.approvals = Array.from(indexes.approvals.values());
state.alerts = Array.from(indexes.alerts.values());

fs.mkdirSync(path.dirname(resolvedOutput), { recursive: true });
const tempPath = `${resolvedOutput}.tmp`;
fs.writeFileSync(tempPath, JSON.stringify(state, null, 2));
fs.renameSync(tempPath, resolvedOutput);

console.log(JSON.stringify({
  ok: true,
  input: resolvedInput,
  output: resolvedOutput,
  generated_at: state.generated_at,
  counts: {
    lobsters: state.lobsters.length,
    tasks: state.tasks.length,
    approvals: state.approvals.length,
    alerts: state.alerts.length
  }
}, null, 2));

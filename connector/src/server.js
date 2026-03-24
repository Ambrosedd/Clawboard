const http = require('http');
const os = require('os');
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const VERSION = '0.4.0';
const HOST = process.env.HOST || '0.0.0.0';
const PORT = Number(process.env.PORT || 8787);
const API_TOKEN = process.env.API_TOKEN || '';
const STATE_FILE = process.env.STATE_FILE || '';
const PERMISSION_PROFILE = process.env.PERMISSION_PROFILE || 'legacy';
const PERMISSION_PROFILE_PATH = process.env.PERMISSION_PROFILE_PATH || '';
const CAPABILITY_LEASES_FILE = process.env.CAPABILITY_LEASES_FILE || '';
const RESTART_SIGNAL_FILE = process.env.RESTART_SIGNAL_FILE || '';
const TOKENS_FILE = process.env.TOKENS_FILE || '';

function defaultPermissionProfile() {
  return {
    profile_id: PERMISSION_PROFILE,
    profile_title: 'Default Legacy Profile',
    runtime_profile: 'legacy',
    supports: {
      directory_access: true,
      command_alias: true,
      restart: true
    },
    directory_policy: {
      mode: 'allowlist-prefix',
      allowed_prefixes: ['/tmp', '/var/tmp', '/data/releases']
    },
    command_aliases: {
      git_status: { title: 'Git 状态检查', command_preview: 'git status --short' },
      release_build: { title: 'Release 构建', command_preview: 'npm run build' },
      restart_worker: { title: '重启 Worker', command_preview: 'systemctl restart lobster-worker' }
    },
    restart_action: RESTART_SIGNAL_FILE ? { type: 'signal_file', path: RESTART_SIGNAL_FILE } : null
  };
}

function normalizePermissionProfile(profile) {
  const base = defaultPermissionProfile();
  const merged = {
    ...base,
    ...(profile || {}),
    supports: { ...base.supports, ...((profile && profile.supports) || {}) },
    directory_policy: { ...base.directory_policy, ...((profile && profile.directory_policy) || {}) },
    command_aliases: { ...base.command_aliases, ...((profile && profile.command_aliases) || {}) }
  };

  if (!merged.runtime_profile) {
    merged.runtime_profile = merged.profile_id || 'legacy';
  }

  if (!merged.restart_action && RESTART_SIGNAL_FILE) {
    merged.restart_action = { type: 'signal_file', path: RESTART_SIGNAL_FILE };
  }

  return merged;
}

function summarizeRestartAction(action) {
  if (!action || !action.type) return null;
  switch (action.type) {
    case 'signal_file':
      return {
        type: 'signal_file',
        path: action.path || null,
        description: '通过受限 signal file 请求 runtime/supervisor 重启'
      };
    case 'supervisor_hint':
      return {
        type: 'supervisor_hint',
        target: action.target || null,
        description: '通过 profile 提示由宿主 supervisor 执行受控重启'
      };
    case 'none':
      return {
        type: 'none',
        description: '当前 profile 不提供 restart 动作'
      };
    default:
      return {
        type: action.type,
        description: '未知 restart action，仅做声明不直接执行'
      };
  }
}

function loadPermissionProfile() {
  if (!PERMISSION_PROFILE_PATH) {
    return normalizePermissionProfile(defaultPermissionProfile());
  }

  try {
    const raw = fs.readFileSync(PERMISSION_PROFILE_PATH, 'utf8');
    const parsed = JSON.parse(raw);
    return normalizePermissionProfile(parsed);
  } catch (error) {
    console.warn(`Failed to load permission profile from ${PERMISSION_PROFILE_PATH}: ${error.message}`);
    return normalizePermissionProfile({
      profile_id: PERMISSION_PROFILE,
      profile_title: 'Fallback Profile',
      runtime_profile: 'fallback',
      supports: { directory_access: true, command_alias: false, restart: false },
      directory_policy: { mode: 'allowlist-prefix', allowed_prefixes: ['/tmp'] },
      command_aliases: {},
      restart_action: { type: 'none' }
    });
  }
}

const permissionProfile = loadPermissionProfile();

const deviceInfo = {
  id: process.env.NODE_ID || 'node-local-1',
  name: process.env.CONNECTOR_NAME || os.hostname(),
  platform: process.env.PLATFORM || process.platform,
  connector_version: VERSION,
  network_mode: process.env.NETWORK_MODE || 'direct',
  permission_profile: permissionProfile.profile_id || PERMISSION_PROFILE,
  runtime_profile: permissionProfile.runtime_profile || permissionProfile.profile_id || PERMISSION_PROFILE
};

const capabilityLeases = [];
const commandAliases = permissionProfile.command_aliases || {};

let pairing = createPairingSession();
const issuedTokens = new Map();
const eventClients = new Set();
const eventLog = [];
let nextEventID = 1;
if (API_TOKEN) {
  issuedTokens.set(API_TOKEN, {
    token: API_TOKEN,
    created_at: new Date().toISOString(),
    revoked_at: null,
    client: {
      device_name: 'Preconfigured Client',
      client_name: 'Clawboard App',
      client_version: VERSION
    }
  });
}
let state = createSeedState(deviceInfo.id);
let stateFileWatcher = null;
let stateReloadTimer = null;
let stateSourceStatus = {
  mode: STATE_FILE ? 'state_file' : 'seed',
  valid: true,
  last_loaded_at: STATE_FILE ? null : isoNow(),
  last_error: null,
  last_error_at: null,
  schema_version: STATE_FILE ? null : 'seed'
};

function defaultBridgeBaseURL() {
  const explicit = process.env.PUBLIC_BASE_URL;
  if (explicit) return explicit;

  const host = (process.env.PUBLIC_HOST || '127.0.0.1').trim();
  const protocol = (process.env.PUBLIC_PROTOCOL || 'http').trim();
  return `${protocol}://${host}:${PORT}`;
}

function createPairingSession() {
  const baseURL = defaultBridgeBaseURL();
  const pairCode = process.env.PAIR_CODE || 'LX-472911';
  const pairingLink = `clawboard://pair?code=${encodeURIComponent(pairCode)}&url=${encodeURIComponent(baseURL)}`;

  return {
    pairing_id: 'pair-001',
    pair_code: pairCode,
    expires_at: isoNowPlusMinutes(10),
    node_id: deviceInfo.id,
    display_name: `${deviceInfo.name} / Clawboard Bridge`,
    bridge_version: VERSION,
    network_hint: deviceInfo.network_mode,
    bridge_url: baseURL,
    pairing_link: pairingLink
  };
}

function getActivePairingSession() {
  if (!pairing || isExpired(pairing.expires_at)) {
    pairing = createPairingSession();
  }
  return pairing;
}

function createSeedState(nodeId) {
  return normalizeState({
    lobsters: [
      {
        id: 'lobster-1',
        name: '分析龙虾 A-01',
        status: 'busy',
        task_title: '客户报告生成',
        last_active_at: isoNowMinusMinutes(2),
        risk_level: 'medium',
        node_id: nodeId,
        recent_logs: [
          'bridge attached',
          'step search completed',
          'waiting approval for crm_export'
        ]
      },
      {
        id: 'lobster-2',
        name: '监控龙虾 OPS-02',
        status: 'paused',
        task_title: '巡检与告警归并',
        last_active_at: isoNowMinusMinutes(18),
        risk_level: 'low',
        node_id: nodeId,
        recent_logs: [
          'health scan completed',
          'alert summary prepared',
          'paused by operator'
        ]
      }
    ],
    tasks: [
      {
        id: 'task-1',
        title: '客户报告生成',
        status: 'waiting_approval',
        progress: 72,
        lobster_id: 'lobster-1',
        current_step: 'crm_export',
        risk_level: 'high',
        risk_score: 82,
        input_summary: '生成客户组 A 周报',
        output_summary: null,
        error_reason: null,
        timeline: [
          { step: 'plan', status: 'done' },
          { step: 'search', status: 'done' },
          { step: 'crm_export', status: 'waiting_approval' }
        ]
      },
      {
        id: 'task-2',
        title: '巡检与告警归并',
        status: 'paused',
        progress: 44,
        lobster_id: 'lobster-2',
        current_step: 'aggregate_alerts',
        risk_level: 'low',
        risk_score: 24,
        input_summary: '汇总今日日志与节点状态',
        output_summary: null,
        error_reason: null,
        timeline: [
          { step: 'collect_nodes', status: 'done' },
          { step: 'aggregate_alerts', status: 'paused' }
        ]
      }
    ],
    approvals: [
      {
        id: 'approval-1',
        task_id: 'task-1',
        lobster_id: 'lobster-1',
        title: '请求 CRM 导出权限',
        reason: '生成完整客户报告',
        scope: '客户组 A',
        expires_at: isoNowPlusMinutes(30),
        risk_level: 'high',
        status: 'pending',
        resolved_at: null,
        resolution: null
      }
    ],
    alerts: [
      {
        id: 'alert-1',
        level: 'P2',
        title: '任务异常重试过多',
        summary: '任务 task-1 在 10 分钟内失败 3 次',
        related_type: 'task',
        related_id: 'task-1'
      }
    ]
  });
}

function isObject(value) {
  return value && typeof value === 'object' && !Array.isArray(value);
}

function isISODateTime(value) {
  return typeof value === 'string' && !Number.isNaN(Date.parse(value));
}

function validateBridgeState(input) {
  const errors = [];

  if (!isObject(input)) {
    return ['root must be an object'];
  }

  if (input.schema_version !== 'clawboard.bridge.state.v1') {
    errors.push('schema_version must equal clawboard.bridge.state.v1');
  }
  if (!isISODateTime(input.generated_at)) {
    errors.push('generated_at must be a valid ISO date-time string');
  }

  const listFields = ['lobsters', 'tasks', 'approvals', 'alerts'];
  for (const field of listFields) {
    if (!Array.isArray(input[field])) {
      errors.push(`${field} must be an array`);
    }
  }

  if (Array.isArray(input.lobsters)) {
    input.lobsters.forEach((item, index) => {
      if (!isObject(item)) return errors.push(`lobsters[${index}] must be an object`);
      for (const key of ['id', 'name', 'status', 'risk_level', 'node_id']) {
        if (typeof item[key] !== 'string' || !item[key]) errors.push(`lobsters[${index}].${key} must be a non-empty string`);
      }
      if (!isISODateTime(item.last_active_at)) errors.push(`lobsters[${index}].last_active_at must be ISO date-time`);
      if (!Array.isArray(item.recent_logs) || !item.recent_logs.every(v => typeof v === 'string')) errors.push(`lobsters[${index}].recent_logs must be string array`);
    });
  }

  if (Array.isArray(input.tasks)) {
    input.tasks.forEach((item, index) => {
      if (!isObject(item)) return errors.push(`tasks[${index}] must be an object`);
      for (const key of ['id', 'title', 'status', 'lobster_id', 'current_step', 'risk_level']) {
        if (typeof item[key] !== 'string' || !item[key]) errors.push(`tasks[${index}].${key} must be a non-empty string`);
      }
      if (typeof item.progress !== 'number') errors.push(`tasks[${index}].progress must be a number`);
      if (typeof item.risk_score !== 'number') errors.push(`tasks[${index}].risk_score must be a number`);
      if (!Array.isArray(item.timeline)) {
        errors.push(`tasks[${index}].timeline must be an array`);
      } else {
        item.timeline.forEach((step, stepIndex) => {
          if (!isObject(step)) return errors.push(`tasks[${index}].timeline[${stepIndex}] must be an object`);
          if (typeof step.step !== 'string' || !step.step) errors.push(`tasks[${index}].timeline[${stepIndex}].step must be string`);
          if (typeof step.status !== 'string' || !step.status) errors.push(`tasks[${index}].timeline[${stepIndex}].status must be string`);
        });
      }
    });
  }

  if (Array.isArray(input.approvals)) {
    input.approvals.forEach((item, index) => {
      if (!isObject(item)) return errors.push(`approvals[${index}] must be an object`);
      for (const key of ['id', 'task_id', 'lobster_id', 'title', 'reason', 'scope', 'risk_level', 'status']) {
        if (typeof item[key] !== 'string' || !item[key]) errors.push(`approvals[${index}].${key} must be a non-empty string`);
      }
      if (!isISODateTime(item.expires_at)) errors.push(`approvals[${index}].expires_at must be ISO date-time`);
      if (item.resolved_at != null && !isISODateTime(item.resolved_at)) errors.push(`approvals[${index}].resolved_at must be null or ISO date-time`);
    });
  }

  if (Array.isArray(input.alerts)) {
    input.alerts.forEach((item, index) => {
      if (!isObject(item)) return errors.push(`alerts[${index}] must be an object`);
      for (const key of ['id', 'level', 'title', 'summary']) {
        if (typeof item[key] !== 'string' || !item[key]) errors.push(`alerts[${index}].${key} must be a non-empty string`);
      }
    });
  }

  return errors;
}

function normalizeState(input = {}) {
  return {
    lobsters: Array.isArray(input.lobsters) ? input.lobsters.map(item => ({
      id: item.id,
      name: item.name,
      status: item.status,
      task_title: item.task_title ?? null,
      last_active_at: item.last_active_at ?? isoNow(),
      risk_level: item.risk_level ?? 'low',
      node_id: item.node_id ?? deviceInfo.id,
      recent_logs: Array.isArray(item.recent_logs) ? item.recent_logs : []
    })) : [],
    tasks: Array.isArray(input.tasks) ? input.tasks.map(item => ({
      id: item.id,
      title: item.title,
      status: item.status,
      progress: Number.isFinite(item.progress) ? item.progress : 0,
      lobster_id: item.lobster_id,
      current_step: item.current_step ?? 'unknown',
      risk_level: item.risk_level ?? 'low',
      risk_score: Number.isFinite(item.risk_score) ? item.risk_score : 0,
      input_summary: item.input_summary ?? null,
      output_summary: item.output_summary ?? null,
      error_reason: item.error_reason ?? null,
      timeline: Array.isArray(item.timeline) ? item.timeline : []
    })) : [],
    approvals: Array.isArray(input.approvals) ? input.approvals.map(item => ({
      id: item.id,
      task_id: item.task_id,
      lobster_id: item.lobster_id,
      title: item.title,
      reason: item.reason,
      scope: item.scope,
      expires_at: item.expires_at ?? isoNowPlusMinutes(30),
      risk_level: item.risk_level ?? 'medium',
      status: item.status ?? 'pending',
      resolved_at: item.resolved_at ?? null,
      resolution: item.resolution ?? null
    })) : [],
    alerts: Array.isArray(input.alerts) ? input.alerts.map(item => ({
      id: item.id,
      level: item.level,
      title: item.title,
      summary: item.summary,
      related_type: item.related_type ?? null,
      related_id: item.related_id ?? null
    })) : []
  };
}

function loadStateFromFile(filePath) {
  const resolvedPath = path.resolve(filePath);
  const raw = fs.readFileSync(resolvedPath, 'utf8');
  const parsed = JSON.parse(raw);
  const errors = validateBridgeState(parsed);
  if (errors.length > 0) {
    const error = new Error(errors.join('; '));
    error.code = 'invalid_state_schema';
    error.validationErrors = errors;
    throw error;
  }
  return {
    normalized: normalizeState(parsed),
    schema_version: parsed.schema_version,
    generated_at: parsed.generated_at,
    source: resolvedPath
  };
}

function markStateInvalid(source, error) {
  stateSourceStatus = {
    ...stateSourceStatus,
    mode: 'state_file',
    valid: false,
    last_error: error.message || String(error),
    last_error_at: isoNow()
  };

  publishEvent('runtime.state.invalid', {
    source,
    message: error.message || String(error),
    validation_errors: Array.isArray(error.validationErrors) ? error.validationErrors.slice(0, 20) : []
  });
}

function persistBridgeState() {
  if (!STATE_FILE) return;
  const payload = {
    schema_version: 'clawboard.bridge.state.v1',
    generated_at: isoNow(),
    ...state
  };
  const resolved = path.resolve(STATE_FILE);
  const tmpPath = `${resolved}.tmp`;
  fs.mkdirSync(path.dirname(resolved), { recursive: true });
  fs.writeFileSync(tmpPath, JSON.stringify(payload, null, 2));
  fs.renameSync(tmpPath, resolved);
}

function applyExternalState(nextState, source = 'external_state_file', metadata = {}) {
  state = normalizeState(nextState);
  stateSourceStatus = {
    mode: 'state_file',
    valid: true,
    last_loaded_at: isoNow(),
    last_error: null,
    last_error_at: null,
    schema_version: metadata.schema_version || 'clawboard.bridge.state.v1'
  };
  publishEvent('runtime.state.reloaded', {
    source,
    generated_at: metadata.generated_at || null,
    schema_version: metadata.schema_version || null,
    lobsters: state.lobsters.length,
    tasks: state.tasks.length,
    approvals: state.approvals.filter(item => item.status === 'pending').length,
    alerts: state.alerts.length
  });
}

function startStateFileWatcher(filePath) {
  const resolvedPath = path.resolve(filePath);

  try {
    const initialState = loadStateFromFile(resolvedPath);
    applyExternalState(initialState.normalized, resolvedPath, initialState);
  } catch (error) {
    console.error(`Failed to load STATE_FILE ${resolvedPath}:`, error.message);
    markStateInvalid(resolvedPath, error);
  }

  stateFileWatcher = fs.watch(resolvedPath, { persistent: false }, () => {
    clearTimeout(stateReloadTimer);
    stateReloadTimer = setTimeout(() => {
      try {
        const nextState = loadStateFromFile(resolvedPath);
        applyExternalState(nextState.normalized, resolvedPath, nextState);
      } catch (error) {
        console.error(`Failed to reload STATE_FILE ${resolvedPath}:`, error.message);
        markStateInvalid(resolvedPath, error);
      }
    }, 150);
  });
}

function isoNow() {
  return new Date().toISOString();
}

function isoNowMinusMinutes(minutes) {
  return new Date(Date.now() - minutes * 60_000).toISOString();
}

function isoNowPlusMinutes(minutes) {
  return new Date(Date.now() + minutes * 60_000).toISOString();
}

function isExpired(isoTime) {
  return Date.parse(isoTime) <= Date.now();
}

function persistTokens() {
  if (!TOKENS_FILE) return;
  const payload = {
    schema_version: 'clawboard.bridge.tokens.v1',
    updated_at: isoNow(),
    items: Array.from(issuedTokens.values())
  };
  fs.mkdirSync(path.dirname(TOKENS_FILE), { recursive: true });
  fs.writeFileSync(TOKENS_FILE, JSON.stringify(payload, null, 2));
}

function loadPersistedTokens() {
  if (!TOKENS_FILE || !fs.existsSync(TOKENS_FILE)) return;
  try {
    const raw = fs.readFileSync(TOKENS_FILE, 'utf8');
    const parsed = JSON.parse(raw);
    const items = Array.isArray(parsed.items) ? parsed.items : [];
    for (const item of items) {
      if (item && typeof item.token === 'string' && item.token) {
        issuedTokens.set(item.token, item);
      }
    }
  } catch (error) {
    console.warn(`Failed to load TOKENS_FILE ${TOKENS_FILE}: ${error.message}`);
  }
}

function issueToken(client = {}) {
  const token = `cb_live_${crypto.randomBytes(12).toString('hex')}`;
  issuedTokens.set(token, {
    token,
    created_at: isoNow(),
    revoked_at: null,
    client: {
      device_name: client.device_name || 'Unknown Device',
      client_name: client.client_name || 'Clawboard App',
      client_version: client.client_version || '0.1.0'
    }
  });
  persistTokens();
  return token;
}

function revokeToken(token) {
  const record = issuedTokens.get(token);
  if (!record || record.revoked_at) return false;
  record.revoked_at = isoNow();
  issuedTokens.set(token, record);
  persistTokens();
  return true;
}

function getTokenRecord(token) {
  const record = issuedTokens.get(token);
  if (!record || record.revoked_at) return null;
  return record;
}

function getTokenRecordIncludingRevoked(token) {
  const record = issuedTokens.get(token);
  return record || null;
}

function tokenPreview(token) {
  return token ? `${token.slice(0, 12)}...` : null;
}

function getAuthDiagnostics(token) {
  const record = token ? getTokenRecordIncludingRevoked(token) : null;
  const activePairing = getActivePairingSession();

  let authState = 'missing';
  if (token) {
    if (!record) {
      authState = 'invalid';
    } else if (record.revoked_at) {
      authState = 'revoked';
    } else {
      authState = 'active';
    }
  }

  const pairSessionState = isExpired(activePairing.expires_at) ? 'expired' : 'active';
  return {
    auth_state: authState,
    token_present: Boolean(token),
    token_preview: tokenPreview(token),
    token_created_at: record?.created_at || null,
    token_revoked_at: record?.revoked_at || null,
    client: record?.client || null,
    pair_session: {
      pairing_id: activePairing.pairing_id,
      state: pairSessionState,
      expires_at: activePairing.expires_at,
      bridge_url: activePairing.bridge_url || null
    },
    bridge: {
      state_source: STATE_FILE ? 'state_file' : 'seed',
      state_status: stateSourceStatus,
      runtime_status: readRuntimeStatus(),
      active_leases: currentCapabilityLeases().length
    }
  };
}

function sendJson(res, statusCode, payload) {
  res.writeHead(statusCode, {
    'Content-Type': 'application/json; charset=utf-8',
    'Cache-Control': 'no-cache'
  });
  res.end(JSON.stringify(payload, null, 2));
}

function writeSSE(res, payload) {
  res.write(`id: ${payload.id}\n`);
  res.write(`event: ${payload.event}\n`);
  res.write(`data: ${JSON.stringify({ time: payload.time, data: payload.data })}\n\n`);
}

function publishEvent(event, data) {
  const payload = {
    id: String(nextEventID++),
    event,
    time: isoNow(),
    data
  };

  eventLog.push(payload);
  if (eventLog.length > 200) {
    eventLog.shift();
  }

  for (const client of eventClients) {
    writeSSE(client, payload);
  }

  return payload;
}

function sendError(res, statusCode, code, message) {
  return sendJson(res, statusCode, {
    error: { code, message }
  });
}

function notFound(res, entity = 'resource') {
  return sendError(res, 404, 'not_found', `${entity} not found`);
}

function readRuntimeStatus() {
  if (!STATE_FILE) {
    return {
      status: 'seed',
      source: null,
      last_restart_requested_at: null,
      last_restart_request_id: null,
      last_restart_requested_by: null,
      last_restart_handled_at: null,
      restart_execution_state: 'seed',
      restart_result: null,
      restart_evidence: null
    };
  }

  const statusFile = path.join(path.dirname(path.resolve(STATE_FILE)), 'runtime-status.json');
  if (!fs.existsSync(statusFile)) {
    return {
      status: 'unknown',
      source: statusFile,
      last_restart_requested_at: null,
      last_restart_request_id: null,
      last_restart_requested_by: null,
      last_restart_handled_at: null,
      restart_execution_state: 'unknown',
      restart_result: null,
      restart_evidence: null
    };
  }

  try {
    const parsed = JSON.parse(fs.readFileSync(statusFile, 'utf8'));
    return {
      status: parsed.status || 'unknown',
      source: statusFile,
      last_restart_requested_at: parsed.last_restart_requested_at || null,
      last_restart_request_id: parsed.last_restart_request_id || null,
      last_restart_requested_by: parsed.last_restart_requested_by || null,
      last_restart_handled_at: parsed.last_restart_handled_at || null,
      restart_execution_state: parsed.restart_execution_state || null,
      restart_result: parsed.restart_result || null,
      restart_evidence: parsed.restart_evidence || null
    };
  } catch (error) {
    return {
      status: 'invalid',
      source: statusFile,
      last_restart_requested_at: null,
      last_restart_request_id: null,
      last_restart_requested_by: null,
      last_restart_handled_at: null,
      restart_execution_state: 'invalid',
      restart_result: 'error',
      restart_evidence: null,
      error: error.message
    };
  }
}

function unauthorized(res, diagnostics = null) {
  return sendJson(res, 401, {
    error: { code: 'unauthorized', message: 'missing or invalid bearer token' },
    diagnostics
  });
}

function invalidRequest(res, message, code = 'invalid_request') {
  return sendError(res, 400, code, message);
}

function readBody(req) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    req.on('data', chunk => chunks.push(chunk));
    req.on('end', () => {
      if (chunks.length === 0) return resolve({});
      const text = Buffer.concat(chunks).toString('utf8').trim();
      if (!text) return resolve({});
      try {
        resolve(JSON.parse(text));
      } catch (error) {
        reject(error);
      }
    });
    req.on('error', reject);
  });
}

function matchRoute(pathname, pattern) {
  const pathParts = pathname.split('/').filter(Boolean);
  const patternParts = pattern.split('/').filter(Boolean);
  if (pathParts.length !== patternParts.length) return null;

  const params = {};
  for (let i = 0; i < patternParts.length; i += 1) {
    const patternPart = patternParts[i];
    const pathPart = pathParts[i];
    if (patternPart.startsWith(':')) {
      params[patternPart.slice(1)] = decodeURIComponent(pathPart);
      continue;
    }
    if (patternPart !== pathPart) return null;
  }
  return params;
}

function extractBearerToken(req) {
  const auth = req.headers.authorization || '';
  return auth.startsWith('Bearer ') ? auth.slice(7) : '';
}

function isLocalRequest(req) {
  const remote = req.socket?.remoteAddress || '';
  return remote === '127.0.0.1' || remote === '::1' || remote === '::ffff:127.0.0.1';
}

function ensureAuth(req, res) {
  if (req.url.startsWith('/pair/') || req.url.startsWith('/health')) return true;
  if (req.method === 'GET' && req.url.startsWith('/debug/diagnostics') && isLocalRequest(req)) return true;
  const token = extractBearerToken(req);
  if (token && getTokenRecord(token)) return true;
  unauthorized(res, getAuthDiagnostics(token));
  return false;
}

function getTaskById(taskId) {
  return state.tasks.find(task => task.id === taskId);
}

function getLobsterById(lobsterId) {
  return state.lobsters.find(lobster => lobster.id === lobsterId);
}

function getApprovalById(approvalId) {
  return state.approvals.find(approval => approval.id === approvalId);
}

function persistCapabilityLeases() {
  if (!CAPABILITY_LEASES_FILE) return;
  const payload = {
    schema_version: 'clawboard.capability.leases.v1',
    updated_at: isoNow(),
    items: currentCapabilityLeases()
  };
  fs.mkdirSync(path.dirname(CAPABILITY_LEASES_FILE), { recursive: true });
  fs.writeFileSync(CAPABILITY_LEASES_FILE, JSON.stringify(payload, null, 2));
}

function loadPersistedCapabilityLeases() {
  if (!CAPABILITY_LEASES_FILE || !fs.existsSync(CAPABILITY_LEASES_FILE)) return;
  try {
    const raw = fs.readFileSync(CAPABILITY_LEASES_FILE, 'utf8');
    const parsed = JSON.parse(raw);
    const items = Array.isArray(parsed.items) ? parsed.items : [];
    capabilityLeases.length = 0;
    for (const item of items) {
      if (item && typeof item.id === 'string' && typeof item.expires_at === 'string' && Date.parse(item.expires_at) > Date.now()) {
        capabilityLeases.push(item);
      }
    }
    persistCapabilityLeases();
  } catch (error) {
    console.warn(`Failed to load CAPABILITY_LEASES_FILE ${CAPABILITY_LEASES_FILE}: ${error.message}`);
  }
}

function currentCapabilityLeases() {
  const now = Date.now();
  const active = capabilityLeases.filter(lease => Date.parse(lease.expires_at) > now);
  if (active.length !== capabilityLeases.length) {
    capabilityLeases.length = 0;
    capabilityLeases.push(...active);
    persistCapabilityLeases();
  }
  return active;
}

function createCapabilityLease({ approval, grantedScope, durationMinutes, capabilityKind }) {
  const expiresAt = new Date(Date.now() + durationMinutes * 60 * 1000).toISOString();
  const lease = {
    id: `lease-${approval.id}`,
    approval_id: approval.id,
    lobster_id: approval.lobster_id,
    task_id: approval.task_id,
    capability_kind: capabilityKind,
    granted_scope: grantedScope,
    expires_at: expiresAt,
    created_at: isoNow()
  };
  capabilityLeases.push(lease);
  persistCapabilityLeases();
  return lease;
}

function appendLobsterLog(lobster, message) {
  if (!lobster) return;
  lobster.recent_logs.unshift(message);
  lobster.recent_logs = lobster.recent_logs.slice(0, 12);
}

function requestProfileRestart(reason, lobster, task) {
  const action = permissionProfile.restart_action;
  if (!action || action.type === 'none') {
    return { ok: false, action: summarizeRestartAction(action), requested_at: null, evidence: 'restart_not_supported' };
  }

  const requestedAt = isoNow();
  const requestPayload = {
    request_id: `restart-${Date.now()}`,
    reason,
    time: requestedAt,
    requested_by: 'connector',
    runtime_profile: permissionProfile.runtime_profile || permissionProfile.profile_id || 'legacy',
    lobster_id: lobster?.id || null,
    task_id: task?.id || null
  };

  try {
    if (action.type === 'signal_file' && action.path) {
      const resolved = path.isAbsolute(action.path) ? action.path : path.resolve(process.cwd(), action.path);
      fs.mkdirSync(path.dirname(resolved), { recursive: true });
      fs.writeFileSync(resolved, JSON.stringify(requestPayload, null, 2));
      return {
        ok: true,
        action: summarizeRestartAction(action),
        requested_at: requestedAt,
        evidence: `signal_file_written:${resolved}`,
        request_id: requestPayload.request_id
      };
    }

    if (action.type === 'supervisor_hint') {
      return {
        ok: true,
        action: summarizeRestartAction(action),
        requested_at: requestedAt,
        evidence: `supervisor_hint_declared:${action.target || 'default'}`,
        request_id: requestPayload.request_id
      };
    }
  } catch (error) {
    console.warn(`Failed to request restart action: ${error.message}`);
    return {
      ok: false,
      action: summarizeRestartAction(action),
      requested_at: requestedAt,
      evidence: `restart_request_failed:${error.message}`,
      request_id: requestPayload.request_id,
      error: error.message
    };
  }

  return {
    ok: false,
    action: summarizeRestartAction(action),
    requested_at: requestedAt,
    evidence: `restart_action_unhandled:${action.type}`
  };
}

function restartLobsterRuntime(lobster, task, reason = 'restart_requested') {
  if (!lobster) return null;
  const restartIssued = requestProfileRestart(reason, lobster, task);
  lobster.status = restartIssued.ok ? 'busy' : 'error';
  lobster.last_active_at = isoNow();
  appendLobsterLog(
    lobster,
    restartIssued.ok
      ? `runtime restart requested via profile (${reason})`
      : `runtime restart request failed (${reason}): ${restartIssued.evidence || restartIssued.error || 'unknown'}`
  );
  if (task) {
    task.status = restartIssued.ok ? 'running' : 'failed';
    task.current_step = 'restart_runtime';
    task.progress = Math.max(task.progress || 0, restartIssued.ok ? 84 : 0);
    task.timeline.push({
      step: 'restart_runtime',
      status: restartIssued.ok ? 'done' : 'failed',
      at: isoNow(),
      note: restartIssued.evidence || null
    });
    task.output_summary = restartIssued.evidence || task.output_summary;
    if (!restartIssued.ok) {
      task.error_reason = restartIssued.error || 'restart_request_failed';
    }
  }
  publishEvent('lobster.status.changed', {
    lobster_id: lobster.id,
    status: lobster.status,
    task_id: task?.id || null,
    action: 'restart',
    restart_request: restartIssued
  });
  if (task) {
    publishEvent('task.progress.updated', {
      task_id: task.id,
      status: task.status,
      progress: task.progress,
      current_step: task.current_step,
      source: reason,
      restart_request: restartIssued
    });
  }
  return restartIssued;
}

function lobsterDetail(lobster) {
  const currentTask = state.tasks.find(task => task.lobster_id === lobster.id && ['running', 'waiting_approval', 'paused', 'failed'].includes(task.status)) || null;
  return {
    id: lobster.id,
    name: lobster.name,
    status: lobster.status,
    current_task: currentTask
      ? {
          id: currentTask.id,
          title: currentTask.title,
          progress: currentTask.progress,
          current_step: currentTask.current_step
        }
      : null,
    recent_logs: lobster.recent_logs
  };
}

function controlResponse(action, targetId, extra = {}) {
  return {
    ok: true,
    action,
    target_id: targetId,
    time: isoNow(),
    ...extra
  };
}

function createDebugApproval(body = {}) {
  const lobster = getLobsterById(body.lobster_id || 'lobster-1') || state.lobsters[0];
  const task = getTaskById(body.task_id || 'task-1') || state.tasks.find(item => item.lobster_id === lobster?.id) || state.tasks[0];
  if (!lobster || !task) {
    throw new Error('no lobster/task available for debug approval');
  }

  const approval = {
    id: `approval-debug-${Date.now()}`,
    task_id: task.id,
    lobster_id: lobster.id,
    title: body.title || '测试权限审批',
    reason: body.reason || '用于验证 App 是否能显示新的审批卡片',
    scope: body.scope || '/data/releases/tmp',
    expires_at: isoNowPlusMinutes(Number(body.expires_in_minutes) || 30),
    risk_level: body.risk_level || 'high',
    status: 'pending',
    resolved_at: null,
    resolution: null,
    lobster_name: lobster.name
  };

  state.approvals.unshift(approval);
  lobster.status = 'busy';
  lobster.last_active_at = isoNow();
  appendLobsterLog(lobster, `debug approval created: ${approval.id}`);
  task.status = 'waiting_approval';
  task.current_step = 'debug_permission_request';
  task.timeline.push({ step: 'debug_permission_request', status: 'waiting_approval' });

  publishEvent('approval.created', {
    approval_id: approval.id,
    task_id: approval.task_id,
    lobster_id: approval.lobster_id,
    title: approval.title,
    scope: approval.scope,
    risk_level: approval.risk_level
  });
  publishEvent('task.progress.updated', {
    task_id: task.id,
    status: task.status,
    progress: task.progress,
    current_step: task.current_step,
    source: 'debug_approval_created'
  });

  return approval;
}

async function handler(req, res) {
  const url = new URL(req.url, `http://${req.headers.host || 'localhost'}`);
  const { pathname, searchParams } = url;

  if (!ensureAuth(req, res)) return;

  if (req.method === 'GET' && pathname === '/pair/session') {
    return sendJson(res, 200, getActivePairingSession());
  }

  if (req.method === 'POST' && pathname === '/pair/exchange') {
    let body = {};
    try {
      body = await readBody(req);
    } catch {
      return invalidRequest(res, 'request body must be valid JSON');
    }

    if (!body.pair_code) {
      return invalidRequest(res, 'pair_code is required');
    }

    const activePairing = getActivePairingSession();

    if (isExpired(activePairing.expires_at)) {
      return sendJson(res, 410, {
        error: {
          code: 'pair_session_expired',
          message: 'pair session has expired, please request a new pairing session'
        }
      });
    }

    if (body.pair_code !== activePairing.pair_code) {
      return invalidRequest(res, 'pair code is invalid or expired', 'pair_code_invalid');
    }

    const token = issueToken(body);
    publishEvent('pair.exchanged', {
      node_id: deviceInfo.id,
      client_name: body.client_name || 'Clawboard App',
      device_name: body.device_name || 'Unknown Device'
    });
    return sendJson(res, 200, {
      token,
      token_type: 'Bearer',
      issued_at: isoNow(),
      node: {
        id: deviceInfo.id,
        name: deviceInfo.name,
        platform: deviceInfo.platform
      },
      client: {
        device_name: body.device_name || 'Unknown Device',
        client_name: body.client_name || 'Clawboard App',
        client_version: body.client_version || '0.1.0'
      }
    });
  }

  if (req.method === 'GET' && pathname === '/health') {
    return sendJson(res, 200, {
      status: stateSourceStatus.valid ? 'ok' : 'degraded',
      version: VERSION,
      time: isoNow(),
      state_source: STATE_FILE ? 'state_file' : 'seed',
      state_status: stateSourceStatus
    });
  }

  if (req.method === 'GET' && pathname === '/stream/events') {
    res.writeHead(200, {
      'Content-Type': 'text/event-stream; charset=utf-8',
      'Cache-Control': 'no-cache, no-transform',
      Connection: 'keep-alive'
    });

    res.write(': clawboard bridge event stream\n\n');
    eventClients.add(res);

    const lastEventID = req.headers['last-event-id'];
    if (lastEventID) {
      const pending = eventLog.filter(item => Number(item.id) > Number(lastEventID));
      for (const event of pending) {
        writeSSE(res, event);
      }
    } else {
      for (const event of eventLog.slice(-10)) {
        writeSSE(res, event);
      }
    }

    const heartbeat = setInterval(() => {
      res.write(`: ping ${Date.now()}\n\n`);
    }, 15_000);

    req.on('close', () => {
      clearInterval(heartbeat);
      eventClients.delete(res);
    });
    return;
  }

  if (req.method === 'GET' && pathname === '/device/info') {
    return sendJson(res, 200, {
      ...deviceInfo,
      state_status: stateSourceStatus,
      permission_profile_title: permissionProfile.profile_title || null,
      supported_capability_kinds: Object.entries(permissionProfile.supports || {})
        .filter(([, enabled]) => Boolean(enabled))
        .map(([key]) => key),
      supported_command_aliases: Object.entries(commandAliases).map(([id, item]) => ({ id, ...item })),
      directory_policy: permissionProfile.directory_policy || null,
      active_capability_leases: currentCapabilityLeases(),
      runtime_status: readRuntimeStatus(),
      restart_action: summarizeRestartAction(permissionProfile.restart_action),
      runtime_profile: permissionProfile.runtime_profile || null
    });
  }

  if (req.method === 'GET' && pathname === '/auth/session') {
    const token = extractBearerToken(req);
    const diagnostics = getAuthDiagnostics(token);
    const record = getTokenRecordIncludingRevoked(token);
    return sendJson(res, 200, {
      node: {
        id: deviceInfo.id,
        name: deviceInfo.name,
        platform: deviceInfo.platform
      },
      session: {
        token_preview: diagnostics.token_preview,
        created_at: record?.created_at || null,
        revoked_at: record?.revoked_at || null,
        auth_state: diagnostics.auth_state,
        client: record?.client || null
      },
      diagnostics
    });
  }

  if (req.method === 'POST' && pathname === '/auth/revoke') {
    const token = extractBearerToken(req);
    const revoked = revokeToken(token);
    if (revoked) {
      publishEvent('auth.revoked', {
        node_id: deviceInfo.id,
        token_preview: tokenPreview(token)
      });
    }
    return sendJson(res, 200, {
      ok: revoked,
      revoked_at: revoked ? isoNow() : null,
      diagnostics: getAuthDiagnostics(token)
    });
  }

  if (req.method === 'GET' && pathname === '/lobsters') {
    return sendJson(res, 200, { items: state.lobsters.map(({ recent_logs, ...summary }) => summary) });
  }

  let params = matchRoute(pathname, '/lobsters/:id');
  if (req.method === 'GET' && params) {
    const lobster = getLobsterById(params.id);
    if (!lobster) return notFound(res, 'lobster');
    return sendJson(res, 200, lobsterDetail(lobster));
  }

  params = matchRoute(pathname, '/lobsters/:id/pause');
  if (req.method === 'POST' && params) {
    const lobster = getLobsterById(params.id);
    if (!lobster) return notFound(res, 'lobster');
    lobster.status = 'paused';
    lobster.last_active_at = isoNow();
    lobster.recent_logs.unshift('paused via bridge api');
    const task = state.tasks.find(item => item.lobster_id === lobster.id && ['running', 'waiting_approval', 'busy'].includes(item.status));
    if (task) task.status = 'paused';
    publishEvent('lobster.status.changed', {
      lobster_id: lobster.id,
      status: lobster.status,
      task_id: task?.id || null,
      action: 'pause'
    });
    return sendJson(res, 200, controlResponse('pause', lobster.id));
  }

  params = matchRoute(pathname, '/lobsters/:id/resume');
  if (req.method === 'POST' && params) {
    const lobster = getLobsterById(params.id);
    if (!lobster) return notFound(res, 'lobster');
    lobster.status = 'busy';
    lobster.last_active_at = isoNow();
    lobster.recent_logs.unshift('resumed via bridge api');
    const task = state.tasks.find(item => item.lobster_id === lobster.id && item.status === 'paused');
    if (task) task.status = 'running';
    publishEvent('lobster.status.changed', {
      lobster_id: lobster.id,
      status: lobster.status,
      task_id: task?.id || null,
      action: 'resume'
    });
    return sendJson(res, 200, controlResponse('resume', lobster.id));
  }

  params = matchRoute(pathname, '/lobsters/:id/terminate');
  if (req.method === 'POST' && params) {
    const lobster = getLobsterById(params.id);
    if (!lobster) return notFound(res, 'lobster');
    lobster.status = 'idle';
    lobster.task_title = null;
    lobster.last_active_at = isoNow();
    lobster.recent_logs.unshift('terminated via bridge api');
    const task = state.tasks.find(item => item.lobster_id === lobster.id && ['running', 'waiting_approval', 'paused'].includes(item.status));
    if (task) {
      task.status = 'terminated';
      task.error_reason = 'terminated_by_operator';
    }
    publishEvent('lobster.status.changed', {
      lobster_id: lobster.id,
      status: lobster.status,
      task_id: task?.id || null,
      action: 'terminate'
    });
    if (task) {
      publishEvent('task.failed', {
        task_id: task.id,
        reason: task.error_reason,
        source: 'operator_terminate'
      });
    }
    return sendJson(res, 200, controlResponse('terminate', lobster.id));
  }

  if (req.method === 'GET' && pathname === '/tasks') {
    const status = searchParams.get('status');
    const lobsterId = searchParams.get('lobster_id');
    const riskLevel = searchParams.get('risk_level');

    const items = state.tasks.filter(task => {
      if (status && task.status !== status) return false;
      if (lobsterId && task.lobster_id !== lobsterId) return false;
      if (riskLevel && task.risk_level !== riskLevel) return false;
      return true;
    });

    return sendJson(res, 200, { items });
  }

  params = matchRoute(pathname, '/tasks/:id');
  if (req.method === 'GET' && params) {
    const task = getTaskById(params.id);
    if (!task) return notFound(res, 'task');
    return sendJson(res, 200, task);
  }

  params = matchRoute(pathname, '/tasks/:id/retry');
  if (req.method === 'POST' && params) {
    const task = getTaskById(params.id);
    if (!task) return notFound(res, 'task');
    task.status = 'running';
    task.error_reason = null;
    task.progress = Math.min(task.progress, 60);
    task.timeline.push({ step: 'retry', status: 'done' });

    const lobster = getLobsterById(task.lobster_id);
    if (lobster) {
      lobster.status = 'busy';
      lobster.task_title = task.title;
      lobster.last_active_at = isoNow();
      lobster.recent_logs.unshift('task retried via bridge api');
    }

    publishEvent('task.progress.updated', {
      task_id: task.id,
      status: task.status,
      progress: task.progress,
      current_step: task.current_step,
      source: 'retry'
    });

    return sendJson(res, 200, controlResponse('retry', task.id));
  }

  if (req.method === 'GET' && pathname === '/approvals') {
    const items = state.approvals.filter(approval => approval.status === 'pending');
    return sendJson(res, 200, { items });
  }

  if (req.method === 'POST' && pathname === '/debug/test-approval') {
    let body = {};
    try {
      body = await readBody(req);
    } catch {
      return invalidRequest(res, 'request body must be valid JSON');
    }

    const approval = createDebugApproval(body);
    return sendJson(res, 200, controlResponse('debug_test_approval', approval.id, { approval }));
  }

  params = matchRoute(pathname, '/approvals/:id/approve');
  if (req.method === 'POST' && params) {
    const approval = getApprovalById(params.id);
    if (!approval) return notFound(res, 'approval');
    if (approval.status !== 'pending') {
      return invalidRequest(res, 'approval already resolved');
    }

    let body = {};
    try {
      body = await readBody(req);
    } catch {
      return invalidRequest(res, 'request body must be valid JSON');
    }

    const durationMinutes = Math.max(1, Math.min(Number(body.duration_minutes) || 30, 240));
    const grantedScope = body.granted_scope || approval.scope;
    const capabilityKind = body.capability_kind === 'command_alias' ? 'command_alias' : 'directory_access';
    const restartAfterGrant = Boolean(body.restart_after_grant);
    const commandAlias = capabilityKind === 'command_alias' ? String(body.command_alias || '').trim() : null;

    const allowedPrefixes = permissionProfile.directory_policy?.allowed_prefixes || [];

    if (capabilityKind === 'command_alias' && (!commandAlias || !commandAliases[commandAlias])) {
      return invalidRequest(res, 'command_alias must be one of the supported aliases');
    }
    if (capabilityKind === 'directory_access') {
      const allowed = allowedPrefixes.length === 0 || allowedPrefixes.some(prefix => grantedScope === prefix || grantedScope.startsWith(`${prefix}/`));
      if (!allowed) {
        return invalidRequest(res, `granted_scope must stay within allowed prefixes: ${allowedPrefixes.join(', ') || '(none configured)'}`);
      }
    }

    approval.status = 'approved';
    approval.resolved_at = isoNow();
    approval.resolution = {
      granted_scope: grantedScope,
      duration_minutes: durationMinutes,
      capability_kind: capabilityKind,
      command_alias: commandAlias,
      restart_after_grant: restartAfterGrant
    };

    const lease = createCapabilityLease({
      approval,
      grantedScope,
      durationMinutes,
      capabilityKind
    });

    const task = getTaskById(approval.task_id);
    if (task) {
      task.status = 'running';
      task.current_step = 'crm_export';
      task.timeline = task.timeline.map(step => step.step === 'crm_export' ? { ...step, status: 'in_progress' } : step);
    }

    const lobster = getLobsterById(approval.lobster_id);
    if (lobster) {
      lobster.status = 'busy';
      lobster.last_active_at = isoNow();
      const scopeText = capabilityKind === 'command_alias'
        ? `command alias ${commandAlias}`
        : `directory ${grantedScope}`;
      appendLobsterLog(lobster, `temporary capability granted: ${scopeText} (${durationMinutes}m)`);
    }

    publishEvent('approval.resolved', {
      approval_id: approval.id,
      status: approval.status,
      task_id: approval.task_id,
      lobster_id: approval.lobster_id,
      granted_scope: approval.resolution?.granted_scope || approval.scope,
      capability_kind: capabilityKind,
      command_alias: commandAlias,
      lease_id: lease.id,
      restart_after_grant: restartAfterGrant
    });
    if (task) {
      publishEvent('task.progress.updated', {
        task_id: task.id,
        status: task.status,
        progress: task.progress,
        current_step: task.current_step,
        source: 'approval_approved'
      });
    }

    if (restartAfterGrant) {
      restartLobsterRuntime(lobster, task, 'temporary_capability_granted');
    }

    return sendJson(res, 200, controlResponse('approve', approval.id, { approval, capability_lease: lease }));
  }

  params = matchRoute(pathname, '/approvals/:id/reject');
  if (req.method === 'POST' && params) {
    const approval = getApprovalById(params.id);
    if (!approval) return notFound(res, 'approval');
    if (approval.status !== 'pending') {
      return invalidRequest(res, 'approval already resolved');
    }

    let body = {};
    try {
      body = await readBody(req);
    } catch {
      return invalidRequest(res, 'request body must be valid JSON');
    }

    approval.status = 'rejected';
    approval.resolved_at = isoNow();
    approval.resolution = {
      reason: body.reason || 'rejected_by_operator'
    };

    const task = getTaskById(approval.task_id);
    if (task) {
      task.status = 'failed';
      task.error_reason = 'approval_rejected';
      task.timeline = task.timeline.map(step => step.step === 'crm_export' ? { ...step, status: 'rejected' } : step);
    }

    const lobster = getLobsterById(approval.lobster_id);
    if (lobster) {
      lobster.status = 'error';
      lobster.last_active_at = isoNow();
      lobster.recent_logs.unshift(`approval ${approval.id} rejected`);
    }

    publishEvent('approval.resolved', {
      approval_id: approval.id,
      status: approval.status,
      task_id: approval.task_id,
      lobster_id: approval.lobster_id,
      reason: approval.resolution?.reason || 'rejected_by_operator'
    });
    if (task) {
      publishEvent('task.failed', {
        task_id: task.id,
        reason: task.error_reason,
        source: 'approval_rejected'
      });
    }
    publishEvent('alert.created', {
      level: 'P1',
      related_type: 'task',
      related_id: approval.task_id,
      title: '审批被拒绝导致任务失败'
    });

    return sendJson(res, 200, controlResponse('reject', approval.id, { approval }));
  }

  if (req.method === 'GET' && pathname === '/capabilities/leases') {
    return sendJson(res, 200, {
      items: currentCapabilityLeases(),
      runtime_status: readRuntimeStatus()
    });
  }

  if (req.method === 'GET' && pathname === '/debug/diagnostics') {
    const token = extractBearerToken(req);
    return sendJson(res, 200, {
      node: deviceInfo,
      diagnostics: getAuthDiagnostics(token),
      tokens: Array.from(issuedTokens.values()).map(item => ({
        token_preview: tokenPreview(item.token),
        created_at: item.created_at || null,
        revoked_at: item.revoked_at || null,
        client: item.client || null
      })),
      runtime_status: readRuntimeStatus(),
      state_status: stateSourceStatus,
      active_capability_leases: currentCapabilityLeases()
    });
  }

  params = matchRoute(pathname, '/lobsters/:id/restart');
  if (req.method === 'POST' && params) {
    const lobster = getLobsterById(params.id);
    if (!lobster) return notFound(res, 'lobster');
    const task = state.tasks.find(item => item.lobster_id === lobster.id && ['running', 'waiting_approval', 'paused', 'failed'].includes(item.status)) || null;
    const restartRequest = restartLobsterRuntime(lobster, task, 'operator_restart');
    return sendJson(res, restartRequest?.ok ? 200 : 409, controlResponse('restart', lobster.id, { restart_request: restartRequest }));
  }

  if (req.method === 'GET' && pathname === '/alerts') {
    return sendJson(res, 200, { items: state.alerts });
  }

  return notFound(res);
}

const server = http.createServer((req, res) => {
  handler(req, res).catch(error => {
    console.error(error);
    sendError(res, 500, 'runtime_unavailable', error.message || 'unexpected server error');
  });
});

server.listen(PORT, HOST, () => {
  publishEvent('bridge.started', {
    node_id: deviceInfo.id,
    node_name: deviceInfo.name,
    version: VERSION,
    state_source: STATE_FILE ? 'state_file' : 'seed'
  });
  loadPersistedTokens();
  loadPersistedCapabilityLeases();
  if (STATE_FILE) {
    startStateFileWatcher(STATE_FILE);
  }
  console.log(`Clawboard Bridge listening on http://${HOST}:${PORT}`);
  const activePairing = getActivePairingSession();
  console.log(`Pair code: ${activePairing.pair_code} (expires at ${activePairing.expires_at})`);
  if (STATE_FILE) {
    console.log(`External state file: ${path.resolve(STATE_FILE)}`);
  }
});

const http = require('http');
const os = require('os');
const crypto = require('crypto');

const VERSION = '0.3.0';
const HOST = process.env.HOST || '0.0.0.0';
const PORT = Number(process.env.PORT || 8787);
const API_TOKEN = process.env.API_TOKEN || '';

const deviceInfo = {
  id: process.env.NODE_ID || 'node-local-1',
  name: process.env.CONNECTOR_NAME || os.hostname(),
  platform: process.env.PLATFORM || process.platform,
  connector_version: VERSION,
  network_mode: process.env.NETWORK_MODE || 'direct'
};

const pairing = createPairingSession();
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
const state = createSeedState(deviceInfo.id);

function createPairingSession() {
  return {
    pairing_id: 'pair-001',
    pair_code: process.env.PAIR_CODE || 'LX-472911',
    expires_at: isoNowPlusMinutes(10),
    node_id: deviceInfo.id,
    display_name: `${deviceInfo.name} / Clawboard Bridge`,
    bridge_version: VERSION,
    network_hint: deviceInfo.network_mode
  };
}

function createSeedState(nodeId) {
  return {
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
  };
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
  return token;
}

function revokeToken(token) {
  const record = issuedTokens.get(token);
  if (!record || record.revoked_at) return false;
  record.revoked_at = isoNow();
  issuedTokens.set(token, record);
  return true;
}

function getTokenRecord(token) {
  const record = issuedTokens.get(token);
  if (!record || record.revoked_at) return null;
  return record;
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

function unauthorized(res) {
  return sendError(res, 401, 'unauthorized', 'missing or invalid bearer token');
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

function ensureAuth(req, res) {
  if (req.url.startsWith('/pair/') || req.url.startsWith('/health')) return true;
  const token = extractBearerToken(req);
  if (token && getTokenRecord(token)) return true;
  unauthorized(res);
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

async function handler(req, res) {
  const url = new URL(req.url, `http://${req.headers.host || 'localhost'}`);
  const { pathname, searchParams } = url;

  if (!ensureAuth(req, res)) return;

  if (req.method === 'GET' && pathname === '/pair/session') {
    return sendJson(res, 200, pairing);
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

    if (isExpired(pairing.expires_at)) {
      return invalidRequest(res, 'pair code is invalid or expired', 'pair_code_invalid');
    }

    if (body.pair_code !== pairing.pair_code) {
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
      status: 'ok',
      version: VERSION,
      time: isoNow()
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
    return sendJson(res, 200, deviceInfo);
  }

  if (req.method === 'GET' && pathname === '/auth/session') {
    const token = extractBearerToken(req);
    const record = getTokenRecord(token);
    return sendJson(res, 200, {
      node: {
        id: deviceInfo.id,
        name: deviceInfo.name,
        platform: deviceInfo.platform
      },
      session: {
        token_preview: token ? `${token.slice(0, 12)}...` : null,
        created_at: record?.created_at || null,
        client: record?.client || null
      }
    });
  }

  if (req.method === 'POST' && pathname === '/auth/revoke') {
    const token = extractBearerToken(req);
    const revoked = revokeToken(token);
    if (revoked) {
      publishEvent('auth.revoked', {
        node_id: deviceInfo.id,
        token_preview: token ? `${token.slice(0, 12)}...` : null
      });
    }
    return sendJson(res, 200, {
      ok: revoked,
      revoked_at: revoked ? isoNow() : null
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

    approval.status = 'approved';
    approval.resolved_at = isoNow();
    approval.resolution = {
      granted_scope: body.granted_scope || approval.scope,
      duration_minutes: body.duration_minutes || 30
    };

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
      lobster.recent_logs.unshift(`approval ${approval.id} approved`);
    }

    publishEvent('approval.resolved', {
      approval_id: approval.id,
      status: approval.status,
      task_id: approval.task_id,
      lobster_id: approval.lobster_id,
      granted_scope: approval.resolution?.granted_scope || approval.scope
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

    return sendJson(res, 200, controlResponse('approve', approval.id, { approval }));
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
    version: VERSION
  });
  console.log(`Clawboard Bridge listening on http://${HOST}:${PORT}`);
  console.log(`Pair code: ${pairing.pair_code} (expires at ${pairing.expires_at})`);
});

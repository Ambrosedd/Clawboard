const navItems = Array.from(document.querySelectorAll('[data-target]'));
const screens = Array.from(document.querySelectorAll('.phone-wrap'));
const tabbars = Array.from(document.querySelectorAll('.tabbar'));
const notice = document.querySelector('#global-notice');
const state = {
  active: 'dashboard',
  approvals: 2,
  alerts: 1,
  paired: false,
  taskProgress: 72,
  lobsterFilter: 'all'
};

function setNotice(text) {
  if (!notice) return;
  notice.textContent = text;
  notice.classList.add('show');
  clearTimeout(setNotice._timer);
  setNotice._timer = setTimeout(() => notice.classList.remove('show'), 1800);
}

function updateNav(target) {
  navItems.forEach(item => {
    item.classList.toggle('active', item.dataset.target === target);
  });
}

function updateScreens(target) {
  screens.forEach(screen => {
    screen.classList.toggle('active-screen', screen.id === target);
  });
}

function updateTabbars(target) {
  tabbars.forEach(bar => {
    Array.from(bar.querySelectorAll('[data-target]')).forEach(item => {
      item.classList.toggle('active', item.dataset.target === target);
    });
  });
}

function navigate(target) {
  state.active = target;
  updateNav(target);
  updateScreens(target);
  updateTabbars(target);
}

function bindNavigation() {
  document.querySelectorAll('[data-target]').forEach(node => {
    node.addEventListener('click', () => {
      const target = node.dataset.target;
      if (target) navigate(target);
    });
  });
}

function bindActions() {
  document.querySelectorAll('[data-action="approve"]').forEach(btn => {
    btn.addEventListener('click', () => {
      state.approvals = Math.max(0, state.approvals - 1);
      document.querySelectorAll('[data-bind="approvals-count"]').forEach(el => {
        el.textContent = state.approvals;
      });
      setNotice('已批准请求，任务继续执行');
      state.taskProgress = 84;
      document.querySelectorAll('[data-bind="task-progress"]').forEach(el => {
        el.textContent = `${state.taskProgress}%`;
      });
      document.querySelectorAll('[data-bind="progress-width"]').forEach(el => {
        el.style.width = `${state.taskProgress}%`;
      });
    });
  });

  document.querySelectorAll('[data-action="reject"]').forEach(btn => {
    btn.addEventListener('click', () => {
      setNotice('已拒绝请求，龙虾将回退到安全分支');
    });
  });

  document.querySelectorAll('[data-action="pause"]').forEach(btn => {
    btn.addEventListener('click', () => setNotice('已发送暂停指令'));
  });

  document.querySelectorAll('[data-action="terminate"]').forEach(btn => {
    btn.addEventListener('click', () => setNotice('已发送终止指令'));
  });

  document.querySelectorAll('[data-action="pair"]').forEach(btn => {
    btn.addEventListener('click', () => {
      state.paired = true;
      document.querySelectorAll('[data-bind="pair-status"]').forEach(el => {
        el.textContent = '已配对';
        el.classList.add('is-paired');
      });
      setNotice('配对成功，已连接 Connector');
    });
  });

  document.querySelectorAll('[data-filter]').forEach(btn => {
    btn.addEventListener('click', () => {
      state.lobsterFilter = btn.dataset.filter;
      document.querySelectorAll('[data-filter]').forEach(el => {
        el.classList.toggle('active', el.dataset.filter === state.lobsterFilter);
      });
      setNotice(`已切换筛选：${btn.textContent.trim()}`);
    });
  });
}

bindNavigation();
bindActions();
navigate(state.active);

/**
 * TerminalModal — xterm.js modal for interactive SSH authentication.
 *
 * Usage:
 *   const modal = new TerminalModal({
 *     getApiConfig: () => apiConfig,
 *     showMessage: (text, type) => {},
 *     onSuccess: (hash) => {},
 *     onError: (hash, message) => {},
 *     getTranslation: (key, fallback) => string,
 *   });
 *   modal.open(hash, tunnelName);
 */
(function () {
  'use strict';

  var STATUS_MAP = {
    connecting:   { icon: 'hourglass_empty', css: 'terminal-status-connecting' },
    connected:    { icon: 'link',            css: 'terminal-status-connected' },
    success:      { icon: 'check_circle',    css: 'terminal-status-success' },
    error:        { icon: 'error',           css: 'terminal-status-error' },
    timeout:      { icon: 'timer_off',        css: 'terminal-status-timeout' },
    disconnected: { icon: 'link_off',         css: 'terminal-status-disconnected' },
  };

  function TerminalModal(options) {
    this._options = options || {};
    this._ws = null;
    this._term = null;
    this._fitAddon = null;
    this._isOpen = false;
    this._sessionActive = false;
    this._statusReceived = false;
    this._currentHash = null;
    this._autoCloseTimer = null;

    this._createDOM();
    this._bindGlobalEvents();
  }

  // ---- DOM creation ----

  TerminalModal.prototype._createDOM = function () {
    this._overlay = document.createElement('div');
    this._overlay.className = 'terminal-modal-overlay';
    this._overlay.innerHTML =
      '<div class="terminal-modal">' +
        '<div class="terminal-modal-header">' +
          '<div class="terminal-modal-title">' +
            '<i class="material-icons">terminal</i>' +
            '<span class="terminal-modal-name"></span>' +
            '<span class="terminal-modal-status terminal-status-connecting">' +
              '<i class="material-icons">hourglass_empty</i>' +
              '<span></span>' +
            '</span>' +
          '</div>' +
          '<div class="terminal-modal-actions">' +
            '<button class="terminal-modal-close" aria-label="Close">' +
              '<i class="material-icons">close</i>' +
            '</button>' +
          '</div>' +
        '</div>' +
        '<div class="terminal-modal-body" id="terminalContainer"></div>' +
        '<div class="terminal-modal-footer">' +
          '<span class="terminal-modal-hint"></span>' +
        '</div>' +
      '</div>';

    document.body.appendChild(this._overlay);

    this._nameEl = this._overlay.querySelector('.terminal-modal-name');
    this._statusEl = this._overlay.querySelector('.terminal-modal-status');
    this._containerEl = this._overlay.querySelector('.terminal-modal-body');
    this._hintEl = this._overlay.querySelector('.terminal-modal-hint');
    this._closeBtn = this._overlay.querySelector('.terminal-modal-close');

    var self = this;
    this._closeBtn.addEventListener('click', function () { self.close(); });
    this._overlay.addEventListener('click', function (e) {
      if (e.target === self._overlay) self.close();
    });
  };

  // ---- Global event listeners ----

  TerminalModal.prototype._bindGlobalEvents = function () {
    var self = this;

    this._resizeHandler = function () {
      if (self._fitAddon && self._isOpen) {
        self._fitAddon.fit();
      }
    };
    window.addEventListener('resize', this._resizeHandler);

    this._keyHandler = function (e) {
      if (e.key === 'Escape' && self._isOpen && !self._sessionActive) {
        self.close();
      }
    };
    document.addEventListener('keydown', this._keyHandler);
  };

  // ---- Open ----

  TerminalModal.prototype.open = function (hash, tunnelName) {
    if (this._isOpen) return;

    var apiConfig = this._options.getApiConfig ? this._options.getApiConfig() : {};
    if (!apiConfig.ws_enabled) {
      this._showMessage(
        this._t('terminal.ws_not_available', 'WebSocket server is not configured. Please use CLI for interactive authentication.'),
        'error'
      );
      return;
    }

    this._currentHash = hash;
    this._sessionActive = false;
    this._statusReceived = false;
    this._isOpen = true;

    // Update UI
    this._nameEl.textContent = tunnelName || hash.substring(0, 8);
    this._hintEl.textContent = this._t('terminal.footer_hint', 'Type your password or 2FA code when prompted. Press Enter to submit.');
    this._updateStatus('connecting');
    this._overlay.classList.add('visible');

    // Initialize xterm.js
    this._initTerminal();

    // Connect WebSocket
    this._connect(hash, apiConfig);
  };

  // ---- Terminal init ----

  TerminalModal.prototype._initTerminal = function () {
    this._containerEl.innerHTML = '';

    this._term = new Terminal({
      cursorBlink: true,
      fontSize: 14,
      fontFamily: "'Courier New', 'Menlo', 'DejaVu Sans Mono', monospace",
      theme: this._getTermTheme(),
      scrollback: 1000,
      convertEol: true,
    });

    this._fitAddon = new FitAddon.FitAddon();
    this._term.loadAddon(this._fitAddon);
    this._term.open(this._containerEl);

    // Delay fit to allow DOM layout to settle
    var self = this;
    requestAnimationFrame(function () {
      self._fitAddon.fit();
    });
  };

  // ---- WebSocket connection ----

  TerminalModal.prototype._connect = function (hash, apiConfig) {
    var protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
    var wsUrl = protocol + '//' + window.location.host + '/ws/auth/' + hash;

    if (apiConfig.api_key) {
      wsUrl += '?token=' + encodeURIComponent(apiConfig.api_key);
    }

    this._ws = new WebSocket(wsUrl);
    this._ws.binaryType = 'arraybuffer';

    var self = this;

    this._ws.onopen = function () {
      self._sessionActive = true;
      self._updateStatus('connected');
      self._term.focus();
    };

    this._ws.onmessage = function (event) {
      if (event.data instanceof ArrayBuffer) {
        // Binary PTY data
        var text = new TextDecoder().decode(event.data);
        self._term.write(text);
      } else {
        // Text message — try JSON status
        try {
          var msg = JSON.parse(event.data);
          if (msg.type === 'status') {
            self._handleStatus(msg);
          }
        } catch (e) {
          // Not JSON — write as plain text
          self._term.write(event.data);
        }
      }
    };

    this._ws.onclose = function () {
      self._sessionActive = false;
      if (!self._statusReceived) {
        self._updateStatus('disconnected');
        self._term.write('\r\n\x1b[90m[Connection closed]\x1b[0m\r\n');
      }
    };

    this._ws.onerror = function () {
      self._sessionActive = false;
      self._updateStatus('error');
      self._term.write('\r\n\x1b[31m[Connection error]\x1b[0m\r\n');
      self._showMessage(
        self._t('terminal.connection_error', 'Failed to connect to authentication server.'),
        'error'
      );
    };

    // Wire terminal input → WebSocket
    this._term.onData(function (data) {
      if (self._ws && self._ws.readyState === WebSocket.OPEN) {
        self._ws.send(new TextEncoder().encode(data));
      }
    });
  };

  // ---- Status message handling ----

  TerminalModal.prototype._handleStatus = function (msg) {
    this._statusReceived = true;
    this._sessionActive = false;

    var self = this;

    switch (msg.code) {
      case 'success':
        this._updateStatus('success');
        this._term.write('\r\n\x1b[32m\u2713 ' + msg.message + '\x1b[0m\r\n');
        this._showMessage(
          this._t('terminal.auth_success', 'Authentication successful! Tunnel is now running.'),
          'success'
        );
        this._autoCloseTimer = setTimeout(function () {
          self.close();
          if (self._options.onSuccess) self._options.onSuccess(self._currentHash);
        }, 3000);
        break;

      case 'error':
        this._updateStatus('error');
        this._term.write('\r\n\x1b[31m\u2717 ' + msg.message + '\x1b[0m\r\n');
        this._term.write('\r\n\x1b[33m' + this._t('terminal.close_hint', 'You may close this terminal.') + '\x1b[0m\r\n');
        if (this._options.onError) this._options.onError(this._currentHash, msg.message);
        break;

      case 'timeout':
        this._updateStatus('timeout');
        this._term.write('\r\n\x1b[33m\u23f1 ' + msg.message + '\x1b[0m\r\n');
        this._showMessage(
          this._t('terminal.session_timeout', 'Session timed out due to inactivity.'),
          'error'
        );
        break;
    }
  };

  // ---- Status badge update ----

  TerminalModal.prototype._updateStatus = function (state) {
    var info = STATUS_MAP[state];
    if (!info) return;

    // Remove all status classes
    var el = this._statusEl;
    Object.keys(STATUS_MAP).forEach(function (k) {
      el.classList.remove(STATUS_MAP[k].css);
    });
    el.classList.add(info.css);

    var iconEl = el.querySelector('.material-icons');
    var textEl = el.querySelector('span:not(.material-icons)');
    if (iconEl) iconEl.textContent = info.icon;
    if (textEl) textEl.textContent = this._t('terminal.status_' + state, state);
  };

  // ---- Close ----

  TerminalModal.prototype.close = function () {
    if (!this._isOpen) return;

    // Confirm if session is active
    if (this._sessionActive) {
      var msg = this._t('terminal.confirm_close', 'Authentication session is active. Close terminal?');
      if (!confirm(msg)) return;
    }

    // Clear auto-close timer
    if (this._autoCloseTimer) {
      clearTimeout(this._autoCloseTimer);
      this._autoCloseTimer = null;
    }

    // Close WebSocket
    if (this._ws) {
      try { this._ws.close(1000); } catch (e) { /* ignore */ }
      this._ws = null;
    }

    // Dispose terminal
    if (this._term) {
      this._term.dispose();
      this._term = null;
      this._fitAddon = null;
    }

    // Hide overlay
    this._overlay.classList.remove('visible');
    this._containerEl.innerHTML = '';

    this._isOpen = false;
    this._sessionActive = false;
    this._statusReceived = false;
    this._currentHash = null;
  };

  // ---- Theme ----

  TerminalModal.prototype._getTermTheme = function () {
    var styles = getComputedStyle(document.documentElement);
    var accent = styles.getPropertyValue('--accent').trim() || '#C2922E';

    return {
      background: '#1a1a1a',
      foreground: '#d4d4d4',
      cursor: accent,
      cursorAccent: '#1a1a1a',
      selectionBackground: 'rgba(255, 255, 255, 0.2)',
      black: '#1a1a1a',
      red: '#f48771',
      green: '#4ec9b0',
      yellow: '#dcdcaa',
      blue: '#569cd6',
      magenta: '#c586c0',
      cyan: '#9cdcfe',
      white: '#d4d4d4',
      brightBlack: '#808080',
      brightRed: '#f48771',
      brightGreen: '#4ec9b0',
      brightYellow: '#dcdcaa',
      brightBlue: '#569cd6',
      brightMagenta: '#c586c0',
      brightCyan: '#9cdcfe',
      brightWhite: '#ffffff',
    };
  };

  // ---- Helpers ----

  TerminalModal.prototype._t = function (key, fallback) {
    if (this._options.getTranslation) {
      return this._options.getTranslation(key, fallback);
    }
    return fallback || key;
  };

  TerminalModal.prototype._showMessage = function (text, type) {
    if (this._options.showMessage) {
      this._options.showMessage(text, type);
    }
  };

  // Export
  window.TerminalModal = TerminalModal;
})();

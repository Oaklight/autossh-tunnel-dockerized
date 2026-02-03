// Tunnel Detail Page JavaScript

document.addEventListener("DOMContentLoaded", () => {
    // API configuration - will be loaded from server
    let apiConfig = { base_url: '', api_key: '' };

    // Auto refresh settings
    let autoRefreshInterval = null;
    const AUTO_REFRESH_INTERVAL = 5000; // 5 seconds

    // Get tunnel hash from URL parameter
    const urlParams = new URLSearchParams(window.location.search);
    const tunnelHash = urlParams.get('hash');

    if (!tunnelHash) {
        showError('No tunnel hash provided');
        return;
    }

    // DOM Elements
    const tunnelName = document.getElementById('tunnelName');
    const tunnelHashEl = document.getElementById('tunnelHash');
    const remoteHost = document.getElementById('remoteHost');
    const remotePort = document.getElementById('remotePort');
    const localPort = document.getElementById('localPort');
    const direction = document.getElementById('direction');
    const interactive = document.getElementById('interactive');
    const statusValue = document.getElementById('statusValue');
    const logBox = document.getElementById('logBox');
    const startBtn = document.getElementById('startBtn');
    const restartBtn = document.getElementById('restartBtn');
    const stopBtn = document.getElementById('stopBtn');
    const refreshLogsBtn = document.getElementById('refreshLogsBtn');
    const clearLogsBtn = document.getElementById('clearLogsBtn');
    const autoRefreshCheckbox = document.getElementById('autoRefresh');

    let currentTunnel = null;

    // Initialize Material Design Components
    initializeMDC();

    // Load API config first, then load tunnel details
    loadAPIConfig().then(() => {
        loadTunnelDetails();
        // Start auto-refresh by default
        startAutoRefresh();
    });

    // Set up event listeners
    startBtn.addEventListener('click', () => handleControl('start'));
    restartBtn.addEventListener('click', () => handleControl('restart'));
    stopBtn.addEventListener('click', () => handleControl('stop'));
    refreshLogsBtn.addEventListener('click', () => {
        loadTunnelDetails();
        loadLogs();
    });
    clearLogsBtn.addEventListener('click', clearLogs);

    // Setup auto-refresh checkbox
    if (autoRefreshCheckbox) {
        // Initialize MDC checkbox
        const checkboxEl = autoRefreshCheckbox.closest('.mdc-checkbox');
        if (checkboxEl) {
            new mdc.checkbox.MDCCheckbox(checkboxEl);
        }

        // Set checkbox to checked by default (auto-refresh is enabled by default)
        autoRefreshCheckbox.checked = true;

        autoRefreshCheckbox.addEventListener('change', () => {
            if (autoRefreshCheckbox.checked) {
                startAutoRefresh();
            } else {
                stopAutoRefresh();
            }
        });
    }

    // Listen for i18n ready event to update translations
    window.addEventListener('i18nReady', () => {
        if (currentTunnel) {
            displayTunnelInfo(currentTunnel);
        }
    });

    // Listen for language change event to update translations
    window.addEventListener('languageChanged', () => {
        if (currentTunnel) {
            displayTunnelInfo(currentTunnel);
        }
    });

    function initializeMDC() {
        const buttons = document.querySelectorAll('.mdc-button');
        buttons.forEach(button => {
            mdc.ripple.MDCRipple.attachTo(button);
        });
    }

    // Load API configuration
    async function loadAPIConfig() {
        try {
            const response = await fetch('/api/config/api');
            if (response.ok) {
                const data = await response.json();
                apiConfig.base_url = data.base_url || '';
                apiConfig.api_key = data.api_key || '';
            }
        } catch (error) {
            console.warn('Failed to load API config:', error);
        }
    }

    // Helper function to make authenticated API calls
    function apiCall(endpoint, options = {}) {
        const url = apiConfig.base_url + endpoint;
        const headers = options.headers || {};

        // Add Bearer token if API key is configured
        if (apiConfig.api_key) {
            headers['Authorization'] = 'Bearer ' + apiConfig.api_key;
        }

        return fetch(url, { ...options, headers });
    }

    async function loadTunnelDetails(retryCount = 0) {
        try {
            // First, get the config to get tunnel details (only needed once on initial load)
            if (!currentTunnel) {
                if (!apiConfig.base_url) {
                    showError('API server not configured');
                    return;
                }

                // Use Config API from autossh container
                const configResponse = await apiCall('/config');
                if (!configResponse.ok) throw new Error('Failed to load configuration');

                const configData = await configResponse.json();
                const tunnel = configData.tunnels.find(t => t.hash === tunnelHash);

                if (!tunnel) {
                    showError('Tunnel not found');
                    return;
                }

                currentTunnel = tunnel;
                displayTunnelInfo(tunnel);

                // Load logs immediately (no delay)
                loadLogs();
            }

            // Refresh status immediately after loading details
            await refreshTunnelStatus();

        } catch (error) {
            console.error('Error loading tunnel details:', error);
            
            // Retry on failure (API might not be ready yet)
            if (!currentTunnel && retryCount < 3) {
                const delay = (retryCount + 1) * 500; // 500ms, 1s, 1.5s
                console.log(`Retrying tunnel details load in ${delay}ms (attempt ${retryCount + 1}/3)`);
                setTimeout(() => loadTunnelDetails(retryCount + 1), delay);
            } else if (!currentTunnel) {
                showError('Failed to load tunnel details');
            }
        }
    }

    // retryCount is used for fast retry on initial load
    async function refreshTunnelStatus(retryCount = 0) {
        if (!apiConfig.base_url || !currentTunnel) return;

        try {
            const statusResponse = await apiCall('/status');
            if (statusResponse.ok) {
                const statusData = await statusResponse.json();
                const tunnelStatus = statusData.find(t => t.hash === currentTunnel.hash);
                if (tunnelStatus) {
                    currentTunnel.status = tunnelStatus.status;
                    updateStatusDisplay(tunnelStatus.status);
                } else {
                    currentTunnel.status = 'STOPPED';
                    updateStatusDisplay('STOPPED');
                }
            } else if (retryCount < 5) {
                // Retry on non-ok response
                const delay = 500;
                console.log(`Status fetch failed, retrying in ${delay}ms (attempt ${retryCount + 1}/5)`);
                setTimeout(() => refreshTunnelStatus(retryCount + 1), delay);
            }
        } catch (error) {
            console.warn('Failed to refresh tunnel status:', error);
            // Retry on error
            if (retryCount < 5) {
                const delay = 500;
                console.log(`Status fetch error, retrying in ${delay}ms (attempt ${retryCount + 1}/5)`);
                setTimeout(() => refreshTunnelStatus(retryCount + 1), delay);
            }
        }
    }

    function displayTunnelInfo(tunnel) {
        tunnelName.textContent = tunnel.name || '-';
        tunnelHashEl.textContent = tunnel.hash || '-';
        remoteHost.textContent = tunnel.remote_host || '-';
        remotePort.textContent = tunnel.remote_port || '-';
        localPort.textContent = tunnel.local_port || '-';

        const directionText = tunnel.direction === 'remote_to_local'
            ? (window.i18n ? window.i18n.t('table.direction.remote_to_local') : 'Remote → Local')
            : (window.i18n ? window.i18n.t('table.direction.local_to_remote') : 'Local → Remote');
        direction.textContent = directionText;

        const enabledText = window.i18n ? window.i18n.t('buttons.interactive_auth_enabled') : 'Enabled';
        const disabledText = window.i18n ? window.i18n.t('buttons.interactive_auth_disabled') : 'Disabled';
        interactive.innerHTML = tunnel.interactive
            ? `<i class="material-icons" style="color: #4CAF50;">check_circle</i> ${enabledText}`
            : `<i class="material-icons" style="color: #9E9E9E;">cancel</i> ${disabledText}`;

        updateStatusDisplay(tunnel.status || 'Unknown');
    }

    function updateStatusDisplay(status) {
        let statusColor = "#9E9E9E";
        let statusIcon = "help_outline";
        let statusText = status || 'Unknown';

        // Normalize status
        const normalizedStatus = (status || 'UNKNOWN').toUpperCase();

        switch (normalizedStatus) {
            case 'RUNNING':
            case 'NORMAL':
                statusIcon = "check_circle";
                statusColor = "#4CAF50";
                statusText = window.i18n ? window.i18n.t('table.status.running') : 'Running';
                break;
            case 'STOPPED':
                statusIcon = "stop_circle";
                statusColor = "#9E9E9E";
                statusText = window.i18n ? window.i18n.t('table.status.stopped') : 'Stopped';
                break;
            case 'STARTING':
                statusIcon = "hourglass_empty";
                statusColor = "#FF9800";
                statusText = window.i18n ? window.i18n.t('table.status.starting') : 'Starting';
                break;
            case 'DEAD':
                statusIcon = "cancel";
                statusColor = "#F44336";
                statusText = window.i18n ? window.i18n.t('table.status.dead') : 'Dead';
                break;
        }

        statusValue.innerHTML = `
            <div style="display: flex; align-items: center;">
                <i class="material-icons" style="color: ${statusColor}; margin-right: 8px;">${statusIcon}</i>
                <span style="color: ${statusColor}; font-weight: 500;">${statusText}</span>
            </div>
        `;
    }

    async function handleControl(action) {
        const confirmMessages = {
            restart: window.i18n ? window.i18n.t('messages.confirm_restart') : 'Are you sure you want to restart this tunnel?',
            stop: window.i18n ? window.i18n.t('messages.confirm_stop') : 'Are you sure you want to stop this tunnel?'
        };

        if (confirmMessages[action] && !confirm(confirmMessages[action])) {
            return;
        }

        // Disable all buttons during operation
        setButtonsEnabled(false);

        try {
            let method = 'POST';

            if (action === 'restart') {
                // Stop first
                const stopResponse = await apiCall(`/stop/${tunnelHash}`, { method });
                if (!stopResponse.ok) throw new Error('Failed to stop tunnel');

                // Wait a bit
                await new Promise(resolve => setTimeout(resolve, 1000));

                // Then start
                const startResponse = await apiCall(`/start/${tunnelHash}`, { method });
                if (!startResponse.ok) throw new Error('Failed to start tunnel');
            } else {
                const response = await apiCall(`/${action}/${tunnelHash}`, { method });
                if (!response.ok) throw new Error(`Failed to ${action} tunnel`);
            }

            const successMsg = window.i18n ? window.i18n.t(`messages.${action}_success`) : `Tunnel ${action}ed successfully`;
            showMessage(successMsg, 'success');

            // Reload details after a short delay
            setTimeout(() => {
                loadTunnelDetails();
                loadLogs();
            }, 1500);

        } catch (error) {
            console.error(`Error ${action}ing tunnel:`, error);
            const failMsg = window.i18n ? window.i18n.t(`messages.${action}_failed`) : `Failed to ${action} tunnel`;
            showMessage(`${failMsg}: ${error.message}`, 'error');
        } finally {
            setButtonsEnabled(true);
        }
    }

    function setButtonsEnabled(enabled) {
        startBtn.disabled = !enabled;
        restartBtn.disabled = !enabled;
        stopBtn.disabled = !enabled;
    }

    async function loadLogs(retryCount = 0) {
        try {
            // Call the API endpoint directly
            const response = await apiCall(`/logs/${tunnelHash}`);

            if (!response.ok) {
                throw new Error(`HTTP error! status: ${response.status}`);
            }

            const data = await response.json();

            if (data.status === 'success' && data.log) {
                // The log content comes with \n escaped, we need to unescape it
                const logs = data.log.replace(/\\n/g, '\n');
                displayLogs(logs);
            } else if (data.error) {
                logBox.innerHTML = `<div class="log-placeholder"><i class="material-icons">info</i><p>${escapeHtml(data.error)}</p></div>`;
            } else {
                logBox.innerHTML = '<div class="log-placeholder"><i class="material-icons">info</i><p>No logs available yet</p></div>';
            }
        } catch (error) {
            console.error('Error loading logs:', error);

            if (retryCount < 3) {
                const delay = (retryCount + 1) * 1000; // 1s, 2s, 3s
                console.log(`Retrying log load in ${delay}ms (attempt ${retryCount + 1}/3)`);
                setTimeout(() => loadLogs(retryCount + 1), delay);
            } else {
                logBox.innerHTML = '<div class="log-placeholder"><i class="material-icons">error</i><p>Failed to load logs. Click refresh to try again.</p></div>';
            }
        }
    }

    function displayLogs(logs) {
        if (!logs || logs.trim() === '') {
            logBox.innerHTML = '<div class="log-placeholder"><i class="material-icons">info</i><p>No logs available</p></div>';
            return;
        }

        const lines = logs.split('\n');
        const formattedLines = lines.map(line => {
            let className = 'log-line';
            if (line.includes('[ERROR]')) className += ' error';
            else if (line.includes('[WARN]')) className += ' warn';
            else if (line.includes('[INFO]')) className += ' info';
            else if (line.includes('[DEBUG]')) className += ' debug';

            return `<div class="${className}">${escapeHtml(line)}</div>`;
        }).join('');

        logBox.innerHTML = formattedLines;

        // Auto-scroll to bottom
        logBox.scrollTop = logBox.scrollHeight;
    }

    function clearLogs() {
        logBox.innerHTML = '<div class="log-placeholder"><i class="material-icons">info</i><p>Logs cleared</p></div>';
    }

    // Start auto-refresh
    function startAutoRefresh() {
        if (autoRefreshInterval) return;
        autoRefreshInterval = setInterval(() => {
            refreshTunnelStatus();
            loadLogs();
        }, AUTO_REFRESH_INTERVAL);
    }

    // Stop auto-refresh
    function stopAutoRefresh() {
        if (autoRefreshInterval) {
            clearInterval(autoRefreshInterval);
            autoRefreshInterval = null;
        }
    }

    function showMessage(text, type = 'success') {
        // Remove existing messages
        const existingMessages = document.querySelectorAll('.message');
        existingMessages.forEach(msg => msg.remove());

        const message = document.createElement('div');
        message.className = `message ${type}`;
        message.textContent = text;

        const container = document.querySelector('.container');
        container.insertBefore(message, container.firstChild);

        // Auto-remove after 3 seconds
        setTimeout(() => {
            if (message.parentNode) {
                message.style.animation = 'fadeOut 0.3s ease-out';
                setTimeout(() => message.remove(), 300);
            }
        }, 3000);
    }

    function showError(text) {
        const container = document.querySelector('.container');
        container.innerHTML = `
            <div class="mdc-card detail-card">
                <div class="card-content" style="text-align: center; padding: 40px;">
                    <i class="material-icons" style="font-size: 64px; color: #f44336;">error</i>
                    <h2 style="margin-top: 16px; color: #f44336;">${text}</h2>
                    <a href="/" class="mdc-button mdc-button--raised" style="margin-top: 24px;">
                        <span class="mdc-button__ripple"></span>
                        <span class="mdc-button__label">Back to Home</span>
                    </a>
                </div>
            </div>
        `;
    }

    function escapeHtml(text) {
        const div = document.createElement('div');
        div.textContent = text;
        return div.innerHTML;
    }
});
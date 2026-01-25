// Tunnel Detail Page JavaScript

document.addEventListener("DOMContentLoaded", () => {
    // Get API base URL from window (set by server)
    const API_BASE_URL = window.API_BASE_URL || 'http://localhost:8080';

    // Get tunnel hash from URL parameter
    const urlParams = new URLSearchParams(window.location.search);
    const tunnelHash = urlParams.get('hash');

    if (!tunnelHash) {
        showError('No tunnel hash provided');
        return;
    }

    // DOM Elements
    const statusBadge = document.getElementById('statusBadge');
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

    let currentTunnel = null;

    // Initialize Material Design Components
    initializeMDC();

    // Load tunnel details
    loadTunnelDetails();

    // Set up event listeners
    startBtn.addEventListener('click', () => handleControl('start'));
    restartBtn.addEventListener('click', () => handleControl('restart'));
    stopBtn.addEventListener('click', () => handleControl('stop'));
    refreshLogsBtn.addEventListener('click', loadLogs);
    clearLogsBtn.addEventListener('click', clearLogs);

    function initializeMDC() {
        const buttons = document.querySelectorAll('.mdc-button');
        buttons.forEach(button => {
            mdc.ripple.MDCRipple.attachTo(button);
        });
    }

    async function loadTunnelDetails() {
        try {
            // First, get the config to get tunnel details (only needed once on initial load)
            if (!currentTunnel) {
                const configResponse = await fetch('/api/config');
                if (!configResponse.ok) throw new Error('Failed to load configuration');

                const configData = await configResponse.json();
                const tunnel = configData.tunnels.find(t => t.hash === tunnelHash);

                if (!tunnel) {
                    showError('Tunnel not found');
                    return;
                }

                currentTunnel = tunnel;
                displayTunnelInfo(tunnel);

                // Delay initial log loading to give API time to be ready
                setTimeout(() => loadLogs(), 1000);
            }

            // Get current status directly from API
            const statusResponse = await fetch(`${API_BASE_URL}/status`);
            if (statusResponse.ok) {
                const statusData = await statusResponse.json();
                const tunnelStatus = statusData.find(t => t.name === currentTunnel.name);
                if (tunnelStatus) {
                    updateStatusBadge(tunnelStatus.status);
                    statusValue.textContent = tunnelStatus.status || 'Unknown';
                }
            }
        } catch (error) {
            console.error('Error loading tunnel details:', error);
            if (!currentTunnel) {
                showError('Failed to load tunnel details');
            }
            // If it's just a status update failure, silently ignore
        }
    }

    function displayTunnelInfo(tunnel) {
        tunnelName.textContent = tunnel.name || '-';
        tunnelHashEl.textContent = tunnel.hash || '-';
        remoteHost.textContent = tunnel.remote_host || '-';
        remotePort.textContent = tunnel.remote_port || '-';
        localPort.textContent = tunnel.local_port || '-';

        const directionText = tunnel.direction === 'remote_to_local'
            ? 'Remote → Local'
            : 'Local → Remote';
        direction.textContent = directionText;

        interactive.innerHTML = tunnel.interactive
            ? '<i class="material-icons" style="color: #4CAF50;">check_circle</i> Enabled'
            : '<i class="material-icons" style="color: #9E9E9E;">cancel</i> Disabled';

        statusValue.textContent = tunnel.status || 'Unknown';
    }

    function updateStatusBadge(status) {
        // Remove all status classes
        statusBadge.classList.remove('running', 'stopped', 'starting', 'dead');

        let icon = 'help_outline';
        let text = 'Unknown';
        let className = '';

        switch (status) {
            case 'RUNNING':
            case 'NORMAL':
                icon = 'check_circle';
                text = 'Running';
                className = 'running';
                break;
            case 'STOPPED':
                icon = 'stop_circle';
                text = 'Stopped';
                className = 'stopped';
                break;
            case 'STARTING':
                icon = 'hourglass_empty';
                text = 'Starting';
                className = 'starting';
                break;
            case 'DEAD':
                icon = 'cancel';
                text = 'Dead';
                className = 'dead';
                break;
        }

        statusBadge.querySelector('.status-icon').textContent = icon;
        statusBadge.querySelector('.status-text').textContent = text;
        if (className) {
            statusBadge.classList.add(className);
        }
    }

    async function handleControl(action) {
        const confirmMessages = {
            restart: 'Are you sure you want to restart this tunnel?',
            stop: 'Are you sure you want to stop this tunnel?'
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
                const stopResponse = await fetch(`${API_BASE_URL}/stop/${tunnelHash}`, { method });
                if (!stopResponse.ok) throw new Error('Failed to stop tunnel');

                // Wait a bit
                await new Promise(resolve => setTimeout(resolve, 1000));

                // Then start
                const startResponse = await fetch(`${API_BASE_URL}/start/${tunnelHash}`, { method });
                if (!startResponse.ok) throw new Error('Failed to start tunnel');
            } else {
                const response = await fetch(`${API_BASE_URL}/${action}/${tunnelHash}`, { method });
                if (!response.ok) throw new Error(`Failed to ${action} tunnel`);
            }

            showMessage(`Tunnel ${action}ed successfully`, 'success');

            // Reload details after a short delay
            setTimeout(() => {
                loadTunnelDetails();
                loadLogs();
            }, 1500);

        } catch (error) {
            console.error(`Error ${action}ing tunnel:`, error);
            showMessage(`Failed to ${action} tunnel: ${error.message}`, 'error');
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
            const response = await fetch(`${API_BASE_URL}/logs/${tunnelHash}`);

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
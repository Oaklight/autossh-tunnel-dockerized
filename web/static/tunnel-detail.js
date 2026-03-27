// Tunnel Detail Page JavaScript

document.addEventListener("DOMContentLoaded", () => {
    // API configuration - will be loaded from server
    let apiConfig = { api_key: '', ws_enabled: false };

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
    const tunnelNameInput = document.getElementById('tunnelName');
    const tunnelHashEl = document.getElementById('tunnelHash');
    const remoteHostInput = document.getElementById('remoteHost');
    const remotePortInput = document.getElementById('remotePort');
    const localPortInput = document.getElementById('localPort');
    const directionSelect = document.getElementById('direction');
    const interactiveToggle = document.getElementById('interactiveToggle');
    const statusValue = document.getElementById('statusValue');
    const logBox = document.getElementById('logBox');
    const startBtn = document.getElementById('startBtn');
    const restartBtn = document.getElementById('restartBtn');
    const stopBtn = document.getElementById('stopBtn');
    const saveConfigBtn = document.getElementById('saveConfigBtn');
    const refreshLogsBtn = document.getElementById('refreshLogsBtn');
    const clearLogsBtn = document.getElementById('clearLogsBtn');
    const autoRefreshCheckbox = document.getElementById('autoRefresh');
    const copyHashBtn = document.getElementById('copyHashBtn');

    let currentTunnel = null;
    let currentHash = tunnelHash; // Track current hash (may change after save)

    // Terminal modal for interactive auth
    let terminalModal = null;

    // Load API config first, then load tunnel details
    loadAPIConfig().then(() => {
        // Initialize terminal modal if WebSocket is enabled
        if (apiConfig.ws_enabled && typeof TerminalModal === 'function') {
            terminalModal = new TerminalModal({
                getApiConfig: () => apiConfig,
                showMessage: showMessage,
                onSuccess: () => {
                    setTimeout(() => {
                        refreshTunnelStatus();
                        loadLogs();
                    }, 1500);
                },
                onError: () => {},
                getTranslation: getTranslation,
            });
        }

        loadTunnelDetails();
        // Start auto-refresh by default
        startAutoRefresh();
    });

    // Set up event listeners
    startBtn.addEventListener('click', () => handleControl('start'));
    restartBtn.addEventListener('click', () => handleControl('restart'));
    stopBtn.addEventListener('click', () => handleControl('stop'));
    saveConfigBtn.addEventListener('click', handleSaveConfig);
    refreshLogsBtn.addEventListener('click', () => {
        loadTunnelDetails();
        loadLogs();
    });
    clearLogsBtn.addEventListener('click', clearLogs);

    // Interactive toggle event
    interactiveToggle.addEventListener('click', () => {
        const isActive = interactiveToggle.classList.contains('active');
        const newState = !isActive;

        interactiveToggle.classList.toggle('active', newState);
        interactiveToggle.setAttribute('data-interactive', newState.toString());

        const enabledText = getTranslation('buttons.interactive_auth_enabled', 'Enabled');
        const disabledText = getTranslation('buttons.interactive_auth_disabled', 'Disabled');
        const toggleLabel = interactiveToggle.querySelector('.toggle-label');
        if (toggleLabel) {
            toggleLabel.textContent = newState ? enabledText : disabledText;
        }
    });

    // Input validation
    addInputValidation();

    // Copy hash button event
    if (copyHashBtn) {
        copyHashBtn.addEventListener('click', handleCopyHash);
    }

    // Setup auto-refresh checkbox
    if (autoRefreshCheckbox) {
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

    // Helper function to get translation with fallback
    function getTranslation(key, fallback) {
        if (window.i18n && window.i18n.isReady) {
            return window.i18n.t(key);
        }
        return fallback;
    }

    // Listen for i18n ready event to update translations
    window.addEventListener('i18nReady', () => {
        if (currentTunnel) {
            updateInteractiveToggleLabel();
            updateControlButtonTitles();
            updateStatusDisplay(currentTunnel.status || 'STOPPED');
        }
    });

    // Listen for language change event to update translations
    window.addEventListener('languageChanged', () => {
        if (currentTunnel) {
            updateInteractiveToggleLabel();
            updateControlButtonTitles();
            updateStatusDisplay(currentTunnel.status || 'STOPPED');
        }
    });

    // Update control button titles based on interactive state
    function updateControlButtonTitles() {
        const isInteractive = currentTunnel?.interactive || false;
        if (isInteractive && apiConfig.ws_enabled) {
            startBtn.title = getTranslation('buttons.interactive_start_terminal', 'Start with Interactive Auth');
            restartBtn.title = getTranslation('buttons.interactive_restart_terminal', 'Restart with Interactive Auth');
        } else if (isInteractive) {
            startBtn.title = getTranslation('buttons.interactive_start_disabled', 'Interactive Auth Required - Use CLI');
            restartBtn.title = getTranslation('buttons.interactive_restart_disabled', 'Interactive Auth Required - Use CLI');
        } else {
            startBtn.title = getTranslation('buttons.start_tunnel', 'Start tunnel');
            restartBtn.title = getTranslation('buttons.restart_tunnel', 'Restart tunnel');
        }
        stopBtn.title = getTranslation('buttons.stop_tunnel', 'Stop tunnel');
    }

    // Update interactive toggle label based on current state
    function updateInteractiveToggleLabel() {
        const isActive = interactiveToggle.classList.contains('active');
        const enabledText = getTranslation('buttons.interactive_auth_enabled', 'Enabled');
        const disabledText = getTranslation('buttons.interactive_auth_disabled', 'Disabled');
        const toggleLabel = interactiveToggle.querySelector('.toggle-label');
        if (toggleLabel) {
            toggleLabel.textContent = isActive ? enabledText : disabledText;
        }
    }

    // Load API configuration
    async function loadAPIConfig() {
        try {
            const response = await fetch('/api/config/api');
            if (response.ok) {
                const data = await response.json();
                apiConfig.api_key = data.api_key || '';
                apiConfig.ws_enabled = data.ws_enabled || false;
            }
        } catch (error) {
            console.warn('Failed to load API config:', error);
        }
    }

    // Helper function to make authenticated API calls (proxied through web panel)
    function apiCall(endpoint, options = {}) {
        const url = '/api/autossh' + endpoint;
        const headers = options.headers || {};

        // Add Bearer token if API key is configured
        if (apiConfig.api_key) {
            headers['Authorization'] = 'Bearer ' + apiConfig.api_key;
        }

        return fetch(url, { ...options, headers });
    }

    async function loadTunnelDetails(retryCount = 0) {
        // Show loading status on initial load
        if (!currentTunnel) {
            updateStatusDisplay('LOADING');
        }

        try {
            // First, get the config to get tunnel details (only needed once on initial load)
            if (!currentTunnel) {
                // Use Config API from autossh container
                const configResponse = await apiCall('/config');
                if (!configResponse.ok) throw new Error('Failed to load configuration');

                const configData = await configResponse.json();
                const tunnel = configData.tunnels.find(t => t.hash === currentHash);

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
        if (!currentTunnel) return;

        try {
            const statusResponse = await apiCall('/status');
            if (statusResponse.ok) {
                const statusData = await statusResponse.json();
                const tunnelStatus = statusData.find(t => t.hash === currentHash);
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
        // Set input values
        tunnelNameInput.value = tunnel.name || '';
        // Update hash text (inside the span)
        const hashTextEl = tunnelHashEl.querySelector('.hash-text');
        if (hashTextEl) {
            hashTextEl.textContent = tunnel.hash || '-';
        }
        remoteHostInput.value = tunnel.remote_host || '';
        remotePortInput.value = tunnel.remote_port || '';
        localPortInput.value = tunnel.local_port || '';

        // Set direction select
        directionSelect.value = tunnel.direction || 'remote_to_local';

        // Set interactive toggle
        const isInteractive = tunnel.interactive || false;
        interactiveToggle.classList.toggle('active', isInteractive);
        interactiveToggle.setAttribute('data-interactive', isInteractive.toString());
        updateInteractiveToggleLabel();

        // Configure start/restart buttons for interactive tunnels
        if (isInteractive && apiConfig.ws_enabled) {
            // WebSocket available — buttons open terminal modal
            startBtn.disabled = false;
            restartBtn.disabled = false;
            startBtn.classList.remove('disabled-interactive');
            restartBtn.classList.remove('disabled-interactive');
            startBtn.classList.add('interactive-ws');
            restartBtn.classList.add('interactive-ws');
            startBtn.title = getTranslation('buttons.interactive_start_terminal', 'Start with Interactive Auth');
            restartBtn.title = getTranslation('buttons.interactive_restart_terminal', 'Restart with Interactive Auth');
        } else if (isInteractive) {
            // WebSocket not available — keep disabled with CLI hint
            startBtn.disabled = true;
            restartBtn.disabled = true;
            startBtn.classList.add('disabled-interactive');
            restartBtn.classList.add('disabled-interactive');
            startBtn.title = getTranslation('buttons.interactive_start_disabled', 'Interactive Auth Required - Use CLI');
            restartBtn.title = getTranslation('buttons.interactive_restart_disabled', 'Interactive Auth Required - Use CLI');
        } else {
            startBtn.disabled = false;
            restartBtn.disabled = false;
            startBtn.classList.remove('disabled-interactive');
            restartBtn.classList.remove('disabled-interactive');
            startBtn.classList.remove('interactive-ws');
            restartBtn.classList.remove('interactive-ws');
            startBtn.title = getTranslation('buttons.start_tunnel', 'Start tunnel');
            restartBtn.title = getTranslation('buttons.restart_tunnel', 'Restart tunnel');
        }

        updateStatusDisplay(tunnel.status || 'LOADING');
    }

    function updateStatusDisplay(status) {
        let statusColor = "var(--text-secondary)";
        let statusIcon = "help_outline";
        let statusText = status || 'Unknown';

        // Normalize status
        const normalizedStatus = (status || 'UNKNOWN').toUpperCase();

        switch (normalizedStatus) {
            case 'RUNNING':
            case 'NORMAL':
                statusIcon = "check_circle";
                statusColor = "var(--success)";
                statusText = getTranslation('table.status.running', 'Running');
                break;
            case 'STOPPED':
                statusIcon = "stop_circle";
                statusColor = "var(--text-secondary)";
                statusText = getTranslation('table.status.stopped', 'Stopped');
                break;
            case 'STARTING':
                statusIcon = "hourglass_empty";
                statusColor = "var(--warning)";
                statusText = getTranslation('table.status.starting', 'Starting');
                break;
            case 'DEAD':
                statusIcon = "cancel";
                statusColor = "var(--error)";
                statusText = getTranslation('table.status.dead', 'Dead');
                break;
            case 'LOADING':
                statusIcon = "hourglass_empty";
                statusColor = "var(--warning)";
                statusText = getTranslation('table.status.loading', 'Loading...');
                break;
            case 'SAVING':
                statusIcon = "hourglass_empty";
                statusColor = "var(--accent)";
                statusText = getTranslation('table.status.saving', 'Saving...');
                break;
        }

        statusValue.innerHTML = `
            <div style="display: flex; align-items: center;">
                <i class="material-icons" style="color: ${statusColor}; margin-right: 8px;">${statusIcon}</i>
                <span style="color: ${statusColor}; font-weight: 500;">${statusText}</span>
            </div>
        `;
    }

    // Handle save configuration
    async function handleSaveConfig() {
        // Collect form data
        const tunnelData = {
            name: tunnelNameInput.value.trim(),
            remote_host: remoteHostInput.value.trim(),
            remote_port: remotePortInput.value.trim(),
            local_port: localPortInput.value.trim(),
            interactive: interactiveToggle.getAttribute('data-interactive') === 'true',
            direction: directionSelect.value,
        };

        // Validate required fields
        if (!tunnelData.name || !tunnelData.remote_host || !tunnelData.remote_port || !tunnelData.local_port) {
            const errorMsg = window.i18n ? window.i18n.t('messages.validation_errors') : 'Please fill in all required fields';
            showMessage(errorMsg, 'error');
            return;
        }

        // Validate inputs
        let hasErrors = false;
        [tunnelNameInput, remoteHostInput, remotePortInput, localPortInput].forEach(input => {
            validateInput({ target: input });
            if (input.classList.contains('error')) {
                hasErrors = true;
            }
        });

        if (hasErrors) {
            const errorMsg = window.i18n ? window.i18n.t('messages.validation_errors') : 'Please fix validation errors before saving';
            showMessage(errorMsg, 'error');
            return;
        }

        // Disable buttons during save
        setAllButtonsEnabled(false);
        updateStatusDisplay('SAVING');

        try {
            // Update existing tunnel via Config API
            const response = await apiCall(`/config/${currentHash}`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(tunnelData),
            });

            if (!response.ok) {
                const errorData = await response.text();
                throw new Error(`Save failed: ${response.status} - ${errorData}`);
            }

            // Get the new hash from response
            const responseData = await response.json();
            const newHash = responseData.hash || currentHash;

            // Update current hash and URL if changed
            if (newHash !== currentHash) {
                currentHash = newHash;
                const hashTextEl = tunnelHashEl.querySelector('.hash-text');
                if (hashTextEl) {
                    hashTextEl.textContent = newHash;
                }
                // Update URL without reload
                const newUrl = new URL(window.location);
                newUrl.searchParams.set('hash', newHash);
                window.history.replaceState({}, '', newUrl);
            }

            const successMsg = window.i18n ? window.i18n.t('messages.config_saved') : 'Configuration saved successfully!';
            showMessage(successMsg, 'success');

            // Wait for file monitor to detect changes and complete smart restart
            // Then refresh status
            setTimeout(async () => {
                await refreshTunnelStatus();
            }, 3000);

        } catch (error) {
            console.error('Error saving tunnel:', error);
            const errorMsg = window.i18n ? window.i18n.t('messages.config_save_failed') : 'Failed to save configuration';
            showMessage(errorMsg, 'error');
            updateStatusDisplay(currentTunnel?.status || 'STOPPED');
        } finally {
            setAllButtonsEnabled(true);
        }
    }

    // Add input validation
    function addInputValidation() {
        const inputs = [tunnelNameInput, remoteHostInput, remotePortInput, localPortInput];
        inputs.forEach(input => {
            input.addEventListener('blur', validateInput);
            input.addEventListener('input', clearValidationError);
        });
    }

    // Validate individual input
    function validateInput(event) {
        const input = event.target;
        const value = input.value.trim();

        // Remove existing error styling
        input.classList.remove('error');

        // Validate based on input id
        if (input.id === 'remotePort') {
            // Validate remote_port which can be "port" or "hostname:port" format
            if (value) {
                const portPattern = /^[\w.-]+:\d{1,5}$|^\d{1,5}$/;
                if (!portPattern.test(value)) {
                    input.classList.add('error');
                    const errorMsg = window.i18n ? window.i18n.t('validation.remote_port_format') : 'Invalid port format. Use "port" or "hostname:port"';
                    input.title = errorMsg;
                }
            }
        } else if (input.id === 'localPort') {
            // Validate local_port which can be "port" or "ip:port" format
            if (value) {
                const portPattern = /^(\d{1,3}\.){3}\d{1,3}:\d{1,5}$|^\d{1,5}$/;
                if (!portPattern.test(value)) {
                    input.classList.add('error');
                    const errorMsg = window.i18n ? window.i18n.t('validation.local_port_format') : 'Invalid port format. Use "port" or "ip:port"';
                    input.title = errorMsg;
                }
            }
        }
    }

    // Clear validation error styling
    function clearValidationError(event) {
        event.target.classList.remove('error');
        event.target.title = '';
    }

    async function handleControl(action) {
        // Check if this is an interactive tunnel
        const isInteractive = currentTunnel?.interactive || false;

        // For interactive tunnels, open terminal modal or show CLI hint
        if (isInteractive && (action === 'start' || action === 'restart')) {
            if (terminalModal && apiConfig.ws_enabled) {
                // For restart, stop the tunnel first
                if (action === 'restart') {
                    setAllButtonsEnabled(false);
                    try {
                        const stopResponse = await apiCall(`/stop/${currentHash}`, { method: 'POST' });
                        if (!stopResponse.ok) {
                            showMessage(getTranslation('messages.stop_failed', 'Failed to stop tunnel'), 'error');
                            setAllButtonsEnabled(true);
                            return;
                        }
                        await new Promise(resolve => setTimeout(resolve, 1000));
                    } catch (error) {
                        showMessage(getTranslation('messages.stop_failed', 'Failed to stop tunnel'), 'error');
                        setAllButtonsEnabled(true);
                        return;
                    }
                    setAllButtonsEnabled(true);
                }
                const tunnelName = currentTunnel?.name || currentHash.substring(0, 8);
                terminalModal.open(currentHash, tunnelName);
            } else {
                // Fallback: show CLI hint
                const hintKey = action === 'start' ? 'messages.interactive_start_hint' : 'messages.interactive_restart_hint';
                const defaultHint = 'This tunnel requires interactive authentication. Please use CLI:\ndocker compose exec -it -u myuser autossh autossh-cli auth ' + currentHash;
                let hintMsg = window.i18n ? window.i18n.t(hintKey) : defaultHint;
                hintMsg = hintMsg.replace('{hash}', currentHash.substring(0, 8));
                showMessage(hintMsg, 'info');
            }
            return;
        }

        const confirmMessages = {
            restart: window.i18n ? window.i18n.t('messages.confirm_restart') : 'Are you sure you want to restart this tunnel?',
            stop: window.i18n ? window.i18n.t('messages.confirm_stop') : 'Are you sure you want to stop this tunnel?'
        };

        if (confirmMessages[action] && !confirm(confirmMessages[action])) {
            return;
        }

        // Disable all buttons during operation
        setAllButtonsEnabled(false);

        try {
            let method = 'POST';

            if (action === 'restart') {
                // Stop first
                const stopResponse = await apiCall(`/stop/${currentHash}`, { method });
                if (!stopResponse.ok) throw new Error('Failed to stop tunnel');

                // Wait a bit
                await new Promise(resolve => setTimeout(resolve, 1000));

                // Then start
                const startResponse = await apiCall(`/start/${currentHash}`, { method });
                if (!startResponse.ok) throw new Error('Failed to start tunnel');
            } else {
                const response = await apiCall(`/${action}/${currentHash}`, { method });
                if (!response.ok) throw new Error(`Failed to ${action} tunnel`);
            }

            const successMsg = window.i18n ? window.i18n.t(`messages.${action}_success`) : `Tunnel ${action}ed successfully`;
            showMessage(successMsg, 'success');

            // Reload details after a short delay
            setTimeout(() => {
                refreshTunnelStatus();
                loadLogs();
            }, 1500);

        } catch (error) {
            console.error(`Error ${action}ing tunnel:`, error);
            const failMsg = window.i18n ? window.i18n.t(`messages.${action}_failed`) : `Failed to ${action} tunnel`;
            showMessage(`${failMsg}: ${error.message}`, 'error');
        } finally {
            setAllButtonsEnabled(true);
        }
    }

    function setAllButtonsEnabled(enabled) {
        startBtn.disabled = !enabled;
        restartBtn.disabled = !enabled;
        stopBtn.disabled = !enabled;
        saveConfigBtn.disabled = !enabled;
    }

    async function loadLogs(retryCount = 0) {
        try {
            // Call the API endpoint directly
            const response = await apiCall(`/logs/${currentHash}`);

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

    // Get or create toast container
    function getToastContainer() {
        let container = document.querySelector('.toast-container');
        if (!container) {
            container = document.createElement('div');
            container.className = 'toast-container';
            document.body.appendChild(container);
        }
        return container;
    }

    // Show success/error messages as floating toast
    function showMessage(text, type = 'success') {
        const container = getToastContainer();

        const message = document.createElement('div');
        message.className = `message ${type}`;

        // Create message content wrapper
        const contentWrapper = document.createElement('div');
        contentWrapper.className = 'message-content';

        // Create message text
        const textSpan = document.createElement('span');
        textSpan.textContent = text;
        contentWrapper.appendChild(textSpan);

        // Add click hint for copyable messages
        const hintText = getTranslation('messages.click_to_copy', 'Click to copy');
        const hint = document.createElement('div');
        hint.className = 'message-hint';
        hint.textContent = hintText;
        contentWrapper.appendChild(hint);

        // Create action buttons container
        const actions = document.createElement('div');
        actions.className = 'message-actions';

        // Create copy button
        const copyBtn = document.createElement('button');
        copyBtn.className = 'message-copy';
        copyBtn.innerHTML = '<i class="material-icons" style="font-size: 16px;">content_copy</i>';
        copyBtn.setAttribute('aria-label', 'Copy');
        copyBtn.addEventListener('click', (e) => {
            e.stopPropagation();
            copyToClipboard(text, copyBtn);
        });

        // Create close button
        const closeBtn = document.createElement('button');
        closeBtn.className = 'message-close';
        closeBtn.innerHTML = '×';
        closeBtn.setAttribute('aria-label', 'Close');
        closeBtn.addEventListener('click', (e) => {
            e.stopPropagation();
            dismissToast(message);
        });

        actions.appendChild(copyBtn);
        actions.appendChild(closeBtn);

        message.appendChild(contentWrapper);
        message.appendChild(actions);

        // Add click to copy on the whole message
        message.addEventListener('click', () => {
            copyToClipboard(text, copyBtn);
        });

        container.appendChild(message);

        // Auto-remove after 5 seconds
        const autoRemoveTimeout = setTimeout(() => {
            dismissToast(message);
        }, 5000);

        // Store timeout reference for cleanup
        message._autoRemoveTimeout = autoRemoveTimeout;
    }

    // Copy text to clipboard
    async function copyToClipboard(text, button) {
        try {
            await navigator.clipboard.writeText(text);

            // Visual feedback
            if (button) {
                button.classList.add('copied');
                const icon = button.querySelector('.material-icons');
                if (icon) {
                    icon.textContent = 'check';
                }

                // Reset after 2 seconds
                setTimeout(() => {
                    button.classList.remove('copied');
                    if (icon) {
                        icon.textContent = 'content_copy';
                    }
                }, 2000);
            }
        } catch (error) {
            console.error('Failed to copy:', error);
        }
    }

    // Dismiss toast with animation
    function dismissToast(message) {
        if (!message || !message.parentNode) return;

        // Clear auto-remove timeout if exists
        if (message._autoRemoveTimeout) {
            clearTimeout(message._autoRemoveTimeout);
        }

        // Add hiding class for animation
        message.classList.add('hiding');

        // Remove after animation completes
        setTimeout(() => {
            if (message.parentNode) {
                message.remove();
            }
        }, 300);
    }

    function showError(text) {
        const container = document.querySelector('.container');
        container.innerHTML = `
            <div class="card">
                <div class="card-content" style="text-align: center; padding: 40px;">
                    <i class="material-icons" style="font-size: 64px; color: var(--error);">error</i>
                    <h2 style="margin-top: 16px; color: var(--error);">${text}</h2>
                    <a href="/" class="btn btn-primary" style="margin-top: 24px; display: inline-flex;">
                        Back to Home
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

    // Handle copy hash to clipboard
    async function handleCopyHash() {
        const hashTextEl = tunnelHashEl.querySelector('.hash-text');
        const hashValue = hashTextEl ? hashTextEl.textContent : currentHash;

        if (!hashValue || hashValue === '-') {
            return;
        }

        try {
            await navigator.clipboard.writeText(hashValue);

            // Visual feedback
            copyHashBtn.classList.add('copied');
            const icon = copyHashBtn.querySelector('.material-icons');
            const originalIcon = icon.textContent;
            icon.textContent = 'check';

            // Reset after 2 seconds
            setTimeout(() => {
                copyHashBtn.classList.remove('copied');
                icon.textContent = originalIcon;
            }, 2000);

            // Show success message
            const successMsg = getTranslation('messages.hash_copied', 'Hash copied to clipboard');
            showMessage(successMsg, 'success');
        } catch (error) {
            console.error('Failed to copy hash:', error);
            const errorMsg = getTranslation('messages.copy_failed', 'Failed to copy to clipboard');
            showMessage(errorMsg, 'error');
        }
    }
});
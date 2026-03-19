document.addEventListener("DOMContentLoaded", () => {
    const tableBody = document.querySelector("#tunnelTable tbody");
    let apiConfig = { base_url: '', api_key: '' };
    let autoRefreshInterval = null;
    const AUTO_REFRESH_INTERVAL = 5000; // 5 seconds
    let isConfigSaving = false; // Flag to prevent clicks during save/reload

    // Load API config first, then load configuration
    loadAPIConfig().then(() => {
        loadConfiguration();
        // Start auto-refresh by default after initial load
        startAutoRefresh();
    });

    // Listen for i18n ready event to update translations
    window.addEventListener('i18nReady', () => {
        updateAllRowTranslations();
    });

    // Listen for language change event to update translations
    window.addEventListener('languageChanged', () => {
        updateAllRowTranslations();
    });

    // Helper function to get translation with fallback
    function getTranslation(key, fallback) {
        if (window.i18n && window.i18n.isReady) {
            return window.i18n.t(key);
        }
        return fallback;
    }

    // Update translations for all existing rows
    function updateAllRowTranslations() {
        const rows = tableBody.querySelectorAll('tr');
        rows.forEach(row => {
            // Update control button titles
            const saveRowBtn = row.querySelector('.save-row-button');
            const startBtn = row.querySelector('.start-button');
            const restartBtn = row.querySelector('.restart-button');
            const stopBtn = row.querySelector('.stop-button');

            if (saveRowBtn) saveRowBtn.title = getTranslation('buttons.save_restart_row', 'Save & Restart');
            if (startBtn) {
                if (startBtn.classList.contains('disabled-interactive')) {
                    startBtn.title = getTranslation('buttons.interactive_start_disabled', 'Interactive Auth Required - Use CLI');
                } else {
                    startBtn.title = getTranslation('buttons.start_tunnel', 'Start tunnel');
                }
            }
            if (restartBtn) {
                if (restartBtn.classList.contains('disabled-interactive')) {
                    restartBtn.title = getTranslation('buttons.interactive_restart_disabled', 'Interactive Auth Required - Use CLI');
                } else {
                    restartBtn.title = getTranslation('buttons.restart_tunnel', 'Restart tunnel');
                }
            }
            if (stopBtn) stopBtn.title = getTranslation('buttons.stop_tunnel', 'Stop tunnel');

            // Update input placeholders
            const inputs = row.querySelectorAll('input[data-i18n-placeholder]');
            inputs.forEach(input => {
                const key = input.getAttribute('data-i18n-placeholder');
                if (key && window.i18n && window.i18n.isReady) {
                    input.placeholder = window.i18n.t(key);
                }
            });

            // Update select options
            const options = row.querySelectorAll('option[data-i18n]');
            options.forEach(option => {
                const key = option.getAttribute('data-i18n');
                if (key && window.i18n && window.i18n.isReady) {
                    option.textContent = window.i18n.t(key);
                }
            });

            // Update interactive toggle button title
            const interactiveToggle = row.querySelector('.interactive-toggle-button');
            if (interactiveToggle) {
                const isActive = interactiveToggle.classList.contains('active');
                const enabledText = getTranslation('buttons.interactive_auth_enabled', 'Interactive Auth Enabled');
                const disabledText = getTranslation('buttons.interactive_auth_disabled', 'Interactive Auth Disabled');
                interactiveToggle.title = isActive ? enabledText : disabledText;
            }

            // Update delete button title
            const deleteBtn = row.querySelector('.delete-button');
            if (deleteBtn) {
                deleteBtn.title = getTranslation('buttons.delete', 'Delete tunnel');
            }
        });
    }

    // Setup refresh button and auto-refresh checkbox
    setupRefreshControls();

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

    // Fetch tunnel statuses from API server
    async function fetchTunnelStatuses() {
        if (!apiConfig.base_url) return {};

        try {
            const response = await apiCall('/status');
            if (!response.ok) return {};

            const statuses = await response.json();
            const statusMap = {};
            statuses.forEach(s => {
                if (s.hash) {
                    statusMap[s.hash] = s.status;
                }
            });
            return statusMap;
        } catch (error) {
            console.warn('Failed to fetch tunnel statuses:', error);
            return {};
        }
    }

    // Load configuration from autossh API server
    async function loadConfiguration() {
        if (!isConfigSaving) {
            showLoading(true);
        }
        try {
            if (!apiConfig.base_url) {
                throw new Error('API server not configured');
            }

            const response = await apiCall('/config');
            if (!response.ok) {
                throw new Error(`HTTP error! status: ${response.status}`);
            }
            const data = await response.json();

            // Clear existing rows before adding new ones
            tableBody.innerHTML = '';
            if (data.tunnels && Array.isArray(data.tunnels)) {
                data.tunnels.forEach((tunnel) => {
                    tunnel.status = 'LOADING';
                    addRow(tunnel);
                });

                // Fetch statuses asynchronously after rendering
                refreshStatuses();
            } else {
                const warningMsg = window.i18n ? window.i18n.t('messages.no_tunnels') : 'No tunnels found in configuration';
                console.warn(warningMsg);
            }
        } catch (error) {
            console.error("Error loading configuration:", error);
            const errorMsg = window.i18n ? window.i18n.t('messages.config_load_failed') : 'Failed to load configuration';
            showMessage(errorMsg, "error");
        } finally {
            if (!isConfigSaving) {
                showLoading(false);
            }
        }
    }

    // Add row function
    function addRow(tunnel = { name: "", remote_host: "", remote_port: "", local_port: "", interactive: false, direction: "remote_to_local", status: "STOPPED" }) {
        const row = document.createElement("tr");
        row.className = "new-row";

        let statusColor = "grey";
        let statusIcon = "radio_button_unchecked";
        let statusTooltip = tunnel.status || "STOPPED";

        switch (tunnel.status) {
            case "RUNNING":
            case "NORMAL":
                statusIcon = "check_circle";
                statusColor = "var(--success)";
                statusTooltip = "Running";
                break;
            case "DEAD":
                statusIcon = "cancel";
                statusColor = "var(--error)";
                statusTooltip = "Dead";
                break;
            case "STARTING":
                statusIcon = "hourglass_empty";
                statusColor = "var(--warning)";
                statusTooltip = "Starting";
                break;
            case "STOPPED":
                statusIcon = "stop_circle";
                statusColor = "var(--text-secondary)";
                statusTooltip = "Stopped";
                break;
            case "LOADING":
                statusIcon = "hourglass_empty";
                statusColor = "var(--warning)";
                statusTooltip = "Loading...";
                break;
            case "N/A":
            default:
                statusIcon = "help_outline";
                statusColor = "var(--text-secondary)";
                statusTooltip = "Unknown";
                break;
        }

        const tunnelHash = tunnel.hash || '';

        const tunnelNamePlaceholder = getTranslation('table.placeholders.tunnel_name', 'Tunnel name');
        const remoteHostPlaceholder = getTranslation('table.placeholders.remote_host', 'Remote host');
        const remotePortPlaceholder = getTranslation('table.placeholders.remote_port', 'Remote port (e.g., 44497 or hostname:44497)');
        const localPortPlaceholder = getTranslation('table.placeholders.local_port', 'Local port (e.g., 55001 or 192.168.1.100:55001)');

        const remoteToLocalText = getTranslation('table.direction.remote_to_local', 'Remote to Local');
        const localToRemoteText = getTranslation('table.direction.local_to_remote', 'Local to Remote');

        const interactiveEnabledText = getTranslation('buttons.interactive_auth_enabled', 'Interactive Auth Enabled');
        const interactiveDisabledText = getTranslation('buttons.interactive_auth_disabled', 'Interactive Auth Disabled');
        const deleteTunnelText = getTranslation('buttons.delete', 'Delete tunnel');

        const saveRestartText = getTranslation('buttons.save_restart_row', 'Save & Restart');
        const startTunnelText = getTranslation('buttons.start_tunnel', 'Start tunnel');
        const restartTunnelText = getTranslation('buttons.restart_tunnel', 'Restart tunnel');
        const stopTunnelText = getTranslation('buttons.stop_tunnel', 'Stop tunnel');

        row.innerHTML = `
            <td>
                <div class="control-buttons-cell">
                    <button class="control-button save-row-button" data-hash="${tunnelHash}" title="${saveRestartText}" data-i18n-title="buttons.save_restart_row">
                        <i class="material-icons">save</i>
                    </button>
                    <button class="control-button start-button" data-hash="${tunnelHash}" title="${startTunnelText}" data-i18n-title="buttons.start_tunnel">
                        <i class="material-icons">play_arrow</i>
                    </button>
                    <button class="control-button restart-button" data-hash="${tunnelHash}" title="${restartTunnelText}" data-i18n-title="buttons.restart_tunnel">
                        <i class="material-icons">refresh</i>
                    </button>
                    <button class="control-button stop-button" data-hash="${tunnelHash}" title="${stopTunnelText}" data-i18n-title="buttons.stop_tunnel">
                        <i class="material-icons">stop</i>
                    </button>
                </div>
            </td>
            <td>
                <input type="text" class="table-input" value="${escapeHtml(tunnel.name || "")}" placeholder="${tunnelNamePlaceholder}" data-i18n-placeholder="table.placeholders.tunnel_name">
            </td>
            <td>
                <i class="material-icons status-indicator" data-hash="${tunnelHash}" style="color: ${statusColor}; font-size: 20px; vertical-align: middle; cursor: pointer;" title="${statusTooltip}">${statusIcon}</i>
            </td>
            <td>
                <input type="text" class="table-input" value="${escapeHtml(tunnel.remote_host || "")}" placeholder="${remoteHostPlaceholder}" data-i18n-placeholder="table.placeholders.remote_host">
            </td>
            <td>
                <input type="text" class="table-input remote-port-input" value="${escapeHtml(tunnel.remote_port || "")}" placeholder="${remotePortPlaceholder}" data-i18n-placeholder="table.placeholders.remote_port">
            </td>
            <td>
                <input type="text" class="table-input" value="${escapeHtml(tunnel.local_port || "")}" placeholder="${localPortPlaceholder}" data-i18n-placeholder="table.placeholders.local_port">
            </td>
            <td>
                <select class="table-select">
                    <option value="remote_to_local" ${tunnel.direction === "remote_to_local" ? "selected" : ""} data-i18n="table.direction.remote_to_local">${remoteToLocalText}</option>
                    <option value="local_to_remote" ${tunnel.direction === "local_to_remote" ? "selected" : ""} data-i18n="table.direction.local_to_remote">${localToRemoteText}</option>
                </select>
            </td>
            <td>
                <div class="action-buttons-cell">
                    <button class="interactive-toggle-button ${tunnel.interactive ? 'active' : ''}" title="${tunnel.interactive ? interactiveEnabledText : interactiveDisabledText}" data-interactive="${tunnel.interactive ? 'true' : 'false'}">
                        <i class="material-icons">fingerprint</i>
                    </button>
                    <button class="delete-button deleteRow" title="${deleteTunnelText}" data-i18n-title="buttons.delete">
                        <i class="material-icons">delete</i>
                    </button>
                </div>
            </td>
        `;

        tableBody.appendChild(row);

        // Add delete row event with confirmation
        row.querySelector(".deleteRow").addEventListener("click", async () => {
            const confirmMessage = window.i18n ? window.i18n.t('messages.delete_confirm') : 'Are you sure you want to delete this tunnel configuration?';
            if (!confirm(confirmMessage)) {
                return;
            }

            if (tunnelHash) {
                try {
                    const response = await apiCall(`/config/${tunnelHash}/delete`, { method: 'POST' });
                    if (!response.ok) {
                        const errorData = await response.text();
                        throw new Error(`Delete failed: ${response.status} - ${errorData}`);
                    }
                    const successMsg = window.i18n ? window.i18n.t('messages.delete_success') : 'Tunnel deleted successfully';
                    showMessage(successMsg, 'success');
                    setTimeout(() => loadConfiguration(), 500);
                } catch (error) {
                    console.error('Error deleting tunnel:', error);
                    const errorMsg = window.i18n ? window.i18n.t('messages.delete_failed') : 'Failed to delete tunnel';
                    showMessage(errorMsg, 'error');
                }
            } else {
                row.style.animation = "fadeOut 0.3s ease-out";
                setTimeout(() => row.remove(), 300);
            }
        });

        // Add interactive toggle event
        const interactiveToggle = row.querySelector(".interactive-toggle-button");
        interactiveToggle.addEventListener("click", () => {
            const isActive = interactiveToggle.classList.contains('active');
            const newState = !isActive;

            interactiveToggle.classList.toggle('active', newState);
            interactiveToggle.setAttribute('data-interactive', newState.toString());

            const enabledText = getTranslation('buttons.interactive_auth_enabled', 'Interactive Auth Enabled');
            const disabledText = getTranslation('buttons.interactive_auth_disabled', 'Interactive Auth Disabled');
            interactiveToggle.title = newState ? enabledText : disabledText;
        });

        // Add control button events
        const saveRowButton = row.querySelector(".save-row-button");
        const startButton = row.querySelector(".start-button");
        const restartButton = row.querySelector(".restart-button");
        const stopButton = row.querySelector(".stop-button");

        const isInteractive = tunnel.interactive || false;

        if (isInteractive) {
            startButton.disabled = true;
            restartButton.disabled = true;
            startButton.classList.add('disabled-interactive');
            restartButton.classList.add('disabled-interactive');
            startButton.title = getTranslation('buttons.interactive_start_disabled', 'Interactive Auth Required - Use CLI');
            restartButton.title = getTranslation('buttons.interactive_restart_disabled', 'Interactive Auth Required - Use CLI');
        }

        saveRowButton.addEventListener("click", () => handleSaveRow(tunnelHash, row));
        startButton.addEventListener("click", () => handleTunnelControl('start', tunnelHash, row, isInteractive));
        restartButton.addEventListener("click", () => handleTunnelControl('restart', tunnelHash, row, isInteractive));
        stopButton.addEventListener("click", () => handleTunnelControl('stop', tunnelHash, row, isInteractive));

        // Add click event to status indicator
        const statusIndicator = row.querySelector(".status-indicator");
        if (statusIndicator && tunnelHash) {
            statusIndicator.addEventListener("click", () => {
                if (isConfigSaving) {
                    const waitMsg = window.i18n ? window.i18n.t('messages.please_wait') : 'Please wait for configuration to reload...';
                    showMessage(waitMsg, 'info');
                    return;
                }
                window.location.href = `/tunnel-detail?hash=${tunnelHash}`;
            });
            statusIndicator.style.transition = "transform 0.2s ease";
            statusIndicator.addEventListener("mouseenter", () => {
                statusIndicator.style.transform = "scale(1.2)";
            });
            statusIndicator.addEventListener("mouseleave", () => {
                statusIndicator.style.transform = "scale(1)";
            });
        }

        // Add input validation
        addInputValidation(row);

        // Remove animation class after animation completes
        setTimeout(() => row.classList.remove("new-row"), 300);
    }

    // Handle save single row
    async function handleSaveRow(hash, row) {
        const cells = row.cells;
        const interactiveToggle = cells[7].querySelector(".interactive-toggle-button");

        const tunnelData = {
            name: cells[1].querySelector("input").value.trim(),
            remote_host: cells[3].querySelector("input").value.trim(),
            remote_port: cells[4].querySelector("input").value.trim(),
            local_port: cells[5].querySelector("input").value.trim(),
            interactive: interactiveToggle.getAttribute('data-interactive') === 'true',
            direction: cells[6].querySelector("select").value,
        };

        if (!tunnelData.name || !tunnelData.remote_host || !tunnelData.remote_port || !tunnelData.local_port) {
            const errorMsg = window.i18n ? window.i18n.t('messages.validation_errors') : 'Please fill in all required fields';
            showMessage(errorMsg, 'error');
            return;
        }

        let hasErrors = false;
        const inputs = row.querySelectorAll('input');
        inputs.forEach(input => {
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

        if (!apiConfig.base_url) {
            const errorMsg = window.i18n ? window.i18n.t('messages.api_not_configured') : 'API server not configured';
            showMessage(errorMsg, 'error');
            return;
        }

        const controlButtons = row.querySelectorAll('.control-button');
        controlButtons.forEach(btn => btn.disabled = true);

        const statusIndicator = row.querySelector('.status-indicator');
        if (statusIndicator) {
            statusIndicator.textContent = 'hourglass_empty';
            statusIndicator.style.color = 'var(--warning)';
            statusIndicator.title = 'Saving...';
        }

        try {
            let response;
            if (hash) {
                response = await apiCall(`/config/${hash}`, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify(tunnelData),
                });
            } else {
                response = await apiCall('/config/new', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify(tunnelData),
                });
            }

            if (!response.ok) {
                const errorData = await response.text();
                throw new Error(`Save failed: ${response.status} - ${errorData}`);
            }

            const responseData = await response.json();
            const newHash = responseData.hash || hash;

            controlButtons.forEach(btn => btn.disabled = false);
            updateRowHash(row, newHash);

            const successMsg = window.i18n ? window.i18n.t('messages.config_saved') : 'Configuration saved successfully!';
            showMessage(successMsg, 'success');

            setTimeout(async () => {
                await refreshRowStatus(row, newHash);
            }, 3000);

        } catch (error) {
            console.error('Error saving tunnel:', error);
            const errorMsg = window.i18n ? window.i18n.t('messages.config_save_failed') : 'Failed to save configuration';
            showMessage(errorMsg, 'error');
            if (statusIndicator) {
                updateStatusIndicator(statusIndicator, 'STOPPED');
            }
            controlButtons.forEach(btn => btn.disabled = false);
        }
    }

    // Update a row's hash references after save
    function updateRowHash(row, newHash) {
        const statusIndicator = row.querySelector('.status-indicator');
        if (statusIndicator) {
            statusIndicator.dataset.hash = newHash;
        }

        const controlButtons = row.querySelectorAll('.control-button');
        controlButtons.forEach(btn => {
            btn.dataset.hash = newHash;
        });

        const saveRowButton = row.querySelector(".save-row-button");
        const startButton = row.querySelector(".start-button");
        const restartButton = row.querySelector(".restart-button");
        const stopButton = row.querySelector(".stop-button");

        const newSaveBtn = saveRowButton.cloneNode(true);
        const newStartBtn = startButton.cloneNode(true);
        const newRestartBtn = restartButton.cloneNode(true);
        const newStopBtn = stopButton.cloneNode(true);

        saveRowButton.parentNode.replaceChild(newSaveBtn, saveRowButton);
        startButton.parentNode.replaceChild(newStartBtn, startButton);
        restartButton.parentNode.replaceChild(newRestartBtn, restartButton);
        stopButton.parentNode.replaceChild(newStopBtn, stopButton);

        newSaveBtn.addEventListener("click", () => handleSaveRow(newHash, row));
        newStartBtn.addEventListener("click", () => handleTunnelControl('start', newHash, row));
        newRestartBtn.addEventListener("click", () => handleTunnelControl('restart', newHash, row));
        newStopBtn.addEventListener("click", () => handleTunnelControl('stop', newHash, row));

        if (statusIndicator && newHash) {
            const newStatusIndicator = statusIndicator.cloneNode(true);
            newStatusIndicator.dataset.hash = newHash;
            statusIndicator.parentNode.replaceChild(newStatusIndicator, statusIndicator);

            newStatusIndicator.addEventListener("click", () => {
                if (isConfigSaving) {
                    const waitMsg = window.i18n ? window.i18n.t('messages.please_wait') : 'Please wait for configuration to reload...';
                    showMessage(waitMsg, 'info');
                    return;
                }
                window.location.href = `/tunnel-detail?hash=${newHash}`;
            });

            newStatusIndicator.style.transition = "transform 0.2s ease";
            newStatusIndicator.addEventListener("mouseenter", () => {
                newStatusIndicator.style.transform = "scale(1.2)";
            });
            newStatusIndicator.addEventListener("mouseleave", () => {
                newStatusIndicator.style.transform = "scale(1)";
            });
        }
    }

    // Refresh status for a single row
    async function refreshRowStatus(row, hash) {
        const statuses = await fetchTunnelStatuses();
        const statusIndicator = row.querySelector('.status-indicator');

        if (statusIndicator) {
            const status = (hash && statuses[hash]) ? statuses[hash] : 'STOPPED';
            updateStatusIndicator(statusIndicator, status);
        }
    }

    // Handle tunnel control actions
    async function handleTunnelControl(action, hash, row, isInteractive = false) {
        if (!hash) {
            const errorMsg = window.i18n ? window.i18n.t('messages.save_first') : 'Please save the configuration first';
            showMessage(errorMsg, 'error');
            return;
        }

        if (isInteractive && (action === 'start' || action === 'restart')) {
            const hintKey = action === 'start' ? 'messages.interactive_start_hint' : 'messages.interactive_restart_hint';
            const defaultHint = action === 'start'
                ? 'This tunnel requires interactive authentication. Please start it via terminal:\ndocker compose exec -it -u myuser autossh autossh-cli auth ' + hash
                : 'This tunnel requires interactive authentication. Please stop it first, then start via terminal:\ndocker compose exec -it -u myuser autossh autossh-cli auth ' + hash;
            let hintMsg = window.i18n ? window.i18n.t(hintKey) : defaultHint;
            hintMsg = hintMsg.replace('{hash}', hash.substring(0, 8));
            showMessage(hintMsg, 'info');
            return;
        }

        const confirmMsg = window.i18n ? window.i18n.t(`messages.confirm_${action}`) : `Are you sure you want to ${action} this tunnel?`;

        if ((action === 'restart' || action === 'stop') && !confirm(confirmMsg)) {
            return;
        }

        const controlButtons = row.querySelectorAll('.control-button');
        controlButtons.forEach(btn => btn.disabled = true);

        try {
            if (!apiConfig.base_url) {
                throw new Error('API server not configured');
            }

            if (action === 'restart') {
                const stopResponse = await apiCall(`/stop/${hash}`, { method: 'POST' });
                if (!stopResponse.ok) {
                    const stopData = await stopResponse.text();
                    throw new Error(`Stop failed: ${stopResponse.status} - ${stopData}`);
                }

                await new Promise(resolve => setTimeout(resolve, 1000));

                const startResponse = await apiCall(`/start/${hash}`, { method: 'POST' });
                if (!startResponse.ok) {
                    const startData = await startResponse.text();
                    throw new Error(`Start failed: ${startResponse.status} - ${startData}`);
                }
            } else {
                const response = await apiCall(`/${action}/${hash}`, { method: 'POST' });
                if (!response.ok) {
                    const responseData = await response.text();
                    throw new Error(`${action} failed: ${response.status} - ${responseData}`);
                }
            }

            const successMsg = window.i18n ? window.i18n.t(`messages.${action}_success`) : `Tunnel ${action}ed successfully`;
            showMessage(successMsg, 'success');

            setTimeout(() => loadConfiguration(), 1500);

        } catch (error) {
            console.error(`Error ${action}ing tunnel:`, error);
            const errorMsg = window.i18n ? window.i18n.t(`messages.${action}_failed`) : `Failed to ${action} tunnel: ${error.message}`;
            showMessage(errorMsg, 'error');
        } finally {
            controlButtons.forEach(btn => btn.disabled = false);
        }
    }

    // Add input validation
    function addInputValidation(row) {
        const inputs = row.querySelectorAll('input, textarea');
        inputs.forEach(input => {
            input.addEventListener('blur', validateInput);
            input.addEventListener('input', clearValidationError);
        });
    }

    // Validate individual input
    function validateInput(event) {
        const input = event.target;
        const value = input.value.trim();

        input.classList.remove('error');

        if (input.type === 'number') {
            const num = parseInt(value);
            if (value && (isNaN(num) || num < 1 || num > 65535)) {
                input.classList.add('error');
                const errorMsg = window.i18n ? window.i18n.t('validation.port_range') : 'Port must be between 1 and 65535';
                input.title = errorMsg;
            }
        } else if (input.classList.contains('remote-port-input') || input.placeholder && input.placeholder.includes('Remote port')) {
            if (value) {
                const portPattern = /^[\w.-]+:\d{1,5}$|^\d{1,5}$/;
                if (!portPattern.test(value)) {
                    input.classList.add('error');
                    const errorMsg = window.i18n ? window.i18n.t('validation.remote_port_format') : 'Invalid port format. Use "port" or "hostname:port"';
                    input.title = errorMsg;
                }
            }
        } else if (input.placeholder && input.placeholder.includes('Local port')) {
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

    // Escape HTML to prevent XSS
    function escapeHtml(text) {
        const div = document.createElement('div');
        div.textContent = text;
        return div.innerHTML;
    }

    // Show loading state
    function showLoading(show) {
        const container = document.querySelector('.container');
        let loadingEl = document.querySelector('.loading');

        if (show && !loadingEl) {
            loadingEl = document.createElement('div');
            loadingEl.className = 'loading';
            loadingEl.innerHTML = '<i class="material-icons" style="font-size:32px; animation: spin 1s linear infinite;">refresh</i>';
            container.appendChild(loadingEl);
        } else if (!show && loadingEl) {
            loadingEl.remove();
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

        const contentWrapper = document.createElement('div');
        contentWrapper.className = 'message-content';

        const textSpan = document.createElement('span');
        textSpan.textContent = text;
        contentWrapper.appendChild(textSpan);

        const hintText = getTranslation('messages.click_to_copy', 'Click to copy');
        const hint = document.createElement('div');
        hint.className = 'message-hint';
        hint.textContent = hintText;
        contentWrapper.appendChild(hint);

        const actions = document.createElement('div');
        actions.className = 'message-actions';

        const copyBtn = document.createElement('button');
        copyBtn.className = 'message-copy';
        copyBtn.innerHTML = '<i class="material-icons" style="font-size: 16px;">content_copy</i>';
        copyBtn.setAttribute('aria-label', 'Copy');
        copyBtn.addEventListener('click', (e) => {
            e.stopPropagation();
            copyToClipboard(text, copyBtn);
        });

        const closeBtn = document.createElement('button');
        closeBtn.className = 'message-close';
        closeBtn.innerHTML = '\u00d7';
        closeBtn.setAttribute('aria-label', 'Close');
        closeBtn.addEventListener('click', (e) => {
            e.stopPropagation();
            dismissToast(message);
        });

        actions.appendChild(copyBtn);
        actions.appendChild(closeBtn);

        message.appendChild(contentWrapper);
        message.appendChild(actions);

        message.addEventListener('click', () => {
            copyToClipboard(text, copyBtn);
        });

        container.appendChild(message);

        const autoRemoveTimeout = setTimeout(() => {
            dismissToast(message);
        }, 5000);

        message._autoRemoveTimeout = autoRemoveTimeout;
    }

    // Copy text to clipboard
    async function copyToClipboard(text, button) {
        try {
            await navigator.clipboard.writeText(text);

            if (button) {
                button.classList.add('copied');
                const icon = button.querySelector('.material-icons');
                if (icon) {
                    icon.textContent = 'check';
                }

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

        if (message._autoRemoveTimeout) {
            clearTimeout(message._autoRemoveTimeout);
        }

        message.classList.add('hiding');

        setTimeout(() => {
            if (message.parentNode) {
                message.remove();
            }
        }, 300);
    }

    // Setup refresh controls
    function setupRefreshControls() {
        const refreshBtn = document.getElementById('refreshStatus');
        const autoRefreshCheckbox = document.getElementById('autoRefresh');

        if (refreshBtn) {
            refreshBtn.addEventListener('click', () => {
                refreshStatuses();
            });
        }

        if (autoRefreshCheckbox) {
            // Set checkbox to checked by default
            autoRefreshCheckbox.checked = true;

            autoRefreshCheckbox.addEventListener('change', () => {
                if (autoRefreshCheckbox.checked) {
                    startAutoRefresh();
                } else {
                    stopAutoRefresh();
                }
            });
        }
    }

    // Refresh only statuses
    async function refreshStatuses(retryCount = 0) {
        const statuses = await fetchTunnelStatuses();

        if (Object.keys(statuses).length === 0) {
            if (retryCount < 5) {
                const delay = 500;
                setTimeout(() => refreshStatuses(retryCount + 1), delay);
            }
            return;
        }

        const rows = tableBody.querySelectorAll('tr');
        rows.forEach(row => {
            const statusIndicator = row.querySelector('.status-indicator');

            if (statusIndicator) {
                const hash = statusIndicator.dataset.hash;
                const status = (hash && statuses[hash]) ? statuses[hash] : 'STOPPED';
                updateStatusIndicator(statusIndicator, status);
            }
        });
    }

    // Update a single status indicator
    function updateStatusIndicator(indicator, status) {
        let statusColor = "var(--text-secondary)";
        let statusIcon = "help_outline";
        let statusTooltip = "Unknown";

        switch (status) {
            case "RUNNING":
            case "NORMAL":
                statusIcon = "check_circle";
                statusColor = "var(--success)";
                statusTooltip = "Running";
                break;
            case "DEAD":
                statusIcon = "cancel";
                statusColor = "var(--error)";
                statusTooltip = "Dead";
                break;
            case "STARTING":
                statusIcon = "hourglass_empty";
                statusColor = "var(--warning)";
                statusTooltip = "Starting";
                break;
            case "STOPPED":
                statusIcon = "stop_circle";
                statusColor = "var(--text-secondary)";
                statusTooltip = "Stopped";
                break;
        }

        indicator.textContent = statusIcon;
        indicator.style.color = statusColor;
        indicator.title = statusTooltip;
    }

    // Start auto-refresh
    function startAutoRefresh() {
        if (autoRefreshInterval) return;
        autoRefreshInterval = setInterval(() => {
            refreshStatuses();
        }, AUTO_REFRESH_INTERVAL);
    }

    // Stop auto-refresh
    function stopAutoRefresh() {
        if (autoRefreshInterval) {
            clearInterval(autoRefreshInterval);
            autoRefreshInterval = null;
        }
    }

    // Add new row button event
    document.getElementById("addRow").addEventListener("click", () => {
        addRow();
    });

    // Save config button event
    document.getElementById("saveConfig").addEventListener("click", async () => {
        const rows = Array.from(tableBody.rows);

        let hasErrors = false;
        rows.forEach(row => {
            const inputs = row.querySelectorAll('input, textarea');
            inputs.forEach(input => {
                validateInput({ target: input });
                if (input.classList.contains('error')) {
                    hasErrors = true;
                }
            });
        });

        if (hasErrors) {
            const errorMsg = window.i18n ? window.i18n.t('messages.validation_errors') : 'Please fix validation errors before saving';
            showMessage(errorMsg, "error");
            return;
        }

        if (!apiConfig.base_url) {
            const errorMsg = window.i18n ? window.i18n.t('messages.api_not_configured') : 'API server not configured';
            showMessage(errorMsg, "error");
            return;
        }

        const updatedData = rows.map((row) => {
            const cells = row.cells;
            const interactiveToggle = cells[7].querySelector(".interactive-toggle-button");
            return {
                name: cells[1].querySelector("input").value.trim(),
                remote_host: cells[3].querySelector("input").value.trim(),
                remote_port: cells[4].querySelector("input").value.trim(),
                local_port: cells[5].querySelector("input").value.trim(),
                interactive: interactiveToggle.getAttribute('data-interactive') === 'true',
                direction: cells[6].querySelector("select").value,
            };
        });

        const validTunnels = updatedData.filter(tunnel =>
            tunnel.name && tunnel.remote_host && tunnel.remote_port && tunnel.local_port
        );

        isConfigSaving = true;
        showLoading(true);

        try {
            const response = await apiCall('/config', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ tunnels: validTunnels }),
            });

            if (!response.ok) {
                const errorData = await response.text();
                throw new Error(`HTTP error! status: ${response.status} - ${errorData}`);
            }

            const successMsg = window.i18n ? window.i18n.t('messages.config_saved') : 'Configuration saved successfully!';
            showMessage(successMsg, "success");

            await loadConfiguration();

            isConfigSaving = false;
            showLoading(false);
        } catch (error) {
            console.error("Error saving configuration:", error);
            const errorMsg = window.i18n ? window.i18n.t('messages.config_save_failed') : 'Failed to save configuration';
            showMessage(errorMsg, "error");
            isConfigSaving = false;
            showLoading(false);
        }
    });

});

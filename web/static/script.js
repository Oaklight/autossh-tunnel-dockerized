document.addEventListener("DOMContentLoaded", () => {
    const tableBody = document.querySelector("#tunnelTable tbody");
    let dataTable;
    let apiConfig = { base_url: '', api_key: '' };
    let autoRefreshInterval = null;
    const AUTO_REFRESH_INTERVAL = 5000; // 5 seconds
    let isConfigSaving = false; // Flag to prevent clicks during save/reload

    // Initialize Material Design Components
    initializeMDC();

    // Load API config first, then load configuration
    loadAPIConfig().then(() => {
        loadConfiguration();
        // Start auto-refresh by default after initial load
        startAutoRefresh();
    });

    // Setup refresh button and auto-refresh checkbox
    setupRefreshControls();

    // Initialize Material Design Components
    function initializeMDC() {
        // Initialize buttons
        const buttons = document.querySelectorAll('.mdc-button');
        buttons.forEach(button => {
            mdc.ripple.MDCRipple.attachTo(button);
        });

        // Initialize data table
        const dataTableEl = document.querySelector('.mdc-data-table');
        if (dataTableEl) {
            dataTable = new mdc.dataTable.MDCDataTable(dataTableEl);
        }
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
        // Only show loading if not already in a save operation
        if (!isConfigSaving) {
            showLoading(true);
        }
        try {
            // Use Config API from autossh container
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
                    // Set initial status to LOADING or N/A
                    tunnel.status = 'N/A';
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
            // Only hide loading if not in a save operation (save handles its own loading state)
            if (!isConfigSaving) {
                showLoading(false);
            }
        }
    }

    // Add row function with Material Design styling
    function addRow(tunnel = { name: "", remote_host: "", remote_port: "", local_port: "", interactive: false, direction: "remote_to_local", status: "STOPPED" }) {
        const row = document.createElement("tr");
        row.className = "mdc-data-table__row new-row";

        let statusColor = "grey";
        let statusIcon = "radio_button_unchecked";
        let statusTooltip = tunnel.status || "STOPPED";

        // Set status icon and color based on status
        switch (tunnel.status) {
            case "RUNNING":
            case "NORMAL":
                statusIcon = "check_circle";
                statusColor = "#4CAF50"; // Green
                statusTooltip = "Running";
                break;
            case "DEAD":
                statusIcon = "cancel";
                statusColor = "#F44336"; // Red
                statusTooltip = "Dead";
                break;
            case "STARTING":
                statusIcon = "hourglass_empty";
                statusColor = "#FF9800"; // Orange
                statusTooltip = "Starting";
                break;
            case "STOPPED":
                statusIcon = "stop_circle";
                statusColor = "#9E9E9E"; // Grey
                statusTooltip = "Stopped";
                break;
            case "N/A":
            default:
                statusIcon = "help_outline";
                statusColor = "#9E9E9E"; // Grey
                statusTooltip = "Unknown";
                break;
        }

        // Use server-provided hash or empty string for new tunnels
        const tunnelHash = tunnel.hash || '';

        // Get translated placeholders
        const tunnelNamePlaceholder = window.i18n ? window.i18n.t('table.placeholders.tunnel_name') : 'Tunnel name';
        const remoteHostPlaceholder = window.i18n ? window.i18n.t('table.placeholders.remote_host') : 'Remote host';
        const remotePortPlaceholder = window.i18n ? window.i18n.t('table.placeholders.remote_port') : 'Remote port (e.g., 44497 or hostname:44497)';
        const localPortPlaceholder = window.i18n ? window.i18n.t('table.placeholders.local_port') : 'Local port (e.g., 55001 or 192.168.1.100:55001)';

        const remoteToLocalText = window.i18n ? window.i18n.t('table.direction.remote_to_local') : 'Remote to Local';
        const localToRemoteText = window.i18n ? window.i18n.t('table.direction.local_to_remote') : 'Local to Remote';

        const interactiveEnabledText = window.i18n ? window.i18n.t('buttons.interactive_auth_enabled') : 'Interactive Auth Enabled';
        const interactiveDisabledText = window.i18n ? window.i18n.t('buttons.interactive_auth_disabled') : 'Interactive Auth Disabled';
        const deleteTunnelText = window.i18n ? window.i18n.t('buttons.delete') : 'Delete tunnel';

        const saveRestartText = window.i18n ? window.i18n.t('buttons.save_restart_row') : 'Save & Restart';
        const startTunnelText = window.i18n ? window.i18n.t('buttons.start_tunnel') : 'Start tunnel';
        const restartTunnelText = window.i18n ? window.i18n.t('buttons.restart_tunnel') : 'Restart tunnel';
        const stopTunnelText = window.i18n ? window.i18n.t('buttons.stop_tunnel') : 'Stop tunnel';

        row.innerHTML = `
            <td class="mdc-data-table__cell">
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
            <td class="mdc-data-table__cell">
                <input type="text" class="table-input" value="${escapeHtml(tunnel.name || "")}" placeholder="${tunnelNamePlaceholder}" data-i18n-placeholder="table.placeholders.tunnel_name">
            </td>
            <td class="mdc-data-table__cell">
                <i class="material-icons status-indicator" data-hash="${tunnelHash}" style="color: ${statusColor}; font-size: 20px; vertical-align: middle; cursor: pointer;" title="${statusTooltip}">${statusIcon}</i>
            </td>
            <td class="mdc-data-table__cell">
                <input type="text" class="table-input" value="${escapeHtml(tunnel.remote_host || "")}" placeholder="${remoteHostPlaceholder}" data-i18n-placeholder="table.placeholders.remote_host">
            </td>
            <td class="mdc-data-table__cell">
                <input type="text" class="table-input remote-port-input" value="${escapeHtml(tunnel.remote_port || "")}" placeholder="${remotePortPlaceholder}" data-i18n-placeholder="table.placeholders.remote_port">
            </td>
            <td class="mdc-data-table__cell">
                <input type="text" class="table-input" value="${escapeHtml(tunnel.local_port || "")}" placeholder="${localPortPlaceholder}" data-i18n-placeholder="table.placeholders.local_port">
            </td>
            <td class="mdc-data-table__cell">
                <select class="table-select">
                    <option value="remote_to_local" ${tunnel.direction === "remote_to_local" ? "selected" : ""} data-i18n="table.direction.remote_to_local">${remoteToLocalText}</option>
                    <option value="local_to_remote" ${tunnel.direction === "local_to_remote" ? "selected" : ""} data-i18n="table.direction.local_to_remote">${localToRemoteText}</option>
                </select>
            </td>
            <td class="mdc-data-table__cell">
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

            // If tunnel has a hash, delete via Config API
            if (tunnelHash) {
                try {
                    const response = await apiCall(`/config/${tunnelHash}/delete`, { method: 'POST' });
                    if (!response.ok) {
                        const errorData = await response.text();
                        throw new Error(`Delete failed: ${response.status} - ${errorData}`);
                    }
                    const successMsg = window.i18n ? window.i18n.t('messages.delete_success') : 'Tunnel deleted successfully';
                    showMessage(successMsg, 'success');
                    // Reload configuration to refresh the list
                    setTimeout(() => loadConfiguration(), 500);
                } catch (error) {
                    console.error('Error deleting tunnel:', error);
                    const errorMsg = window.i18n ? window.i18n.t('messages.delete_failed') : 'Failed to delete tunnel';
                    showMessage(errorMsg, 'error');
                }
            } else {
                // New unsaved row, just remove from DOM
                row.style.animation = "fadeOut 0.3s ease-out";
                setTimeout(() => row.remove(), 300);
            }
        });

        // Add interactive toggle event
        const interactiveToggle = row.querySelector(".interactive-toggle-button");
        interactiveToggle.addEventListener("click", () => {
            const isActive = interactiveToggle.classList.contains('active');
            const newState = !isActive;

            // Update button state
            interactiveToggle.classList.toggle('active', newState);
            interactiveToggle.setAttribute('data-interactive', newState.toString());

            // Update title (icon stays the same, only color changes via CSS)
            const enabledText = window.i18n ? window.i18n.t('buttons.interactive_auth_enabled') : 'Interactive Auth Enabled';
            const disabledText = window.i18n ? window.i18n.t('buttons.interactive_auth_disabled') : 'Interactive Auth Disabled';
            interactiveToggle.title = newState ? enabledText : disabledText;
        });

        // Add control button events
        const saveRowButton = row.querySelector(".save-row-button");
        const startButton = row.querySelector(".start-button");
        const restartButton = row.querySelector(".restart-button");
        const stopButton = row.querySelector(".stop-button");

        saveRowButton.addEventListener("click", () => handleSaveRow(tunnelHash, row));
        startButton.addEventListener("click", () => handleTunnelControl('start', tunnelHash, row));
        restartButton.addEventListener("click", () => handleTunnelControl('restart', tunnelHash, row));
        stopButton.addEventListener("click", () => handleTunnelControl('stop', tunnelHash, row));

        // Add click event to status indicator
        const statusIndicator = row.querySelector(".status-indicator");
        if (statusIndicator && tunnelHash) {
            statusIndicator.addEventListener("click", () => {
                // Prevent navigation during config save/reload
                if (isConfigSaving) {
                    const waitMsg = window.i18n ? window.i18n.t('messages.please_wait') : 'Please wait for configuration to reload...';
                    showMessage(waitMsg, 'info');
                    return;
                }
                window.location.href = `/tunnel-detail?hash=${tunnelHash}`;
            });
            // Add hover effect
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

    // Handle save single row (update tunnel config and restart)
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

        // Validate required fields
        if (!tunnelData.name || !tunnelData.remote_host || !tunnelData.remote_port || !tunnelData.local_port) {
            const errorMsg = window.i18n ? window.i18n.t('messages.validation_errors') : 'Please fill in all required fields';
            showMessage(errorMsg, 'error');
            return;
        }

        // Validate inputs
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

        // Disable all control buttons during operation
        const controlButtons = row.querySelectorAll('.control-button');
        controlButtons.forEach(btn => btn.disabled = true);

        // Show loading indicator on status
        const statusIndicator = row.querySelector('.status-indicator');
        if (statusIndicator) {
            statusIndicator.textContent = 'hourglass_empty';
            statusIndicator.style.color = '#FF9800';
            statusIndicator.title = 'Saving...';
        }

        try {
            let response;
            if (hash) {
                // Update existing tunnel via Config API
                response = await apiCall(`/config/${hash}`, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify(tunnelData),
                });
            } else {
                // Create new tunnel via Config API
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

            // Get the new hash from response
            const responseData = await response.json();
            const newHash = responseData.hash || hash;

            // Update the row's hash references
            updateRowHash(row, newHash);

            const successMsg = window.i18n ? window.i18n.t('messages.config_saved') : 'Configuration saved successfully!';
            showMessage(successMsg, 'success');

            // Wait for file monitor to detect changes and complete smart restart
            // Then refresh only this row's status
            setTimeout(async () => {
                await refreshRowStatus(row, newHash);
            }, 3000);

        } catch (error) {
            console.error('Error saving tunnel:', error);
            const errorMsg = window.i18n ? window.i18n.t('messages.config_save_failed') : 'Failed to save configuration';
            showMessage(errorMsg, 'error');
            // Reset status indicator on error
            if (statusIndicator) {
                updateStatusIndicator(statusIndicator, 'STOPPED');
            }
        } finally {
            controlButtons.forEach(btn => btn.disabled = false);
        }
    }

    // Update a row's hash references after save
    function updateRowHash(row, newHash) {
        // Update status indicator
        const statusIndicator = row.querySelector('.status-indicator');
        if (statusIndicator) {
            statusIndicator.dataset.hash = newHash;
        }

        // Update control buttons
        const controlButtons = row.querySelectorAll('.control-button');
        controlButtons.forEach(btn => {
            btn.dataset.hash = newHash;
        });

        // Update event listeners for control buttons
        const saveRowButton = row.querySelector(".save-row-button");
        const startButton = row.querySelector(".start-button");
        const restartButton = row.querySelector(".restart-button");
        const stopButton = row.querySelector(".stop-button");

        // Clone and replace to remove old event listeners
        const newSaveBtn = saveRowButton.cloneNode(true);
        const newStartBtn = startButton.cloneNode(true);
        const newRestartBtn = restartButton.cloneNode(true);
        const newStopBtn = stopButton.cloneNode(true);

        saveRowButton.parentNode.replaceChild(newSaveBtn, saveRowButton);
        startButton.parentNode.replaceChild(newStartBtn, startButton);
        restartButton.parentNode.replaceChild(newRestartBtn, restartButton);
        stopButton.parentNode.replaceChild(newStopBtn, stopButton);

        // Add new event listeners with updated hash
        newSaveBtn.addEventListener("click", () => handleSaveRow(newHash, row));
        newStartBtn.addEventListener("click", () => handleTunnelControl('start', newHash, row));
        newRestartBtn.addEventListener("click", () => handleTunnelControl('restart', newHash, row));
        newStopBtn.addEventListener("click", () => handleTunnelControl('stop', newHash, row));

        // Update status indicator click handler
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
    async function handleTunnelControl(action, hash, row) {
        // Check if hash is available
        if (!hash) {
            const errorMsg = window.i18n ? window.i18n.t('messages.save_first') : 'Please save the configuration first';
            showMessage(errorMsg, 'error');
            return;
        }

        const actionText = window.i18n ? window.i18n.t(`buttons.${action}_tunnel`) : `${action} tunnel`;
        const confirmMsg = window.i18n ? window.i18n.t(`messages.confirm_${action}`) : `Are you sure you want to ${action} this tunnel?`;

        // For restart and stop, ask for confirmation
        if ((action === 'restart' || action === 'stop') && !confirm(confirmMsg)) {
            return;
        }

        // Disable all control buttons during operation
        const controlButtons = row.querySelectorAll('.control-button');
        controlButtons.forEach(btn => btn.disabled = true);

        try {
            let endpoint, method;

            if (!apiConfig.base_url) {
                throw new Error('API server not configured');
            }

            if (action === 'restart') {
                // Restart = stop + start
                endpoint = `/stop/${hash}`;
                method = 'POST';

                const stopResponse = await apiCall(endpoint, { method });
                if (!stopResponse.ok) {
                    const stopData = await stopResponse.text();
                    throw new Error(`Stop failed: ${stopResponse.status} - ${stopData}`);
                }

                // Wait a bit before starting
                await new Promise(resolve => setTimeout(resolve, 1000));

                endpoint = `/start/${hash}`;
                const startResponse = await apiCall(endpoint, { method });
                if (!startResponse.ok) {
                    const startData = await startResponse.text();
                    throw new Error(`Start failed: ${startResponse.status} - ${startData}`);
                }
            } else {
                endpoint = `/${action}/${hash}`;
                method = 'POST';

                const response = await apiCall(endpoint, { method });
                if (!response.ok) {
                    const responseData = await response.text();
                    throw new Error(`${action} failed: ${response.status} - ${responseData}`);
                }
            }

            const successMsg = window.i18n ? window.i18n.t(`messages.${action}_success`) : `Tunnel ${action}ed successfully`;
            showMessage(successMsg, 'success');

            // Reload status after a short delay
            setTimeout(() => loadConfiguration(), 1500);

        } catch (error) {
            console.error(`Error ${action}ing tunnel:`, error);
            const errorMsg = window.i18n ? window.i18n.t(`messages.${action}_failed`) : `Failed to ${action} tunnel: ${error.message}`;
            showMessage(errorMsg, 'error');
        } finally {
            // Re-enable control buttons
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

        // Remove existing error styling
        input.classList.remove('error');

        // Validate based on input type and requirements
        if (input.type === 'number') {
            const num = parseInt(value);
            if (value && (isNaN(num) || num < 1 || num > 65535)) {
                input.classList.add('error');
                const errorMsg = window.i18n ? window.i18n.t('validation.port_range') : 'Port must be between 1 and 65535';
                input.title = errorMsg;
            }
        } else if (input.classList.contains('remote-port-input') || input.placeholder && input.placeholder.includes('Remote port')) {
            // Validate remote_port which can be "port" or "hostname:port" format
            if (value) {
                const portPattern = /^[\w.-]+:\d{1,5}$|^\d{1,5}$/;
                if (!portPattern.test(value)) {
                    input.classList.add('error');
                    const errorMsg = window.i18n ? window.i18n.t('validation.remote_port_format') : 'Invalid port format. Use "port" or "hostname:port" (e.g., 44497 or lambda5:44497)';
                    input.title = errorMsg;
                }
            }
        } else if (input.placeholder && input.placeholder.includes('Local port')) {
            // Validate local_port which can be "port" or "ip:port" format
            if (value) {
                const portPattern = /^(\d{1,3}\.){3}\d{1,3}:\d{1,5}$|^\d{1,5}$/;
                if (!portPattern.test(value)) {
                    input.classList.add('error');
                    const errorMsg = window.i18n ? window.i18n.t('validation.local_port_format') : 'Invalid port format. Use "port" or "ip:port" (e.g., 55001 or 192.168.1.100:55001)';
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
            loadingEl.innerHTML = '<div class="mdc-circular-progress" style="width:48px;height:48px;" role="progressbar"><div class="mdc-circular-progress__determinate-container"><svg class="mdc-circular-progress__determinate-circle-graphic" viewBox="0 0 48 48"><circle class="mdc-circular-progress__determinate-track" cx="24" cy="24" r="18" stroke-width="4"/><circle class="mdc-circular-progress__determinate-circle" cx="24" cy="24" r="18" stroke-dasharray="113.097" stroke-dashoffset="113.097" stroke-width="4"/></svg></div><div class="mdc-circular-progress__indeterminate-container"><div class="mdc-circular-progress__spinner-layer"><div class="mdc-circular-progress__circle-clipper mdc-circular-progress__circle-left"><svg class="mdc-circular-progress__indeterminate-circle-graphic" viewBox="0 0 48 48"><circle cx="24" cy="24" r="18" stroke-dasharray="113.097" stroke-dashoffset="56.549" stroke-width="4"/></svg></div><div class="mdc-circular-progress__gap-patch"><svg class="mdc-circular-progress__indeterminate-circle-graphic" viewBox="0 0 48 48"><circle cx="24" cy="24" r="18" stroke-dasharray="113.097" stroke-dashoffset="56.549" stroke-width="3.2"/></svg></div><div class="mdc-circular-progress__circle-clipper mdc-circular-progress__circle-right"><svg class="mdc-circular-progress__indeterminate-circle-graphic" viewBox="0 0 48 48"><circle cx="24" cy="24" r="18" stroke-dasharray="113.097" stroke-dashoffset="56.549" stroke-width="4"/></svg></div></div></div></div>';
            container.appendChild(loadingEl);
        } else if (!show && loadingEl) {
            loadingEl.remove();
        }
    }

    // Show success/error messages
    function showMessage(text, type = 'success') {
        // Remove existing messages
        const existingMessages = document.querySelectorAll('.message');
        existingMessages.forEach(msg => msg.remove());

        const message = document.createElement('div');
        message.className = `message ${type}`;
        message.textContent = text;

        const container = document.querySelector('.container');
        container.insertBefore(message, container.firstChild);

        // Auto-remove after 5 seconds
        setTimeout(() => {
            if (message.parentNode) {
                message.style.animation = 'fadeOut 0.3s ease-out';
                setTimeout(() => message.remove(), 300);
            }
        }, 5000);
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
    }

    // Refresh only statuses (not full config reload)
    // retryCount is used for fast retry on initial load
    async function refreshStatuses(retryCount = 0) {
        const statuses = await fetchTunnelStatuses();

        // If empty and we haven't retried too many times, retry quickly
        if (Object.keys(statuses).length === 0) {
            if (retryCount < 5) {
                const delay = 500; // 500ms fast retry
                console.log(`Status fetch returned empty, retrying in ${delay}ms (attempt ${retryCount + 1}/5)`);
                setTimeout(() => refreshStatuses(retryCount + 1), delay);
            }
            return;
        }

        // Update status indicators in existing rows
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
        let statusColor = "#9E9E9E";
        let statusIcon = "help_outline";
        let statusTooltip = "Unknown";

        switch (status) {
            case "RUNNING":
            case "NORMAL":
                statusIcon = "check_circle";
                statusColor = "#4CAF50";
                statusTooltip = "Running";
                break;
            case "DEAD":
                statusIcon = "cancel";
                statusColor = "#F44336";
                statusTooltip = "Dead";
                break;
            case "STARTING":
                statusIcon = "hourglass_empty";
                statusColor = "#FF9800";
                statusTooltip = "Starting";
                break;
            case "STOPPED":
                statusIcon = "stop_circle";
                statusColor = "#9E9E9E";
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

    // Save config button event - uses Config API to replace all configurations
    document.getElementById("saveConfig").addEventListener("click", async () => {
        const rows = Array.from(tableBody.rows);

        // Validate all inputs before saving
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

        // Filter out empty rows
        const validTunnels = updatedData.filter(tunnel =>
            tunnel.name && tunnel.remote_host && tunnel.remote_port && tunnel.local_port
        );

        // Set flag to prevent status indicator clicks during save/reload
        isConfigSaving = true;
        showLoading(true);

        try {
            // Use Config API from autossh container
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

            // Reload configuration immediately to get updated hashes
            await loadConfiguration();

            // Configuration reloaded successfully, re-enable clicks
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


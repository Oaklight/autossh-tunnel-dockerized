document.addEventListener("DOMContentLoaded", () => {
    const tableBody = document.querySelector("#tunnelTable tbody");
    let dataTable;

    // Initialize Material Design Components
    initializeMDC();

    // Load initial config
    loadConfiguration();

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

    // Load configuration from server
    function loadConfiguration() {
        showLoading(true);
        fetch("/api/config")
            .then((response) => {
                if (!response.ok) {
                    throw new Error(`HTTP error! status: ${response.status}`);
                }
                return response.json();
            })
            .then((data) => {
                showLoading(false);
                // Clear existing rows before adding new ones
                tableBody.innerHTML = '';
                if (data.tunnels && Array.isArray(data.tunnels)) {
                    data.tunnels.forEach((tunnel) => addRow(tunnel));
                } else {
                    const warningMsg = window.i18n ? window.i18n.t('messages.no_tunnels') : 'No tunnels found in configuration';
                    console.warn(warningMsg);
                }
            })
            .catch((error) => {
                showLoading(false);
                console.error("Error loading configuration:", error);
                const errorMsg = window.i18n ? window.i18n.t('messages.config_load_failed') : 'Failed to load configuration';
                showMessage(errorMsg, "error");
            });
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

        const startTunnelText = window.i18n ? window.i18n.t('buttons.start_tunnel') : 'Start tunnel';
        const restartTunnelText = window.i18n ? window.i18n.t('buttons.restart_tunnel') : 'Restart tunnel';
        const stopTunnelText = window.i18n ? window.i18n.t('buttons.stop_tunnel') : 'Stop tunnel';

        row.innerHTML = `
            <td class="mdc-data-table__cell">
                <div class="control-buttons-cell">
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
                <i class="material-icons" style="color: ${statusColor}; font-size: 20px; vertical-align: middle;" title="${statusTooltip}">${statusIcon}</i>
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
        row.querySelector(".deleteRow").addEventListener("click", () => {
            const confirmMessage = window.i18n ? window.i18n.t('messages.delete_confirm') : 'Are you sure you want to delete this tunnel configuration?';
            if (confirm(confirmMessage)) {
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
        const startButton = row.querySelector(".start-button");
        const restartButton = row.querySelector(".restart-button");
        const stopButton = row.querySelector(".stop-button");

        startButton.addEventListener("click", () => handleTunnelControl('start', tunnelHash, row));
        restartButton.addEventListener("click", () => handleTunnelControl('restart', tunnelHash, row));
        stopButton.addEventListener("click", () => handleTunnelControl('stop', tunnelHash, row));

        // Add input validation
        addInputValidation(row);

        // Remove animation class after animation completes
        setTimeout(() => row.classList.remove("new-row"), 300);
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

            if (action === 'restart') {
                // Restart = stop + start
                endpoint = `/stop/${hash}`;
                method = 'POST';

                const stopResponse = await fetch(`http://localhost:8080${endpoint}`, { method });
                if (!stopResponse.ok) {
                    const stopData = await stopResponse.text();
                    throw new Error(`Stop failed: ${stopResponse.status} - ${stopData}`);
                }

                // Wait a bit before starting
                await new Promise(resolve => setTimeout(resolve, 1000));

                endpoint = `/start/${hash}`;
                const startResponse = await fetch(`http://localhost:8080${endpoint}`, { method });
                if (!startResponse.ok) {
                    const startData = await startResponse.text();
                    throw new Error(`Start failed: ${startResponse.status} - ${startData}`);
                }
            } else {
                endpoint = `/${action}/${hash}`;
                method = 'POST';

                const response = await fetch(`http://localhost:8080${endpoint}`, { method });
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

    // Add new row button event
    document.getElementById("addRow").addEventListener("click", () => {
        addRow();
    });

    // Save config button event
    document.getElementById("saveConfig").addEventListener("click", () => {
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

        showLoading(true);
        fetch("/api/config", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ tunnels: validTunnels }),
        })
            .then(response => {
                showLoading(false);
                if (!response.ok) {
                    throw new Error(`HTTP error! status: ${response.status}`);
                }
                return response.text();
            })
            .then(() => {
                const successMsg = window.i18n ? window.i18n.t('messages.config_saved') : 'Configuration saved successfully!';
                showMessage(successMsg, "success");
            })
            .catch(error => {
                console.error("Error saving configuration:", error);
                const errorMsg = window.i18n ? window.i18n.t('messages.config_save_failed') : 'Failed to save configuration';
                showMessage(errorMsg, "error");
            });
    });

});


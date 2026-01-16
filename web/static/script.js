document.addEventListener("DOMContentLoaded", () => {
    const tableBody = document.querySelector("#tunnelTable tbody");
    let dataTable;
    let statusUpdateInterval;
    let tunnelStatuses = {};

    // Initialize Material Design Components
    initializeMDC();

    // Load initial config
    loadConfiguration();

    // Start status polling
    startStatusPolling();

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
                if (data.tunnels && Array.isArray(data.tunnels)) {
                    data.tunnels.forEach((tunnel) => addRow(tunnel));
                } else {
                    console.warn("No tunnels found in configuration");
                }
            })
            .catch((error) => {
                showLoading(false);
                console.error("Error loading configuration:", error);
                showMessage("Failed to load configuration", "error");
            });
    }

    // Add row function with Material Design styling
    function addRow(tunnel = { name: "", remote_host: "", remote_port: "", local_port: "", direction: "remote_to_local" }) {
        const row = document.createElement("tr");
        row.className = "mdc-data-table__row new-row";

        // Generate a unique row ID for status tracking
        const rowId = `row_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
        row.setAttribute('data-row-id', rowId);

        row.innerHTML = `
            <td class="mdc-data-table__cell">
                <input type="text" class="table-input" value="${escapeHtml(tunnel.name || "")}" placeholder="Tunnel name">
            </td>
            <td class="mdc-data-table__cell">
                <input type="text" class="table-input" value="${escapeHtml(tunnel.remote_host || "")}" placeholder="Remote host">
            </td>
            <td class="mdc-data-table__cell">
                <input type="number" class="table-input" value="${escapeHtml(tunnel.remote_port || "")}" placeholder="Remote port" min="1" max="65535">
            </td>
            <td class="mdc-data-table__cell">
                <input type="number" class="table-input" value="${escapeHtml(tunnel.local_port || "")}" placeholder="Local port" min="1" max="65535">
            </td>
            <td class="mdc-data-table__cell">
                <select class="table-select">
                    <option value="remote_to_local" ${tunnel.direction === "remote_to_local" ? "selected" : ""}>Remote to Local</option>
                    <option value="local_to_remote" ${tunnel.direction === "local_to_remote" ? "selected" : ""}>Local to Remote</option>
                </select>
            </td>
            <td class="mdc-data-table__cell status-cell">
                <div class="status-indicator">
                    <a href="#" class="status-badge status-unknown status-link" data-log-id="">
                        <i class="material-icons status-icon">help_outline</i>
                        <span class="status-text">Unknown</span>
                    </a>
                    <div class="status-details" style="display: none;">
                        <small class="status-message"></small>
                        <small class="status-time"></small>
                    </div>
                </div>
            </td>
            <td class="mdc-data-table__cell">
                <button class="delete-button deleteRow" title="Delete tunnel">
                    <i class="material-icons">delete</i>
                </button>
            </td>
        `;

        tableBody.appendChild(row);

        // Add delete row event with confirmation
        row.querySelector(".deleteRow").addEventListener("click", () => {
            if (confirm("Are you sure you want to delete this tunnel configuration?")) {
                row.style.animation = "fadeOut 0.3s ease-out";
                setTimeout(() => row.remove(), 300);
            }
        });

        // Add input validation
        addInputValidation(row);

        // Remove animation class after animation completes
        setTimeout(() => row.classList.remove("new-row"), 300);
    }

    // Add input validation
    function addInputValidation(row) {
        const inputs = row.querySelectorAll('input');
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
                input.title = 'Port must be between 1 and 65535';
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

    // Load and update tunnel statuses
    function loadTunnelStatuses() {
        fetch("/api/status")
            .then((response) => {
                if (!response.ok) {
                    throw new Error(`HTTP error! status: ${response.status}`);
                }
                return response.json();
            })
            .then((data) => {
                if (data.tunnels && Array.isArray(data.tunnels)) {
                    // Create a map of statuses by tunnel configuration
                    tunnelStatuses = {};
                    data.tunnels.forEach((tunnel) => {
                        const key = `${tunnel.remote_host}:${tunnel.remote_port}:${tunnel.local_port}:${tunnel.direction}`;
                        tunnelStatuses[key] = tunnel;
                    });
                    updateStatusDisplay();
                }
            })
            .catch((error) => {
                console.error("Error loading tunnel statuses:", error);
            });
    }

    // Update status display for all rows
    function updateStatusDisplay() {
        const rows = Array.from(tableBody.rows);
        rows.forEach((row) => {
            const cells = row.cells;
            if (cells.length < 6) return;

            const remoteHost = cells[1].querySelector("input")?.value.trim();
            const remotePort = cells[2].querySelector("input")?.value.trim();
            const localPort = cells[3].querySelector("input")?.value.trim();
            const direction = cells[4].querySelector("select")?.value;

            if (!remoteHost || !remotePort || !localPort) return;

            const key = `${remoteHost}:${remotePort}:${localPort}:${direction}`;
            const statusData = tunnelStatuses[key];

            const statusCell = cells[5];
            const statusBadge = statusCell.querySelector(".status-badge");
            const statusText = statusCell.querySelector(".status-text");
            const statusIcon = statusCell.querySelector(".status-icon");
            const statusDetails = statusCell.querySelector(".status-details");
            const statusMessage = statusCell.querySelector(".status-message");
            const statusTime = statusCell.querySelector(".status-time");

            if (statusData) {
                // Remove all status classes
                statusBadge.className = "status-badge status-link";
                
                // Set log ID for the link
                statusBadge.setAttribute('data-log-id', statusData.log_id);
                
                // Add appropriate status class and update content
                switch (statusData.status) {
                    case "connected":
                        statusBadge.classList.add("status-connected");
                        statusIcon.textContent = "check_circle";
                        statusText.textContent = "Connected";
                        break;
                    case "disconnected":
                        statusBadge.classList.add("status-disconnected");
                        statusIcon.textContent = "cancel";
                        statusText.textContent = "Disconnected";
                        break;
                    case "error":
                        statusBadge.classList.add("status-error");
                        statusIcon.textContent = "error";
                        statusText.textContent = "Error";
                        break;
                    default:
                        statusBadge.classList.add("status-unknown");
                        statusIcon.textContent = "help_outline";
                        statusText.textContent = "Unknown";
                }

                // Update status details
                if (statusData.message) {
                    statusMessage.textContent = statusData.message;
                    statusDetails.style.display = "block";
                }
                if (statusData.last_update) {
                    statusTime.textContent = `Updated: ${statusData.last_update}`;
                }
            } else {
                // No status data available
                statusBadge.className = "status-badge status-link status-unknown";
                statusBadge.setAttribute('data-log-id', '');
                statusIcon.textContent = "help_outline";
                statusText.textContent = "Unknown";
                statusDetails.style.display = "none";
            }
        });
    }

    // Start polling for status updates
    function startStatusPolling() {
        // Initial load
        loadTunnelStatuses();
        
        // Poll every 5 seconds
        statusUpdateInterval = setInterval(() => {
            loadTunnelStatuses();
        }, 5000);
    }

    // Stop polling (cleanup)
    function stopStatusPolling() {
        if (statusUpdateInterval) {
            clearInterval(statusUpdateInterval);
            statusUpdateInterval = null;
        }
    }

    // Add new row button event
    document.getElementById("addRow").addEventListener("click", () => {
        addRow();
    });

    // Refresh status button event
    document.getElementById("refreshStatus").addEventListener("click", () => {
        loadTunnelStatuses();
        showMessage("Status refreshed", "success");
    });

    // Save config button event
    document.getElementById("saveConfig").addEventListener("click", () => {
        const rows = Array.from(tableBody.rows);
        
        // Validate all inputs before saving
        let hasErrors = false;
        rows.forEach(row => {
            const inputs = row.querySelectorAll('input');
            inputs.forEach(input => {
                validateInput({ target: input });
                if (input.classList.contains('error')) {
                    hasErrors = true;
                }
            });
        });

        if (hasErrors) {
            showMessage("Please fix validation errors before saving", "error");
            return;
        }

        const updatedData = rows.map((row) => {
            const cells = row.cells;
            return {
                name: cells[0].querySelector("input").value.trim(),
                remote_host: cells[1].querySelector("input").value.trim(),
                remote_port: cells[2].querySelector("input").value.trim(),
                local_port: cells[3].querySelector("input").value.trim(),
                direction: cells[4].querySelector("select").value,
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
            showMessage("Configuration saved successfully!", "success");
            // Reload statuses after saving config
            setTimeout(() => {
                loadTunnelStatuses();
            }, 1000);
        })
        .catch(error => {
            console.error("Error saving configuration:", error);
            showMessage("Failed to save configuration", "error");
        });
    });

    // Handle status badge clicks
    document.addEventListener('click', (e) => {
        const statusLink = e.target.closest('.status-link');
        if (statusLink) {
            e.preventDefault();
            const logID = statusLink.getAttribute('data-log-id');
            if (logID) {
                window.location.href = `/logs?id=${logID}`;
            }
        }
    });

    // Cleanup on page unload
    window.addEventListener("beforeunload", () => {
        stopStatusPolling();
    });
});

// Add fadeOut animation to CSS
const style = document.createElement('style');
style.textContent = `
    @keyframes fadeOut {
        from {
            opacity: 1;
            transform: translateY(0);
        }
        to {
            opacity: 0;
            transform: translateY(-10px);
        }
    }
    
    .table-input.error {
        border-color: #d32f2f;
        box-shadow: 0 0 0 2px rgba(211, 47, 47, 0.2);
    }
`;
document.head.appendChild(style);

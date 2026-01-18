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
            initResizableColumns();
        }
    }

    // Initialize Resizable Columns
    function initResizableColumns() {
        const table = document.getElementById('tunnelTable');
        const headerRow = table.querySelector('thead tr');
        const cols = headerRow.querySelectorAll('th');

        cols.forEach((col, index) => {
            // Don't add resizer to the last column (Action)
            if (index === cols.length - 1) return;

            const resizer = document.createElement('div');
            resizer.classList.add('resizer');
            col.appendChild(resizer);

            createResizableColumn(col, resizer);
        });
    }

    function createResizableColumn(col, resizer) {
        let x = 0;
        let w = 0;

        const mouseDownHandler = function (e) {
            x = e.clientX;
            const styles = window.getComputedStyle(col);
            w = parseInt(styles.width, 10);

            document.addEventListener('mousemove', mouseMoveHandler);
            document.addEventListener('mouseup', mouseUpHandler);
            document.body.classList.add('resizing');
        };

        const mouseMoveHandler = function (e) {
            const dx = e.clientX - x;
            col.style.width = `${w + dx}px`;
        };

        const mouseUpHandler = function () {
            document.removeEventListener('mousemove', mouseMoveHandler);
            document.removeEventListener('mouseup', mouseUpHandler);
            document.body.classList.remove('resizing');
        };

        resizer.addEventListener('mousedown', mouseDownHandler);
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
    function addRow(tunnel = { name: "", remote_host: "", remote_port: "", local_port: "", interactive: false, direction: "remote_to_local" }) {
        const row = document.createElement("tr");
        row.className = "mdc-data-table__row new-row";

        row.innerHTML = `
            <td class="mdc-data-table__cell">
                <input type="text" class="table-input" value="${escapeHtml(tunnel.name || "")}" placeholder="Tunnel name">
            </td>
            <td class="mdc-data-table__cell">
                <input type="text" class="table-input" value="${escapeHtml(tunnel.remote_host || "")}" placeholder="Remote host">
            </td>
            <td class="mdc-data-table__cell">
                <input type="text" class="table-input remote-port-input" value="${escapeHtml(tunnel.remote_port || "")}" placeholder="Remote port (e.g., 44497 or hostname:44497)">
            </td>
            <td class="mdc-data-table__cell">
                <input type="text" class="table-input" value="${escapeHtml(tunnel.local_port || "")}" placeholder="Local port (e.g., 55001 or 192.168.1.100:55001)">
            </td>
            <td class="mdc-data-table__cell">
                <input type="checkbox" class="table-checkbox" ${tunnel.interactive ? "checked" : ""}>
            </td>
            <td class="mdc-data-table__cell">
                <select class="table-select">
                    <option value="remote_to_local" ${tunnel.direction === "remote_to_local" ? "selected" : ""}>Remote to Local</option>
                    <option value="local_to_remote" ${tunnel.direction === "local_to_remote" ? "selected" : ""}>Local to Remote</option>
                </select>
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
                input.title = 'Port must be between 1 and 65535';
            }
        } else if (input.classList.contains('remote-port-input') || input.placeholder && input.placeholder.includes('Remote port')) {
            // Validate remote_port which can be "port" or "hostname:port" format
            if (value) {
                const portPattern = /^[\w.-]+:\d{1,5}$|^\d{1,5}$/;
                if (!portPattern.test(value)) {
                    input.classList.add('error');
                    input.title = 'Invalid port format. Use "port" or "hostname:port" (e.g., 44497 or lambda5:44497)';
                }
            }
        } else if (input.placeholder && input.placeholder.includes('Local port')) {
            // Validate local_port which can be "port" or "ip:port" format
            if (value) {
                const portPattern = /^(\d{1,3}\.){3}\d{1,3}:\d{1,5}$|^\d{1,5}$/;
                if (!portPattern.test(value)) {
                    input.classList.add('error');
                    input.title = 'Invalid port format. Use "port" or "ip:port" (e.g., 55001 or 192.168.1.100:55001)';
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
                interactive: cells[4].querySelector("input[type='checkbox']").checked,
                direction: cells[5].querySelector("select").value,
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
            })
            .catch(error => {
                console.error("Error saving configuration:", error);
                showMessage("Failed to save configuration", "error");
            });
    });
});


document.addEventListener("DOMContentLoaded", () => {
    const tableBody = document.querySelector("#tunnelTable tbody");

    // Load initial config
    fetch("/api/config")
        .then((response) => response.json())
        .then((data) => {
            data.tunnels.forEach((tunnel) => addRow(tunnel));
        });

    // Add row function
    function addRow(tunnel = { name: "", remote_host: "", remote_port: "", local_port: "", direction: "remote_to_local" }) {
        const row = document.createElement("tr");

        row.innerHTML = `
            <td><input type="text" value="${tunnel.name || ""}"></td>
            <td><input type="text" value="${tunnel.remote_host || ""}"></td>
            <td><input type="text" value="${tunnel.remote_port || ""}"></td>
            <td><input type="text" value="${tunnel.local_port || ""}"></td>
            <td>
                <select>
                    <option value="remote_to_local" ${tunnel.direction === "remote_to_local" ? "selected" : ""}>Remote to Local</option>
                    <option value="local_to_remote" ${tunnel.direction === "local_to_remote" ? "selected" : ""}>Local to Remote</option>
                </select>
            </td>
            <td><button class="deleteRow">Delete</button></td>
        `;

        tableBody.appendChild(row);

        // Delete row event
        row.querySelector(".deleteRow").addEventListener("click", () => row.remove());
    }

    // Add new row button
    document.getElementById("addRow").addEventListener("click", () => addRow());

    // Save config button
    document.getElementById("saveConfig").addEventListener("click", () => {
        const updatedData = Array.from(tableBody.rows).map((row) => ({
            name: row.cells[0].querySelector("input").value,
            remote_host: row.cells[1].querySelector("input").value,
            remote_port: row.cells[2].querySelector("input").value,
            local_port: row.cells[3].querySelector("input").value,
            direction: row.cells[4].querySelector("select").value,
        }));
        fetch("/api/config", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ tunnels: updatedData }),
        }).then(() => alert("Saved successfully!"));
    });
});

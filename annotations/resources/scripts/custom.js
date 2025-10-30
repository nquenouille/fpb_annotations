/* FPB helper script for updating register */
document.addEventListener('DOMContentLoaded', () => {
    const pbPage = document.querySelector('pb-page');
    if (!pbPage) return;

    // Delegation: auf pb-page lauschen, ob ein Klick auf #updateRegister kommt
    pbPage.addEventListener('click', (event) => {
        const btn = event.target.closest('#updateRegister');
        if (btn) {
            window.pbEvents.emit("pb-start-update", "update", {});
            updateRegister();
        }
    });
});

function updateRegister() {
    const endpoint = document.querySelector("pb-page").getEndpoint();
    fetch(`${endpoint}/api/updateRegister`, {
        method: "GET",
        mode: "cors",
        credentials: "same-origin",
        headers: {
            "Content-Type": "application/json"
        }
    })
    .then(response => {
        window.pbEvents.emit("pb-end-update", "update", {});
        if (!response.ok) throw new Error("HTTP-Fehler: " + response.status);
        return response.json();
    })
    .then(data => {
        console.log("Register updated:", data);
        document.getElementById("popup-data").textContent = JSON.stringify(data, null, 2);
        document.getElementById("popup").style.display = "block";
    })
    .catch(error => {
        console.error("Fehler beim Update:", error);
        alert("Fehler beim Update: " + error.message);
    });
}
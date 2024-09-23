document.getElementById("generateBtn").addEventListener("click", async () => {
  // Get the Type of Diagram Selected from the Dropdown
  const selectedOption = document.getElementById("graph_type").value;

  try {
    const response = await fetch("/generate-pdf", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ option: selectedOption }),
    });

    if (!response.ok) {
      throw new Error("Failed to generate graph");
    }

    const blob = await response.blob();
    const url = URL.createObjectURL(blob);

    document.getElementById("pdf-viewer").src = url;
  } catch (error) {
    document.getElementById("error-message").textContent = error.message;
  }
});

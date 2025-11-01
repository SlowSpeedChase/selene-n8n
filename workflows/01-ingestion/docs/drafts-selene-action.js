// Selene - Send Note to n8n
// This action sends your draft to the Selene knowledge management system
//
// CONFIGURATION: Edit these settings for your environment

const CONFIG = {
  // Choose your network environment
  // Options: "local" (same WiFi), "tailscale", "mac" (macOS Drafts app)
  network: "local",

  // Your IP addresses (update these with your actual values)
  localIP: "192.168.1.26",
  tailscaleIP: "100.111.6.10",

  // n8n configuration
  port: "5678",

  // Webhook path - Change based on workflow activation status:
  // - If workflow is ACTIVATED (production): use "/webhook/api/drafts"
  // - If workflow is NOT activated (testing): use "/webhook-test/api/drafts"
  webhookPath: "/webhook/api/drafts",

  // Testing mode (adds test_run marker for easy cleanup)
  testMode: false,
  testMarker: "drafts-test"
};

// Build the webhook URL based on configuration
function getWebhookURL() {
  let baseURL;

  switch(CONFIG.network) {
    case "mac":
      baseURL = `http://localhost:${CONFIG.port}`;
      break;
    case "tailscale":
      baseURL = `http://${CONFIG.tailscaleIP}:${CONFIG.port}`;
      break;
    case "local":
    default:
      baseURL = `http://${CONFIG.localIP}:${CONFIG.port}`;
  }

  return baseURL + CONFIG.webhookPath;
}

// Build the payload
function buildPayload() {
  const payload = {
    title: draft.title || "Untitled",
    content: draft.content,
    created_at: draft.createdAt.toISOString(),
    source_type: "drafts"
  };

  // Add test marker if in test mode
  if (CONFIG.testMode) {
    payload.test_run = CONFIG.testMarker;
  }

  return payload;
}

// Send the request
function sendToSelene() {
  const url = getWebhookURL();
  const payload = buildPayload();

  // Create HTTP request
  const http = HTTP.create();

  // Configure request
  const response = http.request({
    url: url,
    method: "POST",
    headers: {
      "Content-Type": "application/json"
    },
    data: payload
  });

  return {
    success: response.success,
    statusCode: response.statusCode,
    responseText: response.responseText,
    error: response.error
  };
}

// Health check function (optional, for testing connectivity)
function checkHealth() {
  let baseURL;

  switch(CONFIG.network) {
    case "mac":
      baseURL = `http://localhost:${CONFIG.port}`;
      break;
    case "tailscale":
      baseURL = `http://${CONFIG.tailscaleIP}:${CONFIG.port}`;
      break;
    case "local":
    default:
      baseURL = `http://${CONFIG.localIP}:${CONFIG.port}`;
  }

  const http = HTTP.create();
  const response = http.request({
    url: baseURL + "/healthz",
    method: "GET"
  });

  return response;
}

// Main execution
try {
  // Optional: Uncomment to test connection first
  // const health = checkHealth();
  // if (!health.success) {
  //   alert("Connection Failed", "Cannot reach n8n server. Check that:\n1. n8n is running\n2. You're on the correct network\n3. IP address is correct");
  //   context.fail();
  // }

  // Send the note
  const result = sendToSelene();

  if (result.success) {
    // Success!
    if (CONFIG.testMode) {
      app.displayInfoMessage("✓ Sent to Selene (TEST MODE)");
    } else {
      app.displayInfoMessage("✓ Sent to Selene");
    }

    // Optional: Archive the draft after successful send
    // draft.isArchived = true;
    // draft.update();

    context.cancel(); // Don't show success dialog, just the info message
  } else {
    // Error
    const errorMsg = result.error || `HTTP ${result.statusCode}: ${result.responseText}`;
    alert("Send Failed", `Could not send to Selene:\n\n${errorMsg}\n\nCheck the configuration and try again.`);
    context.fail();
  }

} catch (error) {
  alert("Error", `An error occurred:\n\n${error.message}`);
  context.fail();
}

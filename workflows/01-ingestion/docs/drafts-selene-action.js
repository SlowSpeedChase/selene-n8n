// Selene - Send Note to n8n
// Simplified version: Just sends the draft to n8n, nothing else
//
// CONFIGURATION: Update this URL with your n8n webhook

const WEBHOOK_URL = "http://192.168.1.26:5678/webhook/api/drafts";

// Main execution
try {
  // Build the payload
  const payload = {
    title: draft.title || "Untitled",
    content: draft.content,
    created_at: draft.createdAt.toISOString(),
    source_type: "drafts",
    source_uuid: draft.uuid
  };

  // Send to n8n
  const http = HTTP.create();
  const response = http.request({
    url: WEBHOOK_URL,
    method: "POST",
    headers: {
      "Content-Type": "application/json"
    },
    data: payload
  });

  // Handle response
  if (response.success) {
    app.displayInfoMessage("✓ Sent to Selene");
    context.cancel();
  } else {
    const errorMsg = response.error || `HTTP ${response.statusCode}`;
    alert("Send Failed", `Could not send to Selene:\n${errorMsg}`);
    context.fail();
  }

} catch (error) {
  alert("Error", error.message);
  context.fail();
}

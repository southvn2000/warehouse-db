const messagesEl = document.getElementById("messages");
const queryInputEl = document.getElementById("queryInput");
const sendBtnEl = document.getElementById("sendBtn");
const clearBtnEl = document.getElementById("clearBtn");
const llmBtnEl = document.getElementById("llmBtn");
const llmDialogEl = document.getElementById("llmDialog");
const llmFormEl = document.getElementById("llmForm");
const cancelLlmBtnEl = document.getElementById("cancelLlmBtn");
const llmStatusEl = document.getElementById("llmStatus");
const messageTemplate = document.getElementById("messageTemplate");
const deepExplainToggleEl = document.getElementById("deepExplainToggle");
const testLlmBtnEl = document.getElementById("testLlmBtn");
const llmTestStatusEl = document.getElementById("llmTestStatus");

const SESSION_KEY = "sql_rag_session_id";
const LLM_KEY = "sql_rag_llm_config";
const DEEP_EXPLAIN_KEY = "sql_rag_deep_explain";

const providerSelectEl = document.getElementById("providerSelect");
const llmEnabledEl = document.getElementById("llmEnabled");
const baseUrlInputEl = document.getElementById("baseUrlInput");
const modelInputEl = document.getElementById("modelInput");
const apiKeyInputEl = document.getElementById("apiKeyInput");
const timeoutInputEl = document.getElementById("timeoutInput");

let sessionId = localStorage.getItem(SESSION_KEY) || "";
let llmConfig = JSON.parse(localStorage.getItem(LLM_KEY) || "null") || {
  enabled: false,
  provider: "copilot",
  base_url: "https://models.inference.ai.azure.com/v1",
  model: "gpt-4o-mini",
  api_key: "",
  timeout_seconds: 45,
};
let deepExplainEnabled = localStorage.getItem(DEEP_EXPLAIN_KEY);
if (deepExplainEnabled === null) {
  deepExplainEnabled = "true";
}
deepExplainEnabled = deepExplainEnabled === "true";
let presets = [];

function addMessage(role, text) {
  const node = messageTemplate.content.firstElementChild.cloneNode(true);
  node.classList.add(role);
  node.querySelector(".role").textContent = role === "user" ? "You" : "SQL RAG";
  node.querySelector(".bubble").textContent = text;
  messagesEl.appendChild(node);
  messagesEl.scrollTop = messagesEl.scrollHeight;
  return node;
}

function setLoadingState(loading) {
  sendBtnEl.disabled = loading;
  sendBtnEl.textContent = loading ? "Thinking..." : "Send";
}

function getOrCreateSessionId(incoming) {
  const next = incoming || sessionId || (window.crypto?.randomUUID?.() || `${Date.now()}`);
  sessionId = next;
  localStorage.setItem(SESSION_KEY, next);
  return next;
}

function appendSourcesToMessage(node, sources = []) {
  if (!node || !Array.isArray(sources) || sources.length === 0) return;
  const sourcesWrap = document.createElement("div");
  sourcesWrap.className = "sources";
  sources.slice(0, 5).forEach((s, idx) => {
    const item = document.createElement("div");
    item.className = "source-item";
    const title = document.createElement("div");
    title.className = "source-title";
    title.textContent = `${idx + 1}. ${s.object_name} (${s.object_type})`;
    const path = document.createElement("div");
    path.className = "source-path";
    path.textContent = s.path;
    item.appendChild(title);
    item.appendChild(path);
    sourcesWrap.appendChild(item);
  });
  node.appendChild(sourcesWrap);
}

function appendLlmUsageToMessage(node, llmMeta, deepExplain) {
  if (!node || !llmMeta) return;
  const roleEl = node.querySelector(".role");
  if (!roleEl) return;

  const deepPart = ` | Deep Explain: ${deepExplain ? "ON" : "OFF"}`;

  if (llmMeta.used) {
    const modelPart = llmMeta.model ? ` / ${llmMeta.model}` : "";
    roleEl.textContent = `SQL RAG - External LLM${modelPart}${deepPart}`;
  } else {
    roleEl.textContent = `SQL RAG - Built-in grounded${deepPart}`;
  }
}

function renderCurrentLlmStatusWithRuntime(llmMeta) {
  if (!llmStatusEl) return;
  if (!llmMeta) {
    renderCurrentLlmStatus();
    return;
  }

  if (llmMeta.used) {
    const label = findPresetLabel(llmConfig.provider);
    const model = llmMeta.model || llmConfig.model || "(no model)";
    llmStatusEl.textContent = `Current LLM: ${label} - ${model} (working)`;
  } else if (llmConfig.enabled) {
    llmStatusEl.textContent = "Current LLM: Built-in grounded mode (fallback active)";
  } else {
    llmStatusEl.textContent = "Current LLM: Built-in grounded mode";
  }
}

async function loadPresets() {
  try {
    const resp = await fetch("/llm/presets");
    const data = await resp.json();
    presets = data.presets || [];
  } catch {
    presets = [];
  }

  providerSelectEl.innerHTML = "";
  presets.forEach((p) => {
    const opt = document.createElement("option");
    opt.value = p.id;
    opt.textContent = p.label;
    providerSelectEl.appendChild(opt);
  });
  const customOpt = document.createElement("option");
  customOpt.value = "custom";
  customOpt.textContent = "Custom";
  providerSelectEl.appendChild(customOpt);
}

function saveLocalLlmConfig() {
  localStorage.setItem(LLM_KEY, JSON.stringify(llmConfig));
}

function findPresetLabel(providerId) {
  const preset = presets.find((p) => p.id === providerId);
  return preset ? preset.label : "Custom";
}

function renderCurrentLlmStatus() {
  if (!llmStatusEl) return;
  if (!llmConfig.enabled) {
    llmStatusEl.textContent = "Current LLM: Built-in grounded mode";
    return;
  }

  const label = findPresetLabel(llmConfig.provider);
  const model = llmConfig.model || "(no model)";
  llmStatusEl.textContent = `Current LLM: ${label} - ${model}`;
}

function applyPreset(providerId) {
  const preset = presets.find((p) => p.id === providerId);
  if (!preset) return;
  llmConfig.provider = preset.id;
  llmConfig.base_url = preset.base_url || llmConfig.base_url;
  llmConfig.model = preset.model || llmConfig.model;
  llmConfig.timeout_seconds = Number(preset.timeout_seconds || llmConfig.timeout_seconds || 45);
}

function syncDialogFromConfig() {
  llmEnabledEl.checked = !!llmConfig.enabled;
  providerSelectEl.value = llmConfig.provider || "custom";
  baseUrlInputEl.value = llmConfig.base_url || "";
  modelInputEl.value = llmConfig.model || "";
  apiKeyInputEl.value = llmConfig.api_key || "";
  timeoutInputEl.value = String(llmConfig.timeout_seconds || 45);
}

function syncConfigFromDialog() {
  llmConfig = {
    enabled: llmEnabledEl.checked,
    provider: providerSelectEl.value,
    base_url: baseUrlInputEl.value.trim(),
    model: modelInputEl.value.trim(),
    api_key: apiKeyInputEl.value.trim(),
    timeout_seconds: Number(timeoutInputEl.value || "45"),
  };
  saveLocalLlmConfig();
}

function setLlmTestStatus(text, level = "info") {
  if (!llmTestStatusEl) return;
  llmTestStatusEl.classList.remove("status-info", "status-success", "status-warn", "status-error");
  llmTestStatusEl.classList.add(`status-${level}`);
  llmTestStatusEl.textContent = text;
}

async function runLlmConnectionTest() {
  if (!testLlmBtnEl) return;

  syncConfigFromDialog();

  if (!llmConfig.enabled) {
    setLlmTestStatus("Enable external LLM first.", "warn");
    return;
  }

  testLlmBtnEl.disabled = true;
  setLlmTestStatus("Testing...", "info");

  try {
    const sid = getOrCreateSessionId();
    const resp = await fetch("/ask", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        session_id: sid,
        query: "connection test for llm grounding",
        k: 2,
        llm: llmConfig,
        deep_explain: false,
      }),
    });

    if (!resp.ok) {
      setLlmTestStatus(`Test failed (${resp.status}).`, "error");
      return;
    }

    const data = await resp.json();
    if (data?.llm?.used) {
      const model = data.llm.model || llmConfig.model || "(no model)";
      setLlmTestStatus(`Connected: external LLM active (${model}).`, "success");
    } else {
      const reason = data?.llm?.error ? ` Reason: ${data.llm.error}` : "";
      setLlmTestStatus(`Connected, but fallback mode used. Check API key/model/base URL.${reason}`, "warn");
    }
  } catch {
    setLlmTestStatus("Test failed: cannot reach /ask endpoint.", "error");
  } finally {
    testLlmBtnEl.disabled = false;
  }
}

async function pushSessionLlmConfig() {
  const sid = getOrCreateSessionId();
  await fetch("/session/llm-config", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ session_id: sid, llm: llmConfig }),
  });
}

async function loadSessionLlmConfig() {
  const sid = getOrCreateSessionId();
  try {
    const resp = await fetch(`/session/llm-config?session_id=${encodeURIComponent(sid)}`);
    if (!resp.ok) return;
    const data = await resp.json();
    if (!data || !data.llm) return;

    const fromServer = data.llm;
    llmConfig = {
      ...llmConfig,
      enabled: !!fromServer.enabled,
      provider: fromServer.provider || llmConfig.provider,
      base_url: fromServer.base_url || llmConfig.base_url,
      model: fromServer.model || llmConfig.model,
      timeout_seconds: Number(fromServer.timeout_seconds || llmConfig.timeout_seconds || 45),
      api_key: llmConfig.api_key || "",
    };
    saveLocalLlmConfig();
  } catch {
    // Ignore if session config is unavailable.
  }
}

function streamAskQuery(query, deepExplain, onDelta, onDone, onError) {
  const sid = getOrCreateSessionId();
  const streamUrl = `/ask/stream?q=${encodeURIComponent(query)}&k=5&session_id=${encodeURIComponent(sid)}&deep_explain=${deepExplain ? "true" : "false"}`;
  const es = new EventSource(streamUrl);

  es.addEventListener("session", (event) => {
    try {
      const payload = JSON.parse(event.data);
      if (payload.session_id) getOrCreateSessionId(payload.session_id);
    } catch {
      // Ignore session event parse issues.
    }
  });

  es.addEventListener("delta", (event) => {
    try {
      const payload = JSON.parse(event.data);
      onDelta(payload.text || "");
    } catch {
      onDelta("");
    }
  });

  es.addEventListener("done", (event) => {
    try {
      const payload = JSON.parse(event.data);
      if (payload.session_id) getOrCreateSessionId(payload.session_id);
      onDone(payload);
    } catch (err) {
      onError(err);
    } finally {
      es.close();
    }
  });

  es.onerror = () => {
    es.close();
    onError(new Error("stream disconnected"));
  };
}

async function handleSend() {
  const query = queryInputEl.value.trim();
  if (!query) return;

  addMessage("user", query);
  queryInputEl.value = "";
  setLoadingState(true);
  const assistantNode = addMessage("assistant", "");
  const assistantBubble = assistantNode.querySelector(".bubble");

  try {
    if (llmConfig.enabled) {
      await pushSessionLlmConfig();
    }
    await new Promise((resolve, reject) => {
      streamAskQuery(
        query,
        deepExplainEnabled,
        (partialText) => {
          assistantBubble.textContent = partialText || "";
          messagesEl.scrollTop = messagesEl.scrollHeight;
        },
        (data) => {
          assistantBubble.textContent = data.answer || "No answer generated.";
          appendLlmUsageToMessage(assistantNode, data.llm, !!data.deep_explain);
          renderCurrentLlmStatusWithRuntime(data.llm);
          appendSourcesToMessage(assistantNode, data.sources || []);
          resolve();
        },
        reject
      );
    });
  } catch (err) {
    assistantBubble.textContent = `Request failed: ${err.message}`;
  } finally {
    setLoadingState(false);
    queryInputEl.focus();
  }
}

sendBtnEl.addEventListener("click", handleSend);

clearBtnEl.addEventListener("click", async () => {
  const sid = getOrCreateSessionId();
  try {
    await fetch("/session/clear", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ session_id: sid }),
    });
  } catch {
    // Ignore API failures and clear UI anyway.
  }
  llmConfig.enabled = false;
  saveLocalLlmConfig();
  renderCurrentLlmStatus();
  messagesEl.innerHTML = "";
  addMessage("assistant", "Session cleared. Ask a new question about SQL objects in this repository.");
});

if (deepExplainToggleEl) {
  deepExplainToggleEl.checked = deepExplainEnabled;
  deepExplainToggleEl.addEventListener("change", () => {
    deepExplainEnabled = !!deepExplainToggleEl.checked;
    localStorage.setItem(DEEP_EXPLAIN_KEY, deepExplainEnabled ? "true" : "false");
  });
}

llmBtnEl.addEventListener("click", () => {
  syncDialogFromConfig();
  setLlmTestStatus("");
  llmDialogEl.showModal();
});

cancelLlmBtnEl.addEventListener("click", () => {
  setLlmTestStatus("");
  llmDialogEl.close();
});

if (testLlmBtnEl) {
  testLlmBtnEl.addEventListener("click", runLlmConnectionTest);
}

providerSelectEl.addEventListener("change", () => {
  applyPreset(providerSelectEl.value);
  syncDialogFromConfig();
});

llmFormEl.addEventListener("submit", async (event) => {
  event.preventDefault();
  syncConfigFromDialog();
  renderCurrentLlmStatus();
  setLlmTestStatus("");
  llmDialogEl.close();
  if (llmConfig.enabled) {
    try {
      await pushSessionLlmConfig();
      addMessage("assistant", `LLM config saved (${llmConfig.provider || "custom"}).`);
    } catch {
      addMessage("assistant", "LLM config saved locally. Server sync failed; it will retry on next message.");
    }
  } else {
    addMessage("assistant", "External LLM disabled. Using built-in deterministic grounded answers.");
  }
});

queryInputEl.addEventListener("keydown", (event) => {
  if (event.key === "Enter" && !event.shiftKey) {
    event.preventDefault();
    handleSend();
  }
});

(async () => {
  await loadPresets();
  await loadSessionLlmConfig();
  syncDialogFromConfig();
  renderCurrentLlmStatus();
  addMessage(
    "assistant",
    "Ask me anything about procedures, tables, functions, or workflows. Use LLM Settings for Copilot or Ollama presets."
  );
  queryInputEl.focus();
})();

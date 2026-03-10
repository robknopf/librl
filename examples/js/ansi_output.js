export function ensureOutputElement(outputId = "output") {
  const current = document.getElementById(outputId);
  if (!current) {
    const pre = document.createElement("pre");
    pre.id = outputId;
    document.body.appendChild(pre);
    return pre;
  }
  if (current.tagName === "TEXTAREA") {
    const pre = document.createElement("pre");
    pre.id = outputId;
    pre.className = current.className;
    current.parentNode.replaceChild(pre, current);
    return pre;
  }
  return current;
}

function ansiColorToCss(code) {
  const map = {
    30: "#111111",
    31: "#c62828",
    32: "#2e7d32",
    33: "#f9a825",
    34: "#1565c0",
    35: "#8e24aa",
    36: "#00838f",
    37: "#e0e0e0",
    90: "#616161",
    91: "#ef5350",
    92: "#66bb6a",
    93: "#ffee58",
    94: "#42a5f5",
    95: "#ba68c8",
    96: "#4dd0e1",
    97: "#ffffff",
  };
  return map[code] || null;
}

export function appendAnsiLine(output, text) {
  const line = document.createElement("div");
  const ansi = /\x1b\[([0-9;]*)m/g;
  const state = { color: null, bold: false };
  let cursor = 0;
  let match;

  const appendChunk = (chunk) => {
    if (!chunk) return;
    const span = document.createElement("span");
    span.textContent = chunk;
    if (state.color) span.style.color = state.color;
    if (state.bold) span.style.fontWeight = "700";
    line.appendChild(span);
  };

  while ((match = ansi.exec(text)) !== null) {
    appendChunk(text.slice(cursor, match.index));
    const codes = (match[1] || "0").split(";").map((n) => parseInt(n, 10));
    for (const code of codes) {
      if (Number.isNaN(code) || code === 0) {
        state.color = null;
        state.bold = false;
      } else if (code === 1) {
        state.bold = true;
      } else {
        const color = ansiColorToCss(code);
        if (color) state.color = color;
      }
    }
    cursor = ansi.lastIndex;
  }
  appendChunk(text.slice(cursor));

  output.appendChild(line);
  output.scrollTop = output.scrollHeight;
}

export function createOutputLogger(output) {
  return (...args) => {
    const line = args.length > 1 ? args.join(" ") : String(args[0] ?? "");
    appendAnsiLine(output, line);
  };
}

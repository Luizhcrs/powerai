#!/usr/bin/env python3
import sys
import re
import json

def parse():
    raw = sys.stdin.read().strip()
    if not raw:
        return "", ""

    # 1. Unpack outer API wrapper (Ollama / OpenAI format)
    content = ""
    try:
        data = json.loads(raw)
        if isinstance(data, dict):
            if "choices" in data and len(data["choices"]) > 0:
                content = data["choices"][0].get("message", {}).get("content", "")
            elif "message" in data:
                content = data["message"].get("content", "")
    except Exception:
        pass

    target = content if content else raw

    # 2. Direct JSON parse
    try:
        data = json.loads(target)
        if isinstance(data, dict) and ("suggested_command" in data or "explanation" in data):
            cmd = str(data.get("suggested_command") or "").strip()
            exp = str(data.get("explanation") or "").strip()
            if cmd not in ("null", "None", "undefined", "json"):
                return cmd, exp
    except Exception:
        pass

    # 3. Extract inside markdown ```json ... ``` codeblock
    m_code = re.search(r"```(?:json|bash|sh|zsh)?\s*(\{.*?\})\s*```", target, re.DOTALL)
    if m_code:
        try:
            data = json.loads(m_code.group(1))
            if isinstance(data, dict):
                cmd = str(data.get("suggested_command") or "").strip()
                exp = str(data.get("explanation") or "").strip()
                if cmd not in ("null", "None", "undefined", "json"):
                    return cmd, exp
        except Exception:
            pass

    # 4. Extract outermost JSON { ... }
    first_brace = target.find("{")
    last_brace = target.rfind("}")
    if first_brace != -1 and last_brace != -1 and last_brace > first_brace:
        candidate = target[first_brace:last_brace + 1]
        try:
            data = json.loads(candidate)
            if isinstance(data, dict):
                cmd = str(data.get("suggested_command") or "").strip()
                exp = str(data.get("explanation") or "").strip()
                if cmd not in ("null", "None", "undefined", "json"):
                    return cmd, exp
        except Exception:
            pass

    # 5. Regex Fallback
    cmd = ""
    exp = ""
    m_cmd = re.search(r'["\']suggested_command["\']\s*:\s*"([^"\\]*(?:\\.[^"\\]*)*)"', target)
    if m_cmd:
        cmd = m_cmd.group(1).encode().decode('unicode_escape', 'ignore')

    m_exp = re.search(r'["\']explanation["\']\s*:\s*"([^"\\]*(?:\\.[^"\\]*)*)"', target)
    if m_exp:
        exp = m_exp.group(1).encode().decode('unicode_escape', 'ignore')

    # 6. Raw Codeblock fallback
    if not cmd:
        m_raw = re.search(r"```(?:bash|sh|zsh)?\s*\n([^`]+)```", target)
        if m_raw:
            lines = [l.strip() for l in m_raw.group(1).splitlines() if l.strip() and not l.strip().startswith("#") and not l.strip().startswith("{") and l.strip() != "json"]
            if lines:
                cmd = lines[0]

    if cmd in ("null", "None", "undefined", "json"):
        cmd = ""

    return cmd.strip(), exp.strip()

if __name__ == "__main__":
    c, e = parse()
    print(f"{c}\t{e}")

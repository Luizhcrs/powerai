#!/usr/bin/env python3
import sys
import re
import json

def parse():
    raw = sys.stdin.read().strip()
    if not raw:
        return "", ""

    cmd = ""
    exp = ""

    # 1. Try unpacking outer JSON
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

    target_text = content if content else raw

    # 2. Search for embedded JSON object { ... }
    m_json = re.search(r'\{[^{}]*\"suggested_command\"[^{}]*\}', target_text, re.DOTALL)
    if not m_json:
        m_json = re.search(r'\{[^{}]*\}', target_text, re.DOTALL)

    if m_json:
        try:
            cj = json.loads(m_json.group(0))
            if isinstance(cj, dict):
                cmd = str(cj.get("suggested_command") or "")
                exp = str(cj.get("explanation") or "")
        except Exception:
            pass

    # 3. Key-Value Regex Fallback
    if not cmd:
        m = re.search(r'[\"\'\`]?suggested_command[\"\'\`]?\s*[:=]\s*[\"\'\`]?([^\"\'\`\n\r{}]+)', target_text)
        if m:
            cmd = m.group(1).strip()

    if not exp:
        m = re.search(r'[\"\'\`]?explanation[\"\'\`]?\s*[:=]\s*[\"\'\`]?([^\"\'\`\n\r{}]+)', target_text)
        if m:
            exp = m.group(1).strip()

    # 4. Code Block Fallback
    if not cmd:
        m = re.search(r'```(?:bash|sh|zsh)?\s*\n([^`]+)```', target_text)
        if m:
            lines = [l.strip() for l in m.group(1).splitlines() if l.strip() and not l.strip().startswith('#') and not l.strip().startswith('{') and l.strip() != 'json']
            if lines:
                cmd = lines[0]

    if cmd in ("null", "None", "undefined", "json"):
        cmd = ""

    # Cleanup trailing quotes/punctuation
    cmd = re.sub(r'["\'`},]+$', '', cmd).strip()
    exp = re.sub(r'["\'`},]+$', '', exp).strip()

    return cmd, exp

if __name__ == "__main__":
    c, e = parse()
    print(f"{c}\t{e}")

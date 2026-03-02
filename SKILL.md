---
name: sigaa
description: Interact with SIGAA (Sistema Integrado de Gestão de Atividades Acadêmicas), the academic management system used by 50+ Brazilian federal universities (UNB, UFRN, UFC, UFPE, UFCG, UFPI, etc.). Use when: (1) checking enrollment status or classes for students, (2) verifying grades or academic history, (3) accessing professor portal (classes, attendance, grade launch), (4) logging in to any SIGAA instance via CAS SSO or direct authentication, (5) automating any SIGAA task via web scraping with curl/Python. Handles both undergrad and graduate (stricto/lato sensu) portals.
---

# SIGAA Skill

SIGAA is a JSF-based web system with no public REST API. All automation uses authenticated web scraping (curl + Python/bash).

## Quick Start

### 1. Login

```bash
source scripts/sigaa_login.sh "https://sigaa.unb.br" "<username>" "<password>"
# Sets: $SIGAA_COOKIE_FILE, $SIGAA_USER_ID, $SIGAA_BASE_URL
```

For institution-specific URLs and username formats → see `references/institutions.md`

### 2. Student Operations

```bash
bash scripts/sigaa_student.sh status             # Basic info + active program
bash scripts/sigaa_student.sh enrollments        # Current semester classes
bash scripts/sigaa_student.sh enrollment-result  # Status of enrollment requests
bash scripts/sigaa_student.sh grades             # Grades
bash scripts/sigaa_student.sh history            # Full academic history
bash scripts/sigaa_student.sh schedule           # Class schedule
```

### 3. Professor Operations

```bash
bash scripts/sigaa_professor.sh classes              # Current semester classes
bash scripts/sigaa_professor.sh students <turma_id>  # Students in a class
bash scripts/sigaa_professor.sh attendance           # Pending attendance
bash scripts/sigaa_professor.sh schedule             # Teaching schedule
```

## JSF Navigation Pattern

All menu navigation uses POST with `jscook_action`:

```bash
# Get fresh ViewState from portal page first
VS=$(curl -s -b "$SIGAA_COOKIE_FILE" -c "$SIGAA_COOKIE_FILE" \
  "${SIGAA_BASE_URL}/sigaa/portais/discente/discente.jsf" | \
  grep -oP 'name="javax\.faces\.ViewState"[^>]*value="\K[^"]+' | head -1)

curl -s -L -b "$SIGAA_COOKIE_FILE" -c "$SIGAA_COOKIE_FILE" \
  -X POST "${SIGAA_BASE_URL}/sigaa/portais/discente/discente.jsf" \
  -d "menu%3Aform_menu_discente=menu%3Aform_menu_discente" \
  -d "id=${SIGAA_USER_ID}" \
  --data-urlencode "jscook_action=menu_form_menu_discente_discente_menu:A]#{BEAN.method}" \
  --data-urlencode "javax.faces.ViewState=${VS}"
```

For full list of actions → `references/student-guide.md` and `references/professor-guide.md`

## Parsing Responses

```python
import re, html as h

def clean_html(content):
    content = re.sub(r'<script[^>]*>.*?</script>', '', content, flags=re.DOTALL)
    content = re.sub(r'<style[^>]*>.*?</style>', '', content, flags=re.DOTALL)
    text = re.sub(r'<[^>]+>', ' ', content)
    return h.unescape(re.sub(r'[ \t]+', ' ', text))

def extract_table_rows(html_content):
    content = re.sub(r'<script[^>]*>.*?</script>', '', html_content, flags=re.DOTALL)
    rows = re.findall(r'<tr[^>]*>(.*?)</tr>', content, re.DOTALL)
    result = []
    for row in rows:
        cells = re.findall(r'<t[dh][^>]*>(.*?)</t[dh]>', row, re.DOTALL)
        clean = [h.unescape(re.sub(r'<[^>]+>|\s+', ' ', c)).strip() for c in cells if c.strip()]
        if clean:
            result.append(clean)
    return result
```

## Security Guidelines

- **Never log or display passwords** in plaintext in tool outputs, files, or memory
- **Use 1Password** (`op item get`) to retrieve credentials — never hardcode them
- **Cookie files** are temporary session tokens; store in `/tmp/sigaa_session_<pid>.txt` and delete after use
- **Rate limiting**: add `sleep 0.5` between requests to avoid IP blocks or account lockouts
- **Credential storage**: update 1Password with correct username format after first successful login
- **Session scope**: SIGAA sessions expire after ~20 minutes of inactivity; re-login if you get a redirect back to the login page
- **No public data exfiltration**: grades, enrollment, and student data are personal — only share with the authenticated user

## Common Issues

| Symptom | Fix |
|---------|-----|
| "Credenciais inválidas" | Try matricula number (not CPF); check 1Password item |
| "Nenhuma turma neste semestre" | Run `enrollment-result` — status may be SUBMETIDA |
| JSF POST returns portal (no navigation) | ViewState stale — re-fetch portal page before POST |
| Session redirect to login | Cookie expired — run `sigaa_login.sh` again |
| "Você não pode tentar re-enviar" | Reused old LT token — always fetch fresh login page |

## References

- `references/institutions.md` — All supported institutions, login URLs, username formats
- `references/student-guide.md` — Full student portal guide, JSF actions, parsing tips
- `references/professor-guide.md` — Professor portal, grade/attendance workflows

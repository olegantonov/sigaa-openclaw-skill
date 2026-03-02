#!/usr/bin/env bash
# sigaa_professor.sh - Professor portal operations for SIGAA
# Requires: $SIGAA_COOKIE_FILE, $SIGAA_USER_ID, $SIGAA_BASE_URL (from sigaa_login.sh)
#
# Usage: sigaa_professor.sh <action>
#
# Actions:
#   classes           - List current semester classes (turmas)
#   students <turma>  - List students in a class (requires turma ID)
#   attendance        - Show pending attendance entries
#   schedule          - Show professor teaching schedule

set -euo pipefail

AGENT="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36"

_get() {
  curl -s -L -c "$SIGAA_COOKIE_FILE" -b "$SIGAA_COOKIE_FILE" \
    -A "$AGENT" "$1"
}

_post_menu() {
  local action="$1"
  local html
  html=$(curl -s -c "$SIGAA_COOKIE_FILE" -b "$SIGAA_COOKIE_FILE" \
    -A "$AGENT" "${SIGAA_BASE_URL}/sigaa/verPortalDocente.do")
  local vs
  vs=$(echo "$html" | grep -oP 'name="javax\.faces\.ViewState"[^>]*value="\K[^"]+' | head -1)

  curl -s -L -c "$SIGAA_COOKIE_FILE" -b "$SIGAA_COOKIE_FILE" \
    -A "$AGENT" \
    -X POST "${SIGAA_BASE_URL}/sigaa/verPortalDocente.do" \
    -d "menu%3Aform_menu_docente=menu%3Aform_menu_docente" \
    -d "id=${SIGAA_USER_ID}" \
    --data-urlencode "jscook_action=${action}" \
    --data-urlencode "javax.faces.ViewState=${vs}"
}

_extract_table() {
  python3 -c "
import sys, re, html as h
content = sys.stdin.read()
content = re.sub(r'<script[^>]*>.*?</script>', '', content, flags=re.DOTALL)
content = re.sub(r'<style[^>]*>.*?</style>', '', content, flags=re.DOTALL)
rows = re.findall(r'<tr[^>]*>(.*?)</tr>', content, re.DOTALL)
for row in rows:
    cells = re.findall(r'<t[dh][^>]*>(.*?)</t[dh]>', row, re.DOTALL)
    if cells:
        clean = [re.sub(r'<[^>]+>', '', c).strip() for c in cells]
        clean = [h.unescape(re.sub(r'\s+', ' ', c)).strip() for c in clean]
        clean = [c for c in clean if c]
        if clean:
            print('\t'.join(clean))
"
}

action_classes() {
  echo "=== Turmas do Docente ==="
  local html
  html=$(_get "${SIGAA_BASE_URL}/sigaa/verPortalDocente.do")

  echo "$html" | python3 -c "
import sys, re, html as h
text = sys.stdin.read()
m = re.search(r'(turmas?.*?)(?:Pesquisa|Extens|$)', text, re.DOTALL | re.IGNORECASE)
if m:
    block = re.sub(r'<[^>]+>', ' ', m.group(1))
    block = h.unescape(re.sub(r'[ \t]+', ' ', block))
    for line in block.split('\n'):
        line = line.strip()
        if line and len(line) > 5:
            print(line)
" | head -40
}

action_students() {
  local turma_id="${1:-}"
  if [[ -z "$turma_id" ]]; then
    echo "Usage: sigaa_professor.sh students <turma_id>" >&2
    exit 1
  fi
  echo "=== Alunos da Turma $turma_id ==="
  local html
  html=$(_get "${SIGAA_BASE_URL}/sigaa/graduacao/turma/discente/lista.jsf?id=${turma_id}")
  echo "$html" | _extract_table | head -80
}

action_attendance() {
  echo "=== Frequência Pendente ==="
  local html
  html=$(_post_menu "menu_form_menu_docente_docente_menu:A]#{frequenciaAluno.listarTurmasComFrequenciaPendente}")
  echo "$html" | _extract_table | head -40
}

action_schedule() {
  echo "=== Grade de Horários ==="
  local html
  html=$(_post_menu "menu_form_menu_docente_docente_menu:A]#{horarioDocente.visualizarHorario}")
  echo "$html" | _extract_table | head -40
}

ACTION="${1:-classes}"
shift || true

case "$ACTION" in
  classes)    action_classes ;;
  students)   action_students "$@" ;;
  attendance) action_attendance ;;
  schedule)   action_schedule ;;
  *)
    echo "Unknown action: $ACTION" >&2
    echo "Available: classes, students, attendance, schedule" >&2
    exit 1
    ;;
esac

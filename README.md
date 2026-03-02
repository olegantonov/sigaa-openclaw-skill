# SIGAA OpenClaw Skill

An OpenClaw agent skill for interacting with **SIGAA** (Sistema Integrado de Gestão de Atividades Acadêmicas), the academic management system used by 50+ Brazilian federal universities and institutes.

## Features

- 🔐 **Authentication**: Supports both CAS SSO (UNB-style) and direct login
- 🎓 **Student Portal**: Enrollment status, grades, academic history, class schedule
- 👨‍🏫 **Professor Portal**: Class management, attendance, grade entry
- 🏛️ **Multi-institution**: Works with UNB, UFRN, UFC, UFPE, UFCG, UFPI, UFRRJ, and 40+ more
- 🔒 **Security-first**: Credentials via 1Password, no hardcoded secrets, session cleanup

## Supported Institutions

50+ Brazilian federal universities including:
- UNB (Universidade de Brasília)
- UFRN (Universidade Federal do Rio Grande do Norte — original SIGAA developer)
- UFC (Universidade Federal do Ceará)
- UFPE (Universidade Federal de Pernambuco)
- UFCG (Universidade Federal de Campina Grande)
- UFPI (Universidade Federal do Piauí)
- UFRRJ, UFBA, UFPA, UFPB, and many more

## Installation

```bash
clawhub install sigaa
```

## Usage Examples

```bash
# Login
source scripts/sigaa_login.sh "https://sigaa.unb.br" "241104251" "mypassword"

# Check enrollments
bash scripts/sigaa_student.sh enrollment-result

# Check grades
bash scripts/sigaa_student.sh grades

# Professor: list classes
bash scripts/sigaa_professor.sh classes
```

## Security

- Always retrieve credentials via 1Password (`op item get`)
- Session cookies stored in `/tmp` — automatically scoped to process
- No credentials ever logged or written to disk
- Rate limiting built in to avoid account lockouts

## License

MIT

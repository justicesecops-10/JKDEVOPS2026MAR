#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
#  Day 3: Shell Scripting for DevOps
#  setup-env.sh — Automate project environment setup
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail  # exit on error, undefined vars, pipe failures

# ── Colors ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

log()  { echo -e "${CYAN}[INFO]${NC}  $1"; }
ok()   { echo -e "${GREEN}[OK]${NC}    $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC}  $1"; }
fail() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# ── Check required tools ──────────────────────────────────────────────────────
log "Checking required tools..."

for tool in git docker terraform; do
  if command -v "$tool" &>/dev/null; then
    ok "$tool found: $(command -v $tool)"
  else
    warn "$tool NOT found — attempting install..."
    case "$tool" in
      docker)
        sudo yum install -y docker 2>/dev/null \
          || sudo apt-get install -y docker.io 2>/dev/null \
          || fail "Could not install docker"
        sudo systemctl start docker
        sudo usermod -aG docker "$USER"
        ;;
      terraform)
        warn "Install Terraform manually: https://developer.hashicorp.com/terraform/install"
        ;;
      git)
        sudo yum install -y git 2>/dev/null \
          || sudo apt-get install -y git 2>/dev/null \
          || fail "Could not install git"
        ;;
    esac
  fi
done

# ── Set up Git config (Day 3/4) ───────────────────────────────────────────────
log "Configuring Git..."
read -rp "Enter your Git username: " GIT_USER
read -rp "Enter your Git email: " GIT_EMAIL

git config --global user.name  "$GIT_USER"
git config --global user.email "$GIT_EMAIL"
git config --global init.defaultBranch main
ok "Git configured for $GIT_USER <$GIT_EMAIL>"

# ── Create project directory structure ───────────────────────────────────────
log "Setting up project structure..."

PROJECT_DIR="$HOME/devops-project"
mkdir -p "$PROJECT_DIR"/{app,terraform,jenkins,scripts}

ok "Directory structure created at $PROJECT_DIR"
tree "$PROJECT_DIR" 2>/dev/null || find "$PROJECT_DIR" -type d | sed 's|[^/]*/|  |g'

# ── Set correct file permissions ──────────────────────────────────────────────
log "Setting file permissions..."
find "$PROJECT_DIR/scripts" -name "*.sh" -exec chmod +x {} \;
ok "Shell scripts made executable"

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}════════════════════════════════════════${NC}"
echo -e "${GREEN}  ✅  Environment setup complete!       ${NC}"
echo -e "${GREEN}════════════════════════════════════════${NC}"
echo ""
log "Next steps:"
echo "  1. cd $PROJECT_DIR"
echo "  2. git init && git remote add origin <your-repo-url>"
echo "  3. Configure AWS credentials: aws configure"
echo "  4. Set KEY_PAIR_NAME in Jenkinsfile & terraform/variables.tf"
echo "  5. Create Jenkins pipeline job pointing to Jenkinsfile"
echo ""

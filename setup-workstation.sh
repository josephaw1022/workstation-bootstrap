Generic home workstation setup script

#!/usr/bin/env bash
# Generic workstation setup. Pinned versions; installs or upgrades when the installed version differs.
# Usage: ./setup-workstation.sh [tool ...]   (no args = all tools). Override any pin via env, e.g. K9S_VERSION=0.52.0
set -uo pipefail

BIN_DIR="${BIN_DIR:-$HOME/.local/bin}"
MARK_DIR="$HOME/.local/share/setup-workstation"
mkdir -p "$BIN_DIR" "$MARK_DIR"
export PATH="$BIN_DIR:$PATH"

# Version pins (leading "v" optional)
: "${ACTIONLINT_VERSION:=1.7.12}" # renovate: datasource=github-releases depName=rhysd/actionlint
: "${AKS_NODE_VIEWER_VERSION:=0.0.2-alpha}" # renovate: datasource=github-releases depName=Azure/aks-node-viewer
: "${ARGOCD_VERSION:=v3.5.2}" # renovate: datasource=github-releases depName=argoproj/argo-cd
: "${CF_CLI_VERSION:=1.0.0-beta.28}" # renovate: datasource=npm depName=cf
: "${CHECK_JSONSCHEMA_VERSION:=0.38.2}" # renovate: datasource=pypi depName=check-jsonschema
: "${COPILOT_CLI_VERSION:=1.0.107}" # renovate: datasource=npm depName=@github/copilot
: "${EKS_NODE_VIEWER_VERSION:=0.7.4}" # renovate: datasource=github-releases depName=awslabs/eks-node-viewer
: "${FLARECTL_VERSION:=0.119.0}" # renovate: datasource=github-releases depName=cloudflare/cloudflare-go
: "${GH_VERSION:=2.103.3}" # renovate: datasource=github-releases depName=cli/cli
: "${GO_VERSION:=1.27.0}" # renovate: datasource=golang-version depName=go
: "${HELMPER_VERSION:=0.3.1}" # renovate: datasource=github-releases depName=ChristofferNissen/helmper
: "${HELM_VERSION:=v4.2.3}" # renovate: datasource=github-releases depName=helm/helm
: "${JIRA_CLI_VERSION:=1.7.0}" # renovate: datasource=github-releases depName=ankitpokhrel/jira-cli
: "${K9S_VERSION:=0.51.0}" # renovate: datasource=github-releases depName=derailed/k9s
: "${KARGO_VERSION:=1.12.5}" # renovate: datasource=github-releases depName=akuity/kargo
: "${KIND_VERSION:=0.33.0}" # renovate: datasource=github-releases depName=kubernetes-sigs/kind
: "${KUBECTL_VERSION:=v1.37.1}" # renovate: datasource=github-releases depName=kubernetes/kubernetes
: "${KUBECTX_VERSION:=0.11.0}" # renovate: datasource=github-releases depName=ahmetb/kubectx
: "${KYVERNO_CLI_VERSION:=v1.19.0}" # renovate: datasource=github-releases depName=kyverno/kyverno
: "${NETBIRD_VERSION:=0.80.0}" # renovate: datasource=github-releases depName=netbirdio/netbird
: "${NVM_VERSION:=v0.41.0}" # renovate: datasource=github-releases depName=nvm-sh/nvm
: "${ORAS_VERSION:=1.3.6}" # renovate: datasource=github-releases depName=oras-project/oras
: "${PUP_VERSION:=2.4.2}" # renovate: datasource=github-releases depName=DataDog/pup
: "${STERN_VERSION:=1.34.0}" # renovate: datasource=github-releases depName=stern/stern
: "${TASK_VERSION:=v3.54.0}" # renovate: datasource=github-releases depName=go-task/task
: "${TFLINT_VERSION:=0.65.0}" # renovate: datasource=github-releases depName=terraform-linters/tflint
: "${VAULT_VERSION:=2.2.1}" # renovate: datasource=github-releases depName=hashicorp/vault
: "${YAMLLINT_VERSION:=1.38.0}" # renovate: datasource=pypi depName=yamllint
: "${YQ_VERSION:=4.54.3}" # renovate: datasource=github-releases depName=mikefarah/yq

# Tool -> pinned version. Tools not listed (base, pip3, jq, aws-cli, azure-cli, helm-unittest, claws, psql, slack-cli, valkey-cli) are install-if-missing.
declare -A PIN=(
  [actionlint]=$ACTIONLINT_VERSION [aks-node-viewer]=$AKS_NODE_VIEWER_VERSION [argocd]=$ARGOCD_VERSION
  [cf-cli]=$CF_CLI_VERSION [check-jsonschema]=$CHECK_JSONSCHEMA_VERSION [gh-copilot-cli]=$COPILOT_CLI_VERSION
  [eks-node-viewer]=$EKS_NODE_VIEWER_VERSION [flarectl]=$FLARECTL_VERSION [gh]=$GH_VERSION [golang]=$GO_VERSION
  [helmper]=$HELMPER_VERSION [helm]=$HELM_VERSION [jira-cli]=$JIRA_CLI_VERSION [k9s]=$K9S_VERSION
  [kargo-cli]=$KARGO_VERSION [kind]=$KIND_VERSION [kubectl]=$KUBECTL_VERSION [kubectx]=$KUBECTX_VERSION
  [kyverno-cli]=$KYVERNO_CLI_VERSION [netbird]=$NETBIRD_VERSION [nvm]=$NVM_VERSION [oras]=$ORAS_VERSION
  [pup-cli]=$PUP_VERSION [stern]=$STERN_VERSION [task]=$TASK_VERSION [tflint]=$TFLINT_VERSION
  [vault]=$VAULT_VERSION [yamllint]=$YAMLLINT_VERSION [yq]=$YQ_VERSION
)

TOOLS_DEFAULT="base pip3 jq gh aws-cli azure-cli golang nvm gh-copilot-cli cf-cli kubectl helm helm-unittest k9s kind kubectx stern yq task argocd tflint vault actionlint aks-node-viewer eks-node-viewer check-jsonschema yamllint claws flarectl helmper jira-cli kargo-cli kyverno-cli netbird oras psql pup-cli slack-cli valkey-cli"
TOOLS="${*:-$TOOLS_DEFAULT}"

os="$(uname -s | tr '[:upper:]' '[:lower:]')"
case "$(uname -m)" in
  x86_64) arch=amd64; xarch=x86_64 ;;
  aarch64|arm64) arch=arm64; xarch=arm64 ;;
  *) echo "Unsupported arch: $(uname -m)" >&2; exit 1 ;;
esac

have() { command -v "$1" >/dev/null 2>&1; }
bare() { printf '%s' "${1#v}"; }

pkg_install() {
  if have brew; then brew install "$@"
  elif have dnf; then sudo dnf install -y "$@"
  elif have apt-get; then sudo apt-get update -y && sudo apt-get install -y "$@"
  else echo "No supported package manager" >&2; return 1; fi
}

# fetch_tar <url> <path-in-archive> <bin-name>
fetch_tar() {
  local tmp rc; tmp="$(mktemp -d)"
  curl -fsSL "$1" | tar -xz -C "$tmp" && install -m 0755 "$tmp/$2" "$BIN_DIR/$3"
  rc=$?; rm -rf "$tmp"; return $rc
}
# fetch_zip <url> <path-in-archive> <bin-name>
fetch_zip() {
  local tmp rc; tmp="$(mktemp -d)"
  curl -fsSL -o "$tmp/a.zip" "$1" && unzip -qo "$tmp/a.zip" -d "$tmp" && install -m 0755 "$tmp/$2" "$BIN_DIR/$3"
  rc=$?; rm -rf "$tmp"; return $rc
}
fetch_bin() { curl -fsSL -o "$BIN_DIR/$2" "$1" && chmod +x "$BIN_DIR/$2"; }

# Installed-version probes (print bare version, empty if missing)
marker() { have "$1" && cat "$MARK_DIR/$1" 2>/dev/null; }
ver_gh()       { gh --version 2>/dev/null | head -n1 | awk '{print $3}'; }
ver_golang()   { go version 2>/dev/null | awk '{print $3}' | sed 's/^go//'; }
ver_nvm()      { [ -s "$HOME/.nvm/nvm.sh" ] && (. "$HOME/.nvm/nvm.sh" >/dev/null 2>&1; nvm --version); }
ver_gh-copilot-cli() { npm ls -g @github/copilot --depth=0 2>/dev/null | grep -o 'copilot@[^ ]*' | cut -d@ -f2; }
ver_cf-cli()   { npm ls -g cf --depth=0 2>/dev/null | grep -o ' cf@[^ ]*' | cut -d@ -f2; }
ver_kubectl()  { kubectl version --client -o yaml 2>/dev/null | grep -m1 'gitVersion:' | awk '{print $2}'; }
ver_helm()     { helm version --short 2>/dev/null | grep -o 'v[0-9][0-9.]*' | head -n1; }
ver_k9s()      { k9s version --short 2>/dev/null | grep -o '[0-9][0-9.]*' | head -n1; }
ver_kind()     { kind version 2>/dev/null | awk '{print $2}'; }
ver_kubectx()  { have kubens && marker kubectx; }
ver_stern()    { stern --version 2>/dev/null | grep -o 'version: [0-9][0-9.]*' | grep -o '[0-9][0-9.]*' | head -n1; }
ver_yq()       { yq --version 2>/dev/null | grep -o '[0-9][0-9.]*' | head -n1; }
ver_task()     { task --version 2>/dev/null | grep -o '[0-9][0-9.]*' | head -n1; }
ver_argocd()   { argocd version --client 2>/dev/null | grep -m1 'argocd:' | awk '{print $2}' | cut -d'+' -f1; }
ver_tflint()   { tflint --version 2>/dev/null | head -n1 | grep -o '[0-9][0-9.]*' | head -n1; }
ver_vault()    { vault version 2>/dev/null | awk '{print $2}'; }
ver_actionlint() { actionlint --version 2>/dev/null | head -n1; }
ver_aks-node-viewer() { marker aks-node-viewer; }
ver_eks-node-viewer() { marker eks-node-viewer; }
ver_check-jsonschema() { check-jsonschema --version 2>/dev/null | awk '{print $3}'; }
ver_yamllint() { yamllint --version 2>/dev/null | awk '{print $2}'; }
ver_flarectl() { flarectl --version 2>&1 | head -n1 | grep -o '[0-9][0-9.]*' | head -n1; }
ver_helmper()  { marker helmper; }
ver_jira-cli() { jira version 2>&1 | grep -oP 'Version="\K[0-9.]+'; }
ver_kargo-cli() { kargo version 2>/dev/null | grep -o '[0-9][0-9.]*' | head -n1; }
ver_kyverno-cli() { kyverno version 2>/dev/null | awk '/^Version:/ {print $2; exit}'; }
ver_netbird()  { netbird version 2>/dev/null | head -n1; }
ver_oras()     { oras version 2>/dev/null | grep -o '[0-9][0-9.]*' | head -n1; }
ver_pup-cli()  { pup --version 2>&1 | head -n1 | grep -o '[0-9][0-9.]*' | head -n1; }

# Install-if-missing probes
present_base()        { have git && have curl && have unzip; }
present_pip3()        { have pip3; }
present_jq()          { have jq; }
present_aws-cli()     { have aws && aws --version 2>&1 | grep -q 'aws-cli/2\.'; }
present_azure-cli()   { have az; }
present_helm-unittest() { have helm && helm plugin list 2>/dev/null | grep -q '^unittest'; }
present_claws()       { have claws; }
present_psql()        { have psql; }
present_slack-cli()   { have slack; }
present_valkey-cli()  { have valkey-cli; }

install_base()  { pkg_install git curl unzip python3; }
install_pip3()  { if have brew; then brew install python3; else pkg_install python3-pip; fi; }
install_jq()    { pkg_install jq; }
install_gh() {
  local v; v="$(bare "$GH_VERSION")"
  [ "$os" = darwin ] && { brew install gh; return; }
  fetch_tar "https://github.com/cli/cli/releases/download/v${v}/gh_${v}_linux_${arch}.tar.gz" "gh_${v}_linux_${arch}/bin/gh" gh
}
install_aws-cli() {
  [ "$os" = darwin ] && { brew install awscli; return; }
  local tmp rc; tmp="$(mktemp -d)"
  curl -fsSL -o "$tmp/a.zip" "https://awscli.amazonaws.com/awscli-exe-linux-$(uname -m).zip" \
    && unzip -q "$tmp/a.zip" -d "$tmp" && sudo "$tmp/aws/install" --update
  rc=$?; rm -rf "$tmp"; return $rc
}
install_azure-cli() {
  have brew && { brew install azure-cli; return; }
  if have dnf; then
    sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
    printf '[azure-cli]\nname=Azure CLI\nbaseurl=https://packages.microsoft.com/yumrepos/azure-cli\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc\n' \
      | sudo tee /etc/yum.repos.d/azure-cli.repo >/dev/null
    sudo dnf install -y azure-cli
  else curl -fsSL https://aka.ms/InstallAzureCLIDeb | sudo bash; fi
}
install_golang() {
  local v tmp rc; v="$(bare "$GO_VERSION")"; tmp="$(mktemp -d)"
  curl -fsSL -o "$tmp/go.tgz" "https://go.dev/dl/go${v}.${os}-${arch}.tar.gz" \
    && sudo rm -rf /usr/local/go && sudo tar -C /usr/local -xzf "$tmp/go.tgz" \
    && sudo ln -sf /usr/local/go/bin/go /usr/local/bin/go && sudo ln -sf /usr/local/go/bin/gofmt /usr/local/bin/gofmt
  rc=$?; rm -rf "$tmp"; return $rc
}
install_nvm() {
  curl -fsSL "https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh" | bash || return 1
  export NVM_DIR="$HOME/.nvm"; . "$NVM_DIR/nvm.sh"
  have node || nvm install --lts
}
npm_ready() {
  have npm && return 0
  [ -s "$HOME/.nvm/nvm.sh" ] && . "$HOME/.nvm/nvm.sh" && have npm
}
install_gh-copilot-cli() { npm_ready || { echo "npm required (install nvm first)" >&2; return 1; }; npm install -g "@github/copilot@$(bare "$COPILOT_CLI_VERSION")"; }
install_cf-cli()         { npm_ready || { echo "npm required (install nvm first)" >&2; return 1; }; npm install -g "cf@$(bare "$CF_CLI_VERSION")"; }
install_kubectl() { fetch_bin "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/${os}/${arch}/kubectl" kubectl; }
install_helm() {
  local tmp rc; tmp="$(mktemp -d)"
  curl -fsSL -o "$tmp/get_helm.sh" https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-4 \
    && USE_SUDO=false HELM_INSTALL_DIR="$BIN_DIR" bash "$tmp/get_helm.sh" --version "$HELM_VERSION"
  rc=$?; rm -rf "$tmp"; return $rc
}
install_helm-unittest() {
  have helm || { echo "helm required" >&2; return 1; }
  helm plugin install --verify=false https://github.com/helm-unittest/helm-unittest.git
}
install_k9s() {
  local os_cap; os_cap="$(printf '%s' "$os" | sed 's/./\U&/')"
  fetch_tar "https://github.com/derailed/k9s/releases/download/v${K9S_VERSION}/k9s_${os_cap}_${arch}.tar.gz" k9s k9s
}
install_kind()    { fetch_bin "https://kind.sigs.k8s.io/dl/v${KIND_VERSION}/kind-${os}-${arch}" kind; }
install_kubectx() {
  local t
  for t in kubectx kubens; do
    fetch_tar "https://github.com/ahmetb/kubectx/releases/download/v${KUBECTX_VERSION}/${t}_v${KUBECTX_VERSION}_${os}_${xarch}.tar.gz" "$t" "$t" || return 1
  done
}
install_stern()   { fetch_tar "https://github.com/stern/stern/releases/download/v${STERN_VERSION}/stern_${STERN_VERSION}_${os}_${arch}.tar.gz" stern stern; }
install_yq()      { fetch_bin "https://github.com/mikefarah/yq/releases/download/v${YQ_VERSION}/yq_${os}_${arch}" yq; }
install_task()    { curl -fsSL https://taskfile.dev/install.sh | sh -s -- -d -b "$BIN_DIR" "$TASK_VERSION"; }
install_argocd()  { fetch_bin "https://github.com/argoproj/argo-cd/releases/download/${ARGOCD_VERSION}/argocd-${os}-${arch}" argocd; }
install_tflint()  { fetch_zip "https://github.com/terraform-linters/tflint/releases/download/v${TFLINT_VERSION}/tflint_${os}_${arch}.zip" tflint tflint; }
install_vault()   { fetch_zip "https://releases.hashicorp.com/vault/${VAULT_VERSION}/vault_${VAULT_VERSION}_${os}_${arch}.zip" vault vault; }
install_actionlint() { fetch_tar "https://github.com/rhysd/actionlint/releases/download/v${ACTIONLINT_VERSION}/actionlint_${ACTIONLINT_VERSION}_${os}_${arch}.tar.gz" actionlint actionlint; }
node_viewer() { # repo bin version
  local a="$xarch" asset; [ "$a" = x86_64 ] || a=arm64
  asset="$2_Linux_${a}"; [ "$os" = darwin ] && asset="$2_Darwin_all"
  fetch_bin "https://github.com/$1/releases/download/v$3/${asset}" "$2"
}
install_aks-node-viewer() { node_viewer Azure/aks-node-viewer aks-node-viewer "$AKS_NODE_VIEWER_VERSION"; }
install_eks-node-viewer() { node_viewer awslabs/eks-node-viewer eks-node-viewer "$EKS_NODE_VIEWER_VERSION"; }
pip_user() { have pip3 || { echo "pip3 required" >&2; return 1; }; pip3 install --user "$1==$2" || pip3 install --user --break-system-packages "$1==$2"; }
install_check-jsonschema() { pip_user check-jsonschema "$CHECK_JSONSCHEMA_VERSION"; }
install_yamllint()        { pip_user yamllint "$YAMLLINT_VERSION"; }
install_claws()   { curl -fsSL https://raw.githubusercontent.com/clawscli/claws/main/install.sh | sh; }
install_flarectl() { fetch_tar "https://github.com/cloudflare/cloudflare-go/releases/download/v${FLARECTL_VERSION}/flarectl_${FLARECTL_VERSION}_${os}_${arch}.tar.gz" flarectl flarectl; }
install_helmper() { fetch_bin "https://github.com/ChristofferNissen/helmper/releases/download/v${HELMPER_VERSION}/helmper-${os}-${arch}" helmper; }
install_jira-cli() {
  local d="jira_${JIRA_CLI_VERSION}_${os}_${xarch}"
  fetch_tar "https://github.com/ankitpokhrel/jira-cli/releases/download/v${JIRA_CLI_VERSION}/${d}.tar.gz" "${d}/bin/jira" jira
}
install_kargo-cli() { fetch_bin "https://github.com/akuity/kargo/releases/download/v${KARGO_VERSION}/kargo-${os}-${arch}" kargo; }
install_kyverno-cli() {
  fetch_tar "https://github.com/kyverno/kyverno/releases/download/${KYVERNO_CLI_VERSION}/kyverno-cli_${KYVERNO_CLI_VERSION}_${os}_${xarch}.tar.gz" kyverno kyverno
}
install_netbird() {
  if [ "$os" = darwin ]; then brew install netbirdio/tap/netbird; return; fi
  NETBIRD_RELEASE="v$(bare "$NETBIRD_VERSION")" curl -fsSL https://pkgs.netbird.io/install.sh | sh
}
install_oras()    { fetch_tar "https://github.com/oras-project/oras/releases/download/v${ORAS_VERSION}/oras_${ORAS_VERSION}_${os}_${arch}.tar.gz" oras oras; }
install_psql() {
  if have brew; then brew install libpq && brew link --force libpq; elif have dnf; then pkg_install postgresql; else pkg_install postgresql-client; fi
}
install_pup-cli() {
  if [ "$os" = darwin ]; then brew install datadog-labs/pack/pup; return; fi
  fetch_tar "https://github.com/DataDog/pup/releases/download/v${PUP_VERSION}/pup_${PUP_VERSION}_Linux_${xarch}.tar.gz" pup pup
}
install_slack-cli() { curl -fsSL https://downloads.slack-edge.com/slack-cli/install.sh | bash; }
install_valkey-cli() { if have apt-get; then pkg_install valkey-tools; else pkg_install valkey; fi; }

run_tool() {
  local t="$1" want have_v
  if [ -n "${PIN[$t]:-}" ]; then
    want="$(bare "${PIN[$t]}")"
    have_v="$("ver_$t" 2>/dev/null | head -n1)"; have_v="$(bare "$have_v")"
    if [ "$have_v" = "$want" ]; then echo "  already installed: $have_v"; return 0; fi
    [ -n "$have_v" ] && echo "  $have_v installed, want $want - upgrading"
    "install_$t" || return 1
    printf '%s' "$want" > "$MARK_DIR/$t"
  else
    if "present_$t" 2>/dev/null; then echo "  already installed"; return 0; fi
    "install_$t"
  fi
}

failed=()
for t in $TOOLS; do
  printf '→ %s\n' "$t"
  if declare -F "install_$t" >/dev/null && run_tool "$t"; then echo "  ok"; else echo "  FAILED"; failed+=("$t"); fi
done

echo
case ":$PATH:" in *":$BIN_DIR:"*) ;; *) echo "Add to shell rc: export PATH=\"$BIN_DIR:\$PATH\"" ;; esac
[ ${#failed[@]} -eq 0 ] && echo "All done." || { echo "Failed: ${failed[*]}"; exit 1; }

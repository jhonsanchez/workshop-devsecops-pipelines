---
title: "Prerequisitos"
description: Todo lo que necesitas instalar y configurar antes de empezar el workshop
tags:
  - Instalacion
  - Prerequisitos
  - Setup
---

# Prerequisitos

Antes de iniciar el primer lab, necesitas tener configuradas las siguientes
herramientas y cuentas. Reserva **30-45 minutos** para completar esta seccion.

---

## Cuentas necesarias

| Cuenta | Proposito | Enlace de registro |
|--------|-----------|--------------------|
| **GitHub** | Repositorio del codigo fuente y CI/CD (GitHub Actions) | [github.com](https://github.com) |
| **Azure** (suscripcion gratuita, opcional) | App Service para deploy | [azure.microsoft.com/free](https://azure.microsoft.com/free) |

!!! warning "Cuenta GitHub"
    Necesitas una cuenta de **GitHub** con acceso a GitHub Actions. El plan
    gratuito incluye 2,000 minutos/mes de Actions para repositorios privados
    e ilimitado para repositorios publicos, suficiente para este workshop.

---

## Herramientas requeridas

### Git

=== "macOS"

    ```bash
    # Git viene con Xcode Command Line Tools
    xcode-select --install
    # Verificar
    git --version  # >= 2.40
    ```

=== "Linux (Ubuntu/Debian)"

    ```bash
    sudo apt update && sudo apt install -y git
    git --version  # >= 2.40
    ```

=== "WSL2 (Windows)"

    ```bash
    # Dentro de tu distribucion WSL2
    sudo apt update && sudo apt install -y git
    git --version  # >= 2.40
    ```

---

### Docker Desktop

=== "macOS"

    ```bash
    # Descargar desde https://www.docker.com/products/docker-desktop/
    # O con Homebrew:
    brew install --cask docker
    # Abrir Docker Desktop y esperar a que inicie
    docker version  # Client + Server
    ```

=== "Linux (Ubuntu/Debian)"

    ```bash
    # Instalar Docker Engine
    curl -fsSL https://get.docker.com | sudo sh
    sudo usermod -aG docker $USER
    newgrp docker
    docker version
    ```

=== "WSL2 (Windows)"

    ```bash
    # Instalar Docker Desktop para Windows
    # Habilitar integracion WSL2 en Settings > Resources > WSL Integration
    docker version
    ```

!!! info "Docker es obligatorio"
    Varios labs construyen y escanean imagenes de contenedores. Sin Docker
    funcionando, no podras completar los Labs 6, 7 y 8.

---

### Terraform

=== "macOS"

    ```bash
    brew tap hashicorp/tap
    brew install hashicorp/tap/terraform
    terraform version  # >= 1.6
    ```

=== "Linux (Ubuntu/Debian)"

    ```bash
    wget -O - https://apt.releases.hashicorp.com/gpg | \
      sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
    echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
      https://apt.releases.hashicorp.com $(lsb_release -cs) main" | \
      sudo tee /etc/apt/sources.list.d/hashicorp.list
    sudo apt update && sudo apt install terraform
    terraform version  # >= 1.6
    ```

=== "WSL2 (Windows)"

    ```bash
    # Mismos pasos que Linux (Ubuntu/Debian) dentro de WSL2
    wget -O - https://apt.releases.hashicorp.com/gpg | \
      sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
    echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
      https://apt.releases.hashicorp.com $(lsb_release -cs) main" | \
      sudo tee /etc/apt/sources.list.d/hashicorp.list
    sudo apt update && sudo apt install terraform
    terraform version  # >= 1.6
    ```

---

### Azure CLI

=== "macOS"

    ```bash
    brew install azure-cli
    az version  # >= 2.55
    az login
    ```

=== "Linux (Ubuntu/Debian)"

    ```bash
    curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
    az version  # >= 2.55
    az login
    ```

=== "WSL2 (Windows)"

    ```bash
    curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
    az version  # >= 2.55
    az login --use-device-code  # Recomendado en WSL2
    ```

---

### Python

=== "macOS"

    ```bash
    # Python 3 viene preinstalado en macOS recientes, o:
    brew install python@3.12
    python3 --version  # >= 3.10
    pip3 --version
    ```

=== "Linux (Ubuntu/Debian)"

    ```bash
    sudo apt install -y python3 python3-pip python3-venv
    python3 --version  # >= 3.10
    ```

=== "WSL2 (Windows)"

    ```bash
    sudo apt install -y python3 python3-pip python3-venv
    python3 --version  # >= 3.10
    ```

---

### Herramientas de seguridad (se instalaran en los labs)

Las siguientes herramientas se instalaran durante los labs correspondientes,
pero si quieres adelantarte:

```bash
# Gitleaks (Lab 3)
brew install gitleaks       # macOS
# o descargar binario: https://github.com/gitleaks/gitleaks/releases

# Semgrep (Lab 4)
pip3 install semgrep

# Trivy (Lab 5 y 7)
brew install trivy          # macOS
# o: https://aquasecurity.github.io/trivy/latest/getting-started/installation/

# Cosign (Lab 7)
brew install cosign         # macOS
# o: https://docs.sigstore.dev/cosign/system_config/installation/

# Checkov (Lab 9)
pip3 install checkov

# Conftest (Lab 9)
brew install conftest       # macOS
```

---

## Fork de la aplicacion vulnerable

El workshop usa una aplicacion vulnerable pre-construida. Necesitas hacer fork
del repositorio:

<div class="steps" markdown>

1. Ve a [github.com/jhonsanchez/workshop-devsecops-pipelines](https://github.com/jhonsanchez/workshop-devsecops-pipelines)

2. Haz clic en **Fork** (esquina superior derecha)

3. Clona tu fork localmente:

    ```bash
    git clone https://github.com/jhonsanchez/workshop-devsecops-pipelines.git
    cd devsecops-workshop
    ```

4. Verifica la estructura del proyecto:

    ```bash
    ls -la vulnerable-app/
    # Deberia mostrar: Dockerfile, requirements.txt, app/, etc.
    ```

</div>

!!! danger "No uses el repositorio original"
    Trabaja siempre sobre tu fork. Los labs requieren que hagas push de
    cambios y configures pipelines en tu propia copia del repositorio.

---

## Script de verificacion

Ejecuta el siguiente script para verificar que tienes todo instalado:

```bash title="verify-prerequisites.sh"
#!/bin/bash
set -e

echo "=== Verificacion de Prerequisitos DevSecOps Workshop ==="
echo ""

check() {
  local name="$1"
  local cmd="$2"
  local min_version="$3"

  if command -v "$cmd" &> /dev/null; then
    local version
    version=$($cmd --version 2>&1 | head -1)
    echo "[OK]  $name: $version"
  else
    echo "[FALTA] $name: no encontrado. Instala '$cmd' antes de continuar."
  fi
}

check "Git"        git        "2.40"
check "Docker"     docker     ""
check "Terraform"  terraform  "1.6"
check "Azure CLI"  az         "2.55"
check "Python"     python3    "3.10"
check "pip"        pip3       ""

echo ""
echo "=== Verificacion de cuentas ==="

# GitHub CLI
if gh auth status &> /dev/null; then
  echo "[OK]  GitHub CLI: autenticado"
else
  echo "[FALTA] GitHub CLI: ejecuta 'gh auth login'"
fi

# Docker daemon
if docker info &> /dev/null; then
  echo "[OK]  Docker daemon: funcionando"
else
  echo "[FALTA] Docker daemon: no esta ejecutandose. Abre Docker Desktop."
fi

echo ""
echo "=== Verificacion del repositorio ==="

if [ -f "vulnerable-app/Dockerfile" ]; then
  echo "[OK]  Repositorio: vulnerable-app encontrada"
else
  echo "[FALTA] Repositorio: no se encuentra vulnerable-app/. Asegurate de estar en el directorio correcto."
fi

echo ""
echo "=== Fin de la verificacion ==="
```

Ejecutalo con:

```bash
chmod +x verify-prerequisites.sh
./verify-prerequisites.sh
```

!!! tip "Todo en verde?"
    Si todos los checks muestran `[OK]`, estas listo para empezar el
    [Concepto 1: CI/CD y Seguridad](../concepto01-cicd/index.md).

---

## Resumen de versiones minimas

| Herramienta | Version minima | Comando de verificacion |
|-------------|---------------|------------------------|
| Git | >= 2.40 | `git --version` |
| Docker | >= 24.0 | `docker version` |
| Terraform | >= 1.6 | `terraform version` |
| Azure CLI | >= 2.55 | `az version` |
| Python | >= 3.10 | `python3 --version` |
| pip | >= 23.0 | `pip3 --version` |

---

<div style="display: flex; justify-content: space-between; margin-top: 2rem;">
[:octicons-arrow-left-24: Anterior: Bienvenida](index.md){ .md-button }
[Siguiente: Concepto 1 — CI/CD y Seguridad :octicons-arrow-right-24:](../concepto01-cicd/index.md){ .md-button .md-button--primary }
</div>

---
title: "Concepto 3 — Secretos en Codigo"
description: Tipos de secretos, permanencia en Git, ciclo de vida de una fuga y gestion segura
tags:
  - Secretos
  - Credenciales
  - Git
  - Key Vault
  - Seguridad
---

# Concepto 3 — Secretos en Codigo

## Objetivo de aprendizaje

Al terminar este modulo entenderas que es un secreto, por que el historial de
Git hace que una fuga sea permanente, las estadisticas de secretos filtrados,
el ciclo de vida completo de una fuga, como gestionar secretos correctamente
y los incidentes reales que demuestran el impacto de este problema.

---

## Que es un secreto

Un **secreto** es cualquier dato que otorga acceso a un sistema, servicio o
recurso. Si alguien obtiene el secreto, puede actuar como el propietario
legitimo.

| Tipo de secreto | Ejemplo | Riesgo si se filtra |
|-----------------|---------|---------------------|
| **API Key** | `AKIA5EXAMPLE12345678` (AWS) | Acceso a recursos cloud, facturacion |
| **Token de acceso** | `ghp_xxxxxxxxxxxx` (GitHub PAT) | Lectura/escritura de repositorios |
| **Contrasena de BD** | `postgres://user:P@ssw0rd@host/db` | Acceso directo a datos |
| **Clave privada** | `-----BEGIN RSA PRIVATE KEY-----` | Suplantacion de identidad, firma |
| **Client Secret** | `service-principal-secret-xyz` | Acceso a suscripcion Azure |
| **Connection String** | `Server=...;Password=...` | Acceso a base de datos |
| **Webhook Secret** | `whsec_xxxxxxxxx` | Disparo de acciones, exfiltracion |
| **Certificado (.pfx)** | Archivo binario con clave privada | TLS interception, firma de codigo |

!!! danger "Un secreto no es solo una contrasena"
    Los equipos a menudo piensan en "contrasenas" cuando hablan de secretos.
    Pero tokens, claves de API, certificados, connection strings y hasta URLs
    con credenciales embebidas son secretos. El alcance es mucho mayor de
    lo que parece.

---

## La permanencia de Git

Git es un sistema de control de versiones **inmutable por diseno**. Cada
commit se identifica por un hash SHA-1 que incluye el contenido completo.

```mermaid
gitGraph
    commit id: "feat: login"
    commit id: "add: config" type: HIGHLIGHT
    commit id: "fix: remove secret"
    commit id: "refactor: cleanup"
```

!!! danger "Borrar un archivo NO borra el secreto"
    En el diagrama anterior, el commit "add: config" incluye el secreto.
    Aunque en "fix: remove secret" se borra el archivo, **el commit
    anterior sigue existiendo** en el historial de Git. Cualquier persona
    con acceso al repositorio puede ejecutar:

    ```bash
    git log --all --full-history -- config.py
    git show <commit-hash>:config.py
    ```

    Y ver el secreto original. Incluso despues de un `git rebase` o
    `git filter-branch`, el secreto puede persistir en reflog, forks,
    espejos y backups.

### Por que es tan dificil de remediar

```mermaid
flowchart TB
    C[Secreto en commit] --> R1[Repositorio original]
    C --> R2[Forks]
    C --> R3[Espejos/mirrors]
    C --> R4[Clones locales<br/>de desarrolladores]
    C --> R5[Backups]
    C --> R6[Caches de CI/CD]
    C --> R7[Indexadores<br/>GitHub Search, Google]

    R1 --> |git filter-branch| X1[Se puede limpiar<br/>pero rompe historial]
    R2 --> X2[No controlas<br/>los forks]
    R7 --> X3[Puede estar cacheado<br/>indefinidamente]

    style C fill:#d32f2f,color:#fff
    style X2 fill:#d32f2f,color:#fff
    style X3 fill:#d32f2f,color:#fff
```

!!! warning "La unica remediacion real es ROTAR el secreto"
    Una vez que un secreto se ha commiteado a Git, la unica respuesta
    segura es **revocar y rotar** el secreto inmediatamente. Intentar
    "limpiar" el historial es necesario pero **no suficiente**.

---

## Estadisticas de secretos filtrados

Los datos del reporte de GitGuardian 2024 muestran la escala del problema:

| Metrica | Valor |
|---------|-------|
| Secretos detectados en repositorios publicos (2023) | **12.8 millones** |
| Incremento respecto al ano anterior | +28% |
| Porcentaje de repos con al menos 1 secreto | ~1 de cada 10 |
| Tiempo promedio de exposicion antes de revocar | **varios dias** |
| Secretos que siguen validos tras deteccion | ~70% |
| Tipo mas comun | API keys genericas |
| Segundo mas comun | Google API keys |

!!! example "Dato impactante"
    Segun GitHub, en 2023 se bloquearon mas de **1 millon** de secretos
    a traves de push protection (secretos que intentaron ser pusheados
    pero fueron bloqueados antes de llegar al repositorio). Esto demuestra
    que la deteccion en pre-push funciona — pero tambien que millones de
    desarrolladores intentan pushear secretos diariamente.

---

## Categorias de fugas de secretos

```mermaid
flowchart TB
    subgraph Categorias["Como se filtran los secretos"]
        direction TB
        A[Directamente<br/>en codigo fuente] --> |"password = 'abc123'"| R[Repositorio Git]
        B[En archivos de<br/>configuracion] --> |".env, config.yml<br/>application.properties"| R
        C[En archivos<br/>de infraestructura] --> |"terraform.tfvars<br/>docker-compose.yml"| R
        D[En logs<br/>y artefactos] --> |"Pipeline output<br/>build artifacts"| L[Logs CI/CD]
        E[En notebooks<br/>y documentacion] --> |"Jupyter, README<br/>con ejemplos reales"| R
        F[En variables<br/>de entorno hardcodeadas] --> |"Dockerfile ENV"| R
    end

    style A fill:#d32f2f,color:#fff
    style B fill:#d32f2f,color:#fff
    style C fill:#d32f2f,color:#fff
    style D fill:#d32f2f,color:#fff
    style E fill:#d32f2f,color:#fff
    style F fill:#d32f2f,color:#fff
```

| Categoria | Ejemplo | Frecuencia |
|-----------|---------|------------|
| **Hardcoded en codigo** | `api_key = "sk-xxxx"` | Muy alta |
| **Archivos de config** | `.env`, `config.json`, `application.yml` | Alta |
| **IaC** | `terraform.tfvars`, `docker-compose.yml` | Alta |
| **Notebooks** | Jupyter con tokens de API | Media |
| **Logs de CI/CD** | Pipeline imprime variable con secreto | Media |
| **Commits de merge** | Secreto en branch feature, mergeado a main | Media |
| **Dependencias** | Secreto en paquete publicado a npm/PyPI | Baja pero devastadora |

---

## Ciclo de vida de una fuga de secreto

```mermaid
flowchart LR
    A["1. COMMIT<br/>Desarrollador<br/>commitea secreto<br/>accidentalmente"] --> B["2. PUSH<br/>Secreto llega<br/>al repositorio<br/>remoto"]
    B --> C["3. INDEXADO<br/>Bots escanean<br/>GitHub/GitLab<br/>en minutos"]
    C --> D["4. EXPLOTADO<br/>Atacante usa<br/>credenciales<br/>en < 1 hora"]
    D --> E["5. IMPACTO<br/>Datos exfiltrados<br/>recursos abusados<br/>movimiento lateral"]
    E --> F["6. DETECCION<br/>Alerta de coste<br/>anomalo, o<br/>reporte externo"]
    F --> G["7. RESPUESTA<br/>Revocar, rotar<br/>investigar alcance<br/>notificar"]

    style A fill:#ff9800,color:#000
    style B fill:#f44336,color:#fff
    style C fill:#d32f2f,color:#fff
    style D fill:#b71c1c,color:#fff
    style E fill:#880e4f,color:#fff
    style F fill:#046BD2,color:#fff
    style G fill:#2e7d32,color:#fff
```

### Timeline real de explotacion

| Paso | Tiempo desde el commit | Que ocurre |
|------|----------------------|------------|
| Commit | T+0 | Desarrollador escribe `AWS_SECRET_ACCESS_KEY=...` |
| Push | T+30 seg | `git push` al repositorio |
| Indexacion | T+1-5 min | Bots automatizados escanean repos publicos |
| Primer intento de uso | T+5-30 min | Atacante prueba las credenciales |
| Explotacion activa | T+1-24 h | Criptomineria, exfiltracion de datos, pivot |
| Factura anormal | T+24-72 h | Alertas de coste en la nube |
| Deteccion/respuesta | T+dias a semanas | Equipo de seguridad investiga |

!!! danger "Velocidad de explotacion"
    Investigadores de seguridad han demostrado que **credenciales de AWS
    publicadas en GitHub son explotadas en menos de 5 minutos**. Bots
    automatizados escanean continuamente repositorios publicos buscando
    patrones de secretos conocidos (regex para AWS keys, GitHub tokens, etc.).

---

## Gestion segura de secretos

### Anti-patrones (lo que NO hacer)

| Anti-patron | Ejemplo | Por que es malo |
|-------------|---------|-----------------|
| Hardcoded en codigo | `password = "admin123"` | Queda en historial de Git para siempre |
| Archivo `.env` commiteado | `.env` sin `.gitignore` | Mismo problema que hardcoded |
| Variable de entorno en Dockerfile | `ENV DB_PASSWORD=xxx` | Queda en las capas de la imagen |
| Secreto en pipeline YAML | `variables: password: "xxx"` | Visible en el repositorio |
| Compartir por Slack/email | "Te paso el token por DM" | Sin auditoria, sin rotacion |

### Patron correcto: GitHub Secrets + GitHub Environments

```mermaid
flowchart LR
    subgraph Correcto["Gestion Segura de Secretos"]
        KV[GitHub Secrets<br/>Secretos cifrados<br/>con auditoria] --> VG[GitHub Environment<br/>vinculado a KV]
        VG --> P[Pipeline<br/>Referencia por nombre]
        P --> A[Agente<br/>Secreto en memoria<br/>solo durante ejecucion]
        A --> M[Logs<br/>Valor enmascarado<br/>como ***]
    end

    style KV fill:#2e7d32,color:#fff
    style VG fill:#046BD2,color:#fff
    style M fill:#046BD2,color:#fff
```

| Solucion | Ventajas | Uso recomendado |
|----------|----------|-----------------|
| **GitHub Secrets** | Cifrado HSM, auditoria, rotacion, RBAC | Secretos de aplicacion y pipeline |
| **GitHub Secrets** | Integracion nativa con GitHub Actions | Inyectar secretos en el workflow |
| **Managed Identity** | Sin credenciales que gestionar | Autenticacion de servicios Azure |
| **Workload Identity Federation** | Sin secretos para service principals | Service connections sin client secrets |
| **GitHub Secrets** | Cifrado, scoped a repo/org/environment | GitHub Actions (cuando se usa con GH) |

### Managed Identity: el objetivo final

```mermaid
flowchart LR
    App[Aplicacion<br/>en Azure] --> |"Pido un token<br/>sin credenciales"| IMDS[Azure IMDS<br/>Instance Metadata<br/>Service]
    IMDS --> |"Aqui tienes<br/>un token JWT"| App
    App --> |"Token en header"| KV[Key Vault]
    KV --> |"Secreto"| App

    style App fill:#046BD2,color:#fff
    style IMDS fill:#2e7d32,color:#fff
```

!!! tip "Managed Identity elimina el problema de raiz"
    Con Managed Identity, **no hay secreto que filtrar**. La identidad
    esta vinculada al recurso de Azure (VM, App Service, AKS) y el token
    se obtiene automaticamente del metadata service. No hay credenciales
    en codigo, en variables ni en Key Vault.

---

## Incidentes reales

### Uber (2016)

!!! example "Incidente: Uber Data Breach 2016"
    **Que paso**: Dos atacantes encontraron credenciales de AWS hardcodeadas
    en un repositorio privado de GitHub de Uber. Con esas credenciales,
    accedieron a un bucket S3 que contenia datos personales de **57 millones
    de usuarios y 600,000 conductores** (nombres, emails, numeros de
    telefono, numeros de licencia de conducir).

    **Lo que agrava el caso**: Uber pago $100,000 a los atacantes para que
    eliminaran los datos y **oculto el incidente durante mas de un ano**,
    lo que resulto en multas regulatorias y dano reputacional masivo.

    **Leccion**:

    - Las credenciales de AWS en un repo privado son igual de peligrosas
    - El acceso al repositorio = acceso a la infraestructura
    - La deteccion automatica habria evitado la fuga inicial
    - La ocultacion empeora las consecuencias exponencialmente

### CircleCI (2023)

!!! example "Incidente: CircleCI Security Incident 2023"
    **Que paso**: Un ingeniero de CircleCI fue victima de un ataque de
    malware que robo su token de sesion SSO. Con esa sesion, los atacantes
    accedieron a los sistemas internos de CircleCI y extrajeron **todas
    las variables de entorno, tokens y secretos** almacenados por los
    clientes en la plataforma CI/CD.

    CircleCI pidio a **todos** sus clientes que rotaran **todos** sus
    secretos — una operacion de emergencia masiva.

    **Leccion**:

    - Los secretos almacenados en la plataforma CI/CD son un target de
      alto valor
    - Un unico punto de compromiso (la cuenta del ingeniero) expuso a
      miles de organizaciones
    - La rotacion masiva de secretos es extremadamente costosa
    - Minimiza los secretos almacenados en CI/CD; usa identidades
      gestionadas siempre que sea posible

---

## Estrategia de prevencion y deteccion

| Capa | Control | Herramienta | Cuando |
|------|---------|-------------|--------|
| **Pre-commit** | Hook local que bloquea el commit | `gitleaks`, `detect-secrets` | Antes de `git commit` |
| **Pre-push** | Push protection del proveedor | GitHub Push Protection | Antes de `git push` |
| **CI** | Escaneo del repositorio completo | Gitleaks en pipeline | Con cada PR/push |
| **Historico** | Escaneo de todo el historial de Git | `gitleaks detect --source=.` | Periodicamente |
| **Runtime** | Secretos inyectados desde Key Vault | GitHub Secrets + MI | En tiempo de ejecucion |
| **Rotacion** | Cambiar secretos periodicamente | Azure KV auto-rotation | Cada 30-90 dias |
| **Respuesta** | Revocar y rotar ante deteccion | Runbook de incidentes | Ante cualquier alerta |

```mermaid
flowchart LR
    subgraph Defensa["Defensa en Profundidad para Secretos"]
        direction LR
        PC[Pre-commit<br/>Hook local] --> PP[Pre-push<br/>Push Protection]
        PP --> CI[CI Pipeline<br/>Gitleaks scan]
        CI --> H[Historico<br/>Full repo scan]
        H --> RT[Runtime<br/>Key Vault + MI]
        RT --> ROT[Rotacion<br/>Automatica]
    end

    style PC fill:#2e7d32,color:#fff
    style PP fill:#2e7d32,color:#fff
    style CI fill:#046BD2,color:#fff
    style H fill:#046BD2,color:#fff
    style RT fill:#045CB4,color:#fff
    style ROT fill:#041C2C,color:#fff
```

---

## Resumen

```mermaid
mindmap
  root((Secretos en<br/>Codigo))
    Que es un secreto
      API Keys
      Tokens
      Contrasenas
      Certificados
    Permanencia en Git
      Historial inmutable
      Forks y mirrors
      Indexadores automaticos
    Ciclo de fuga
      Commit
      Push
      Indexado en minutos
      Explotado en horas
    Gestion segura
      GitHub Secrets
      Managed Identity
      GitHub Environments
      Rotacion automatica
    Incidentes
      Uber 2016
      CircleCI 2023
    Defensa
      Pre-commit hooks
      Push protection
      CI scanning
      Rotacion
```

---

<div style="display: flex; justify-content: space-between; margin-top: 2rem;">
[:octicons-arrow-left-24: Anterior: Lab 2](../lab02-pipeline-base/index.md){ .md-button }
[Siguiente: Lab 3 — Deteccion de Secretos :octicons-arrow-right-24:](../lab03-secretos/index.md){ .md-button .md-button--primary }
</div>

---
title: "Concepto 6 — Artefactos e Inmutabilidad"
description: Registros de artefactos, inmutabilidad, versionado semantico, digests SHA256 y builds reproducibles
tags:
  - Artefactos
  - Inmutabilidad
  - Docker
  - Registry
  - SHA256
  - Seguridad
---

# Concepto 6 — Artefactos e Inmutabilidad

## Objetivo de aprendizaje

Al terminar este modulo entenderas que es un artefacto de build, como
funcionan los registros de artefactos, por que la inmutabilidad es fundamental
para la seguridad, como el versionado semantico impacta la seguridad,
que son los digests SHA256 y por que el tag `:latest` es un anti-patron
peligroso.

---

## Que es un artefacto de build

Un **artefacto** es el producto resultante de un proceso de build. Es lo que
realmente se despliega en produccion.

| Tipo de artefacto | Ejemplo | Formato |
|-------------------|---------|---------|
| **Imagen de contenedor** | `myapp:v1.2.3` | OCI / Docker image |
| **Paquete de aplicacion** | `myapp-1.2.3.whl` | Python wheel |
| **Binario compilado** | `myapp-linux-amd64` | ELF / PE |
| **Bundle frontend** | `dist/` | HTML/JS/CSS |
| **Chart de Helm** | `myapp-chart-1.2.3.tgz` | Helm chart |
| **Archivo de IaC** | `terraform-plan.json` | Terraform plan |

!!! info "Para equipos de seguridad"
    El artefacto es lo que **realmente corre en produccion**. Todo el
    analisis de seguridad previo (SAST, SCA, secretos) protege el codigo
    fuente. Pero si el artefacto se manipula entre el build y el despliegue,
    todas esas protecciones son inutiles. La **integridad del artefacto**
    es la ultima linea de defensa.

---

## Registros de artefactos

Un **registro** (registry) es el almacen donde se publican, versionan y
distribuyen artefactos.

| Registro | Tipo de artefactos | Proveedor |
|----------|-------------------|-----------|
| **Azure Container Registry (ACR)** | Imagenes OCI, Helm charts | Microsoft Azure |
| **Docker Hub** | Imagenes Docker | Docker Inc. |
| **GitHub Container Registry (GHCR)** | Imagenes OCI | GitHub |
| **Azure Artifacts** | npm, NuGet, Python, Maven | Microsoft Azure |
| **Artifactory** | Universal (todos los formatos) | JFrog |
| **Amazon ECR** | Imagenes OCI | AWS |

### Flujo: del build al registro

```mermaid
flowchart LR
    CODE[Codigo<br/>fuente] --> BUILD[Build<br/>docker build]
    BUILD --> IMAGE[Imagen<br/>myapp:v1.2.3]
    IMAGE --> PUSH[Push<br/>docker push]
    PUSH --> REG[Registry<br/>ACR / Docker Hub]
    REG --> PULL[Pull<br/>docker pull]
    PULL --> DEPLOY[Deploy<br/>Produccion]

    style BUILD fill:#046BD2,color:#fff
    style REG fill:#045CB4,color:#fff
    style DEPLOY fill:#041C2C,color:#fff
```

!!! warning "El registro es un activo critico"
    Quien tiene acceso de **push** al registro puede reemplazar cualquier
    imagen. Es equivalente a tener acceso de escritura a produccion. Los
    permisos del registro deben ser tan restrictivos como los permisos
    de despliegue.

---

## Inmutabilidad: por que importa

**Inmutabilidad** significa que una vez publicado un artefacto con una version
especifica, ese artefacto **no puede ser modificado ni sobreescrito**.

### Mutable vs inmutable

```mermaid
flowchart TB
    subgraph Mutable["Flujo MUTABLE (peligroso)"]
        direction LR
        B1[Build v1] --> |"push myapp:v1.0"| R1[Registry<br/>myapp:v1.0 = abc123]
        B2[Build v1 rehecho] --> |"push myapp:v1.0<br/>SOBREESCRIBE"| R1b[Registry<br/>myapp:v1.0 = def456]
        R1b --> D1[Deploy<br/>Que version es?]
    end

    subgraph Immutable["Flujo INMUTABLE (seguro)"]
        direction LR
        B3[Build v1] --> |"push myapp:v1.0"| R2[Registry<br/>myapp:v1.0 = abc123<br/>BLOQUEADO]
        B4[Build v1 rehecho] --> |"push myapp:v1.0<br/>RECHAZADO"| X[Error: tag existe<br/>inmutabilidad activada]
        B4 --> |"push myapp:v1.1"| R3[Registry<br/>myapp:v1.1 = def456]
    end

    style R1b fill:#d32f2f,color:#fff
    style D1 fill:#d32f2f,color:#fff
    style R2 fill:#2e7d32,color:#fff
    style X fill:#ff9800,color:#000
    style R3 fill:#2e7d32,color:#fff
```

### Por que la inmutabilidad es un control de seguridad

| Sin inmutabilidad | Con inmutabilidad |
|------------------|-------------------|
| Un atacante con acceso al registro puede reemplazar una imagen | Un atacante no puede sobreescribir una version publicada |
| No puedes verificar que la imagen desplegada es la que se construyo | Cada version es unica y verificable |
| No hay trazabilidad del contenido real de cada version | Cada tag apunta siempre al mismo contenido |
| Un error en CI puede sobreescribir una version estable | Las versiones publicadas son permanentes |

!!! danger "Sin inmutabilidad, tu registro es una puerta trasera"
    Si alguien puede ejecutar `docker push myapp:v1.0` y sobreescribir la
    imagen que ya esta en produccion, todos los controles de seguridad
    anteriores son irrelevantes. La imagen que paso SAST, SCA y escaneo
    puede ser reemplazada silenciosamente por una imagen maliciosa.

### Habilitar inmutabilidad en ACR

```bash
# Habilitar inmutabilidad en Azure Container Registry
az acr repository update \
  --name myregistry \
  --image myapp:v1.0.0 \
  --write-enabled false

# O a nivel de repositorio completo:
az acr config retention update \
  --registry myregistry \
  --type UntaggedManifests \
  --days 30 \
  --status enabled
```

---

## Versionado semantico para seguridad

El **versionado semantico** (SemVer) usa el formato `MAJOR.MINOR.PATCH`:

| Componente | Cuando se incrementa | Ejemplo |
|-----------|---------------------|---------|
| **MAJOR** | Cambios incompatibles (breaking changes) | `1.0.0` → `2.0.0` |
| **MINOR** | Nueva funcionalidad compatible hacia atras | `1.0.0` → `1.1.0` |
| **PATCH** | Correccion de bugs (incluye fixes de seguridad) | `1.0.0` → `1.0.1` |

### Implicaciones de seguridad del versionado

| Practica | Riesgo | Recomendacion |
|----------|--------|---------------|
| Usar ranges (`>=1.0`, `^1.0`) | Actualizacion automatica puede introducir CVEs o breaking changes | Usar versiones exactas en produccion |
| Usar `:latest` | No sabes que version esta corriendo | Siempre especificar tag + digest |
| Saltar versiones PATCH | Perder fixes de seguridad | Aplicar PATCHes rapidamente |
| No seguir SemVer | Imposible evaluar riesgo de actualizacion | Exigir SemVer en politicas |

---

## SHA256 digests

Un **digest** es un hash criptografico del contenido exacto de un artefacto.
Mientras un tag es un nombre legible que puede cambiar, el digest es una
referencia **inmutable y unica** al contenido.

```
Tag:     myapp:v1.0.0                          ← Nombre legible, puede cambiar
Digest:  myapp@sha256:a3b5c7d9e1f2...          ← Hash del contenido, INMUTABLE
```

### Tag vs Digest

| Caracteristica | Tag | Digest |
|---------------|-----|--------|
| **Formato** | `myapp:v1.0.0` | `myapp@sha256:a3b5c7...` |
| **Mutable** | Si (puede ser reasignado) | No (el contenido define el hash) |
| **Legible** | Si | No (hash largo) |
| **Verificable** | No (puede apuntar a contenido diferente) | Si (el hash garantiza el contenido) |
| **Uso en produccion** | Solo si hay inmutabilidad de tags | Siempre seguro |

```mermaid
flowchart TB
    subgraph Tags["Tags: nombres mutables"]
        direction LR
        T1[myapp:v1.0.0] --> |"hoy apunta a"| C1[Contenido A<br/>sha256:abc...]
        T1 -.-> |"manana podria<br/>apuntar a"| C2[Contenido B<br/>sha256:def...]
    end

    subgraph Digests["Digests: referencias inmutables"]
        direction LR
        D1["myapp@sha256:abc..."] --> |"SIEMPRE apunta a"| C3[Contenido A]
    end

    style T1 fill:#ff9800,color:#000
    style D1 fill:#2e7d32,color:#fff
    style C2 fill:#d32f2f,color:#fff
```

### Digest pinning en Kubernetes

```yaml title="deployment.yaml"
# MAL: usa tag mutable
containers:
  - name: myapp
    image: myregistry.azurecr.io/myapp:latest  # NO

# MEJOR: usa tag de version
containers:
  - name: myapp
    image: myregistry.azurecr.io/myapp:v1.0.0  # Mejor, pero aun mutable

# CORRECTO: usa digest
containers:
  - name: myapp
    image: myregistry.azurecr.io/myapp@sha256:a3b5c7d9e1f2...  # INMUTABLE
```

!!! tip "Obtener el digest de una imagen"
    ```bash
    # Despues de build y push:
    docker inspect --format='{{index .RepoDigests 0}}' myapp:v1.0.0
    # Salida: myregistry.azurecr.io/myapp@sha256:a3b5c7d9e1f2...

    # O desde el registro:
    az acr manifest show \
      --registry myregistry \
      --name myapp:v1.0.0 \
      --query "digest" -o tsv
    ```

---

## El peligro del tag `:latest`

El tag `:latest` es el **anti-patron mas peligroso** en la gestion de
artefactos.

| Problema | Explicacion |
|----------|-------------|
| **No sabes que version es** | `:latest` no indica la version del codigo |
| **Cambia sin aviso** | Cada `docker push myapp:latest` sobreescribe el anterior |
| **No es reproducible** | Dos pulls del mismo tag pueden dar contenido diferente |
| **Rompe el rollback** | Si `:latest` ya apunta a la version nueva, no puedes volver a la anterior |
| **Dificulta auditorias** | No puedes correlacionar la imagen en produccion con un commit |
| **Enmascara vulnerabilidades** | No puedes saber si la imagen actual paso los escaneos |

```mermaid
flowchart TB
    subgraph Escenario["Desastre con :latest"]
        direction TB
        B1["Build #42<br/>Tests pasan<br/>Seguridad OK"] --> |"push myapp:latest"| REG[Registry<br/>myapp:latest]
        REG --> PROD[Produccion<br/>ejecuta :latest OK]

        B2["Build #43<br/>Tests FALLAN<br/>Vulnerabilidad critica"] --> |"push myapp:latest<br/>SOBREESCRIBE"| REG
        REG --> |"restart pod"| PROD2["Produccion<br/>ejecuta :latest ROTO<br/>Vulnerabilidad en prod"]
    end

    PROD2 --> |"rollback a :latest?"| FAIL["No puedes. :latest<br/>ya es la version rota"]

    style B2 fill:#d32f2f,color:#fff
    style PROD2 fill:#d32f2f,color:#fff
    style FAIL fill:#d32f2f,color:#fff
```

!!! danger "Prohibe `:latest` en produccion"
    Como control de seguridad, implementa una politica (OPA/Gatekeeper,
    Azure Policy) que **rechace despliegues con el tag `:latest`** en
    entornos de staging y produccion. Solo permite tags de version
    especificos (ej: `v1.2.3`) o, mejor aun, digests SHA256.

---

## Builds reproducibles

Un **build reproducible** es aquel que, dado el mismo codigo fuente y la misma
configuracion, produce un artefacto **identico bit a bit** cada vez.

### Por que importa para seguridad

| Aspecto | Build no reproducible | Build reproducible |
|---------|----------------------|-------------------|
| **Verificacion** | No puedes verificar que el artefacto corresponde al codigo | Cualquiera puede rebuildir y comparar |
| **Confianza** | Confias ciegamente en el pipeline | El artefacto se puede auditar independientemente |
| **Tampering** | No detectas manipulacion post-build | Si el hash no coincide, algo fue manipulado |
| **Regulacion** | Dificil demostrar integridad a auditores | Hash reproducible = evidencia solida |

### Obstaculos comunes

| Obstaculo | Ejemplo | Solucion |
|-----------|---------|----------|
| **Timestamps** | Fecha de build embebida en el binario | Usar `SOURCE_DATE_EPOCH` |
| **Orden de archivos** | Sistema de archivos ordena diferente | Forzar orden deterministico |
| **Dependencias flotantes** | `pip install flask` instala la ultima version | Lockfile con hashes |
| **Capas Docker** | Metadata del build varia | Multi-stage, `--build-arg` fijos |

```mermaid
flowchart LR
    subgraph Reproducible["Build Reproducible"]
        direction LR
        SRC[Codigo fuente<br/>commit abc123] --> B1[Build en CI<br/>Pipeline #42]
        SRC --> B2[Build local<br/>Auditor independiente]
        B1 --> H1["sha256:xyz..."]
        B2 --> H2["sha256:xyz..."]
        H1 --> |"Coinciden?"| CHECK{Verificar}
        H2 --> CHECK
        CHECK --> |"Si"| OK[Artefacto<br/>integro]
        CHECK --> |"No"| ALERT[ALERTA:<br/>posible tampering]
    end

    style OK fill:#2e7d32,color:#fff
    style ALERT fill:#d32f2f,color:#fff
```

---

## Resumen de controles para artefactos

| Control | Proposito | Implementacion |
|---------|-----------|----------------|
| **Inmutabilidad de tags** | Evitar sobreescritura de versiones | ACR tag immutability |
| **Digest pinning** | Referenciar artefactos por hash | `image@sha256:...` en YAML |
| **Prohibir `:latest`** | Evitar tags mutables en produccion | OPA policy, admission webhook |
| **SemVer estricto** | Versionado predecible y auditable | Convencion + CI validation |
| **Firma de artefactos** | Verificar origen y integridad | Cosign (Lab 7) |
| **SBOM vinculado** | Saber que contiene cada artefacto | SBOM atestado con Cosign |
| **Build reproducible** | Verificacion independiente | Lockfiles, timestamps fijos |
| **Escaneo pre-push** | No publicar imagenes vulnerables | Trivy scan antes de push |
| **Retencion y limpieza** | No acumular imagenes obsoletas | ACR retention policy |

---

## El artefacto en el contexto del pipeline

```mermaid
flowchart TB
    subgraph CI["Pipeline CI"]
        direction TB
        SAST[SAST] --> SCA[SCA + SBOM]
        SCA --> BUILD[Docker Build]
        BUILD --> SCAN[Image Scan<br/>Trivy]
        SCAN --> |"Sin CVE Critical/High"| PUSH[Push a ACR<br/>Tag: v1.2.3<br/>Inmutable]
        SCAN --> |"CVE Critical"| FAIL[Pipeline FALLA]
    end

    PUSH --> SIGN[Firma<br/>Cosign]
    SIGN --> ATTEST[Atestar SBOM<br/>Cosign attach]

    subgraph CD["Pipeline CD"]
        direction TB
        VERIFY[Verificar firma<br/>Cosign verify] --> DEPLOY[Deploy<br/>Digest pinning]
    end

    ATTEST --> VERIFY

    style BUILD fill:#046BD2,color:#fff
    style PUSH fill:#2e7d32,color:#fff
    style SIGN fill:#045CB4,color:#fff
    style FAIL fill:#d32f2f,color:#fff
    style VERIFY fill:#046BD2,color:#fff
```

---

## Resumen

```mermaid
mindmap
  root((Artefactos e<br/>Inmutabilidad))
    Que es un artefacto
      Imagenes Docker
      Paquetes
      Binarios
    Registros
      ACR
      Docker Hub
      Permisos criticos
    Inmutabilidad
      Tags no sobreescribibles
      Integridad garantizada
      Control de seguridad
    Versionado
      SemVer
      PATCH = fix seguridad
      Versiones exactas
    Digests SHA256
      Hash del contenido
      Inmutable por definicion
      Digest pinning
    Anti-patron latest
      No reproducible
      No auditable
      Prohibir en prod
    Builds reproducibles
      Mismo codigo = mismo hash
      Verificacion independiente
      Lockfiles
```

---

<div style="display: flex; justify-content: space-between; margin-top: 2rem;">
[:octicons-arrow-left-24: Anterior: Lab 5](../lab05-sca/index.md){ .md-button }
[Siguiente: Lab 6 — Build e Imagen :octicons-arrow-right-24:](../lab06-build/index.md){ .md-button .md-button--primary }
</div>

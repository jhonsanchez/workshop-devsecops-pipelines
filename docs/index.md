---
title: DevSecOps Pipelines Workshop
description: Workshop practico de seguridad en pipelines CI/CD para equipos de seguridad — by Entelgy
hide:
  - toc
  - navigation
---

<div class="hero" markdown>

# DevSecOps Pipelines Workshop

**Entiende el pipeline como un analista de seguridad.**
Aprende a auditar, instrumentar y gobernar pipelines CI/CD con controles
automatizados en cada etapa — desde el commit hasta produccion. Pensado para
equipos de seguridad que necesitan hablar el idioma de DevOps sin convertirse
en desarrolladores.

<div class="hero-buttons" markdown>
[Comenzar el Workshop](modulo0/index.md){ .md-button .md-button--primary }
[Ver en GitHub](https://github.com/jhonsanchez/workshop-devsecops-pipelines){ .md-button }
</div>

</div>

---

## El Workshop de un Vistazo

<div class="lab-meta">
  <div class="lab-meta-item">
    <strong>Duracion</strong>
    8–10 horas
  </div>
  <div class="lab-meta-item">
    <strong>Audiencia</strong>
    Equipos de Seguridad
  </div>
  <div class="lab-meta-item">
    <strong>Nivel</strong>
    Intermedio
  </div>
  <div class="lab-meta-item">
    <strong>Conceptos</strong>
    11 modulos teoricos
  </div>
  <div class="lab-meta-item">
    <strong>Labs</strong>
    11 practicos
  </div>
  <div class="lab-meta-item">
    <strong>Idioma</strong>
    Espanol
  </div>
  <div class="lab-meta-item">
    <strong>Plataforma</strong>
    GitHub Actions
  </div>
  <div class="lab-meta-item">
    <strong>Formato</strong>
    Presencial / Autoguiado
  </div>
</div>

---

## Estructura: Concepto + Lab

Este workshop alterna **modulos de concepto** (teoria con diagramas, incidentes reales y tablas) con **labs practicos** donde aplicas cada control en un pipeline real de GitHub Actions.

```mermaid
flowchart LR
    C1[Concepto 1<br/>CI/CD y Seguridad] --> L1[Lab 1<br/>Setup Proyecto]
    L1 --> C2[Concepto 2<br/>Anatomia Pipeline]
    C2 --> L2[Lab 2<br/>Pipeline Base]
    L2 --> C3[Concepto 3<br/>Secretos]
    C3 --> L3[Lab 3<br/>Deteccion Secretos]
    L3 --> C4[Concepto 4<br/>SAST]
    C4 --> L4[Lab 4<br/>SAST Semgrep]
    L4 --> C5[Concepto 5<br/>SCA]
    C5 --> L5[Lab 5<br/>SCA y SBOM]
    L5 --> C6[Concepto 6<br/>Artefactos]
    C6 --> L6[Lab 6<br/>Build e Imagen]
    L6 --> C7[Concepto 7<br/>Registros]
    C7 --> L7[Lab 7<br/>Firma Imagen]
    L7 --> C8[Concepto 8<br/>DAST]
    C8 --> L8[Lab 8<br/>OWASP ZAP]
    L8 --> C9[Concepto 9<br/>IaC]
    C9 --> L9[Lab 9<br/>Escaneo IaC]
    L9 --> C10[Concepto 10<br/>Despliegues]
    C10 --> L10[Lab 10<br/>Deploy]
    L10 --> C11[Concepto 11<br/>Monitorizacion]
    C11 --> L11[Lab 11<br/>Dashboard]

    style C1 fill:#046BD2,color:#fff
    style C2 fill:#046BD2,color:#fff
    style C3 fill:#046BD2,color:#fff
    style C4 fill:#046BD2,color:#fff
    style C5 fill:#046BD2,color:#fff
    style C6 fill:#046BD2,color:#fff
    style C7 fill:#046BD2,color:#fff
    style C8 fill:#046BD2,color:#fff
    style C9 fill:#046BD2,color:#fff
    style C10 fill:#046BD2,color:#fff
    style C11 fill:#046BD2,color:#fff
    style L1 fill:#041C2C,color:#fff
    style L2 fill:#041C2C,color:#fff
    style L3 fill:#041C2C,color:#fff
    style L4 fill:#041C2C,color:#fff
    style L5 fill:#041C2C,color:#fff
    style L6 fill:#041C2C,color:#fff
    style L7 fill:#041C2C,color:#fff
    style L8 fill:#041C2C,color:#fff
    style L9 fill:#041C2C,color:#fff
    style L10 fill:#041C2C,color:#fff
    style L11 fill:#041C2C,color:#fff
```

---

## Conceptos que cubriras

<div class="grid cards" markdown>

- :material-pipe: **Concepto 1 — CI/CD y Seguridad**

    Que es CI/CD, por que le importa al equipo de seguridad, shift-left y el
    pipeline como control de seguridad. Incidentes: SolarWinds, CodeCov.

    [:octicons-arrow-right-24: Ir al concepto](concepto01-cicd/index.md)

- :material-sitemap-outline: **Concepto 2 — Anatomia del Pipeline**

    Jerarquia de GitHub Actions: Pipeline > Stages > Jobs > Steps. Agentes,
    YAML, variables, secretos y service connections como vectores de ataque.

    [:octicons-arrow-right-24: Ir al concepto](concepto02-anatomia-pipeline/index.md)

- :material-key-alert: **Concepto 3 — Secretos en Codigo**

    Permanencia en Git, ciclo de vida de una fuga, gestion de secretos con
    Azure Key Vault e identidades gestionadas. Casos: Uber 2016, CircleCI.

    [:octicons-arrow-right-24: Ir al concepto](concepto03-secretos/index.md)

- :material-magnify-scan: **Concepto 4 — Analisis Estatico (SAST)**

    Pattern matching, ASTs, taint analysis. OWASP Top 10 mapeado a SAST.
    Como leer un reporte SAST: CWE, severidad, confianza.

    [:octicons-arrow-right-24: Ir al concepto](concepto04-sast/index.md)

- :material-package-variant-closed: **Concepto 5 — SCA y Cadena de Suministro**

    Dependencias transitivas, bases de datos CVE, SBOM. Ataques: typosquatting,
    dependency confusion. Casos: Log4Shell, event-stream, colors.js.

    [:octicons-arrow-right-24: Ir al concepto](concepto05-sca/index.md)

- :material-archive-lock: **Concepto 6 — Artefactos e Inmutabilidad**

    Registros, inmutabilidad, versionado semantico para seguridad, digests
    SHA256, builds reproducibles. Peligro del tag `:latest`.

    [:octicons-arrow-right-24: Ir al concepto](concepto06-artefactos/index.md)

- :material-certificate: **Concepto 7 — Registros y Confianza**

    Firma de imagenes con Cosign/Notation, politicas de admision, cadena de
    custodia digital, provenance y atestaciones SLSA.

    [:octicons-arrow-right-24: Ir al concepto](concepto07-registros-confianza/index.md)

- :material-web-check: **Concepto 8 — Pruebas Dinamicas (DAST)**

    Escaneo de aplicaciones en ejecucion, OWASP ZAP, diferencias con SAST,
    integracion en pipeline, manejo de falsos positivos.

    [:octicons-arrow-right-24: Ir al concepto](concepto08-dast/index.md)

- :material-terraform: **Concepto 9 — IaC y Seguridad**

    Infraestructura como Codigo, Checkov, OPA/Conftest, misconfiguraciones
    comunes en Terraform y Kubernetes.

    [:octicons-arrow-right-24: Ir al concepto](concepto09-iac/index.md)

- :material-rocket-launch: **Concepto 10 — Despliegues Seguros**

    Estrategias de despliegue (blue-green, canary), aprobaciones, environments,
    gates de seguridad y rollback automatico.

    [:octicons-arrow-right-24: Ir al concepto](concepto10-despliegues/index.md)

- :material-chart-timeline-variant-shimmer: **Concepto 11 — Monitorizacion**

    Observabilidad post-despliegue, alertas de seguridad, dashboards,
    metricas DORA desde la perspectiva de seguridad.

    [:octicons-arrow-right-24: Ir al concepto](concepto11-monitorizacion/index.md)

</div>

---

## Labs practicos

<div class="grid cards" markdown>

- :octicons-terminal-24: **Lab 1** — Proyecto GitHub Actions

    [:octicons-arrow-right-24: Ir al lab](lab01-setup/index.md)

- :octicons-terminal-24: **Lab 2** — Pipeline Base

    [:octicons-arrow-right-24: Ir al lab](lab02-pipeline-base/index.md)

- :octicons-terminal-24: **Lab 3** — Deteccion de Secretos

    [:octicons-arrow-right-24: Ir al lab](lab03-secretos/index.md)

- :octicons-terminal-24: **Lab 4** — SAST con Semgrep

    [:octicons-arrow-right-24: Ir al lab](lab04-sast/index.md)

- :octicons-terminal-24: **Lab 5** — SCA y SBOM

    [:octicons-arrow-right-24: Ir al lab](lab05-sca/index.md)

- :octicons-terminal-24: **Lab 6** — Build e Imagen

    [:octicons-arrow-right-24: Ir al lab](lab06-build/index.md)

- :octicons-terminal-24: **Lab 7** — Firma de Imagen

    [:octicons-arrow-right-24: Ir al lab](lab07-image-signing/index.md)

- :octicons-terminal-24: **Lab 8** — DAST con OWASP ZAP

    [:octicons-arrow-right-24: Ir al lab](lab08-dast/index.md)

- :octicons-terminal-24: **Lab 9** — Escaneo de IaC

    [:octicons-arrow-right-24: Ir al lab](lab09-iac/index.md)

- :octicons-terminal-24: **Lab 10** — Deploy con Aprobaciones

    [:octicons-arrow-right-24: Ir al lab](lab10-deploy/index.md)

- :octicons-terminal-24: **Lab 11** — Monitorizacion

    [:octicons-arrow-right-24: Ir al lab](lab11-monitorizacion/index.md)

</div>

---

## Arquitectura del Pipeline Final

El pipeline DevSecOps completo que construiras abarca once capas de seguridad:

```mermaid
flowchart TB
    subgraph DEV["Estacion de Trabajo"]
        A[Commit] --> B[Pre-commit hooks<br/>Secretos]
    end

    B --> C[Push / PR]

    subgraph CI["Pipeline CI"]
        C --> D[Deteccion Secretos<br/>Gitleaks]
        D --> E[SAST<br/>Semgrep]
        E --> F[SCA + SBOM<br/>Trivy]
        F --> G[Build Imagen<br/>Docker]
        G --> H[Escaneo Imagen<br/>Trivy]
        H --> I[Firma Imagen<br/>Cosign]
        I --> J[IaC Scan<br/>Checkov + OPA]
    end

    subgraph CD["Pipeline CD"]
        J --> K[Deploy Staging]
        K --> L[DAST<br/>OWASP ZAP]
        L --> M{Security Gate}
        M -->|Aprobado| N[Deploy Produccion]
        M -->|Rechazado| O[Bloqueo + Alerta]
    end

    subgraph OPS["Post-Despliegue"]
        N --> P[Health Checks]
        P --> Q[Dashboard Seguridad]
        Q --> R[Alertas y Metricas]
    end

    style DEV fill:#f0f5fa,stroke:#046BD2,color:#041C2C
    style CI fill:#e8f0fe,stroke:#046BD2,color:#041C2C
    style CD fill:#e0ecf8,stroke:#046BD2,color:#041C2C
    style OPS fill:#d8e4f0,stroke:#046BD2,color:#041C2C
```

---

## Prerequisitos

Antes de comenzar, asegurate de tener:

- [x] Una cuenta de **GitHub Actions** (gratuita)
- [ ] Una cuenta de **GitHub** con un repositorio personal
- [ ] **Docker Desktop** instalado y funcionando
- [ ] **Terraform** >= 1.6 instalado
- [ ] **Azure CLI** (`az`) instalado y autenticado
- [ ] **Python** >= 3.10 y `pip` disponibles
- [ ] **Git** >= 2.40 instalado
- [ ] Familiaridad basica con YAML y la linea de comandos

!!! tip "Guia de instalacion completa"
    Sigue la [Guia de Prerequisitos](modulo0/prerequisites.md) para instrucciones
    paso a paso en macOS, Linux y WSL2 antes de comenzar los labs.

---

## Impartido por Entelgy

Este workshop es impartido por [Entelgy](https://www.entelgy.com), consultora
europea especializada en transformacion digital, ciberseguridad y entrega
cloud-native.

---
tags:
  - lab
  - dashboard
  - metricas
  - seguridad
---

# Paso 2 -- Dashboard de Seguridad

!!! abstract "Objetivo"
    Construir un dashboard de seguridad en Azure DevOps que agregue los resultados de escaneo a lo largo de las ejecuciones del pipeline, revisar el pipeline completo, y discutir metricas de seguridad para reportes ejecutivos.

## 2.1 Crear el dashboard en Azure DevOps

1. Ve a **Overview** > **Dashboards** en Azure DevOps
2. Click en **+ New Dashboard**
3. Nombre: `DevSecOps Security Dashboard`
4. Visibilidad: Team Dashboard

## 2.2 Widgets recomendados

### Widget 1: Estado del ultimo pipeline

1. Click en **+ Add widget**
2. Selecciona **Build History** o **Deployment Status**
3. Configura para mostrar el pipeline DevSecOps
4. Tamano: 4x2

Este widget muestra el estado de cada stage del ultimo run, permitiendo ver de un vistazo si algun control de seguridad fallo.

### Widget 2: Tendencia de builds (pass/fail)

1. Agrega el widget **Chart for Build History**
2. Configura:
    - Pipeline: tu pipeline DevSecOps
    - Duracion: ultimos 30 dias
    - Tipo: stacked bar (pass vs fail)
3. Tamano: 4x2

!!! tip "Tendencia de fallos de seguridad"
    Si los builds empiezan a fallar mas frecuentemente por gates de seguridad, puede indicar que se estan introduciendo mas vulnerabilidades. Si fallan menos, el equipo esta mejorando sus practicas.

### Widget 3: Resultados de tests

Si publicas resultados como tests de JUnit, puedes usar:

1. Widget **Test Results Trend**
2. Configura para el pipeline DevSecOps
3. Muestra pass/fail/skip a lo largo del tiempo

### Widget 4: Work Items de seguridad

1. Agrega el widget **Query Results**
2. Crea un query que filtre work items con tag "seguridad":

```text title="Query: Work Items de Seguridad"
SELECT [System.Id], [System.Title], [System.State], [System.Tags]
FROM workitems
WHERE [System.Tags] CONTAINS "seguridad"
  AND [System.State] <> "Closed"
ORDER BY [Microsoft.VSTS.Common.Priority] ASC
```

### Widget 5: Metricas personalizadas

Para metricas mas detalladas de seguridad, crea un script que genere datos y los publique:

```yaml title="vulnerable-app/azure-pipelines.yml -- Publicar metricas de seguridad"
          # --- Recopilar metricas de seguridad ---
          - script: |
              echo "=== Recopilando metricas de seguridad ==="

              # Crear archivo de resumen
              SUMMARY="$(Build.ArtifactStagingDirectory)/security-summary.json"

              python3 << 'PYEOF'
              import json
              import os
              import glob

              summary = {
                  "build_id": os.environ.get("BUILD_BUILDID", "unknown"),
                  "commit": os.environ.get("BUILD_SOURCEVERSION", "unknown"),
                  "branch": os.environ.get("BUILD_SOURCEBRANCHNAME", "unknown"),
                  "timestamp": os.environ.get("BUILD_QUEUEDBY", "unknown"),
                  "scans": {}
              }

              # Trivy Image Report
              trivy_path = glob.glob("**/trivy-image-report.json", recursive=True)
              if trivy_path:
                  with open(trivy_path[0]) as f:
                      trivy = json.load(f)
                  results = trivy.get("Results", [])
                  vulns = {"CRITICAL": 0, "HIGH": 0, "MEDIUM": 0, "LOW": 0}
                  for result in results:
                      for vuln in result.get("Vulnerabilities", []):
                          sev = vuln.get("Severity", "UNKNOWN")
                          if sev in vulns:
                              vulns[sev] += 1
                  summary["scans"]["trivy_image"] = vulns

              # ZAP Report
              zap_path = glob.glob("**/zap-full-report.json", recursive=True)
              if zap_path:
                  with open(zap_path[0]) as f:
                      zap = json.load(f)
                  sites = zap.get("site", [])
                  alerts = sites[0].get("alerts", []) if sites else []
                  risk_map = {"0": "Informational", "1": "Low", "2": "Medium", "3": "High"}
                  zap_summary = {"High": 0, "Medium": 0, "Low": 0, "Informational": 0}
                  for alert in alerts:
                      risk = risk_map.get(alert.get("riskcode", "0"), "Unknown")
                      if risk in zap_summary:
                          zap_summary[risk] += 1
                  summary["scans"]["zap"] = zap_summary

              # Checkov Report
              checkov_path = glob.glob("**/results_json.json", recursive=True)
              if checkov_path:
                  with open(checkov_path[0]) as f:
                      checkov = json.load(f)
                  passed = checkov.get("summary", {}).get("passed", 0)
                  failed = checkov.get("summary", {}).get("failed", 0)
                  summary["scans"]["checkov"] = {
                      "passed": passed,
                      "failed": failed
                  }

              # Escribir resumen
              output_path = os.path.join(
                  os.environ.get("BUILD_ARTIFACTSTAGINGDIRECTORY", "."),
                  "security-summary.json"
              )
              with open(output_path, "w") as f:
                  json.dump(summary, f, indent=2)

              # Imprimir resumen
              print(json.dumps(summary, indent=2))
              PYEOF

              echo ""
              echo "=== Resumen de seguridad generado ==="
            displayName: 'Recopilar metricas de seguridad'
            continueOnError: true

          # --- Publicar resumen ---
          - task: PublishBuildArtifacts@1
            displayName: 'Publicar resumen de seguridad'
            inputs:
              PathtoPublish: '$(Build.ArtifactStagingDirectory)/security-summary.json'
              ArtifactName: 'security-summary'
              publishLocation: 'Container'
            condition: always()
```

## 2.3 Metricas de seguridad clave

Para reportes ejecutivos y seguimiento continuo, estas son las metricas esenciales:

### Metricas de vulnerabilidades

| Metrica | Descripcion | Target |
|---------|-------------|--------|
| **MTTR** (Mean Time to Remediate) | Tiempo promedio desde deteccion hasta correccion | < 7 dias (Critical), < 30 dias (High) |
| **Vulnerability Density** | Vulnerabilidades por 1000 lineas de codigo | Tendencia descendente |
| **Open Critical/High** | Numero de vulnerabilidades abiertas Critical/High | 0 en produccion |
| **False Positive Rate** | % de hallazgos que son falsos positivos | < 20% |

### Metricas de pipeline

| Metrica | Descripcion | Target |
|---------|-------------|--------|
| **Security Gate Pass Rate** | % de builds que pasan todos los gates | > 80% |
| **Pipeline Duration** | Tiempo total del pipeline | < 30 min (sin aprobaciones) |
| **Scan Coverage** | % de componentes escaneados | 100% |
| **Time to Approval** | Tiempo desde que el pipeline pide aprobacion hasta que se aprueba | < 4 horas |

### Metricas de compliance

| Metrica | Descripcion | Target |
|---------|-------------|--------|
| **IaC Compliance** | % de checks Checkov que pasan | > 90% |
| **Signed Images** | % de imagenes en produccion que estan firmadas | 100% |
| **Dependencies Up-to-date** | % de dependencias sin CVEs conocidos | > 95% |
| **Security Headers** | % de endpoints con headers de seguridad | 100% |

## 2.4 Revision del pipeline completo

Veamos el pipeline completo construido a lo largo de los 11 laboratorios:

```yaml title="vulnerable-app/azure-pipelines.yml -- Pipeline FINAL (estructura)"
trigger:
  branches:
    include:
      - main

pool:
  vmImage: 'ubuntu-latest'

variables:
  - group: devsecops-workshop-secrets

stages:
  # === FASE 1: Analisis estatico ===
  - stage: Checkout                # Lab 1: Validacion del repositorio
  - stage: SecretsDetection        # Lab 3: Gitleaks
  - stage: SAST                    # Lab 4: Semgrep
  - stage: SCA                     # Lab 5: Trivy fs + SBOM

  # === FASE 2: Build y verificacion ===
  - stage: Build                   # Lab 6: Docker build + push ACR
  - stage: ImageScan               # Lab 7: Trivy image + Cosign sign

  # === FASE 3: Tests dinamicos e IaC ===
  - stage: DAST                    # Lab 8: OWASP ZAP
  - stage: IaCScan                 # Lab 9: Checkov + Conftest

  # === FASE 4: Deploy controlado ===
  - stage: DeployStaging           # Lab 10: Terraform + aprobacion
  - stage: DeployProduction        # Lab 10: Cosign verify + Terraform + aprobacion

  # === FASE 5: Monitorizacion ===
  - stage: Monitor                 # Lab 11: Health checks + alertas
```

## 2.5 Tabla resumen de herramientas

| Herramienta | Tipo | Que detecta | Stage |
|------------|------|-------------|-------|
| **Gitleaks** | Secret Detection | Claves API, passwords, tokens en codigo | SecretsDetection |
| **Semgrep** | SAST | SQL injection, XSS, crypto debil, etc. | SAST |
| **Trivy fs** | SCA | Dependencias vulnerables (PyPI, npm, etc.) | SCA |
| **Docker** | Build | Imagen de contenedor | Build |
| **Trivy image** | Container Scan | CVEs en SO base + dependencias | ImageScan |
| **Cosign** | Image Signing | Integridad y procedencia de imagen | ImageScan + DeployProduction |
| **OWASP ZAP** | DAST | Vulnerabilidades en app corriendo (SQLi, XSS) | DAST |
| **Checkov** | IaC Scan | Misconfiguraciones en Terraform | IaCScan |
| **Conftest** | Policy as Code | Politicas personalizadas OPA/Rego | IaCScan |
| **Terraform** | IaC Deploy | Infraestructura como codigo | DeployStaging, DeployProduction |
| **Azure Monitor** | Monitoring | Alertas de seguridad post-deploy | Monitor |

## 2.6 Discusion: madurez DevSecOps

El pipeline que hemos construido representa un nivel de madurez avanzado. Para evaluar donde esta tu organizacion:

### Nivel 1: Basico

- [x] Pipeline CI/CD funcional
- [x] Deteccion de secretos
- [ ] Algun escaneo de seguridad (SAST o SCA)

### Nivel 2: Integrado

- [x] SAST + SCA en el pipeline
- [x] Build de contenedor con buenas practicas
- [x] Escaneo de imagen
- [ ] Gate basico (fallar en CRITICAL)

### Nivel 3: Avanzado

- [x] DAST integrado
- [x] Firma de imagen (Cosign)
- [x] IaC scan con politicas custom (OPA)
- [x] Aprobaciones de seguridad
- [x] Multiples entornos (staging + production)

### Nivel 4: Optimizado

- [x] Monitorizacion post-deploy
- [x] Dashboard de metricas de seguridad
- [x] Verificacion de firma pre-deploy
- [ ] Feedback loop automatico (alertas -> work items)
- [ ] Security champions en cada equipo
- [ ] Threat modeling integrado

!!! info "Mejora continua"
    DevSecOps no es un destino, es un viaje. El pipeline que construimos hoy se mejora continuamente: se ajustan umbrales, se agregan reglas, se optimizan tiempos y se adapta a nuevas amenazas.

## 2.7 Proximos pasos recomendados

Despues del workshop, considera implementar:

1. **Runtime Security**: Herramientas como Falco o Sysdig para detectar comportamiento anomalo en contenedores en ejecucion
2. **SBOM continuo**: Publicar SBOMs en cada release y monitorear nuevos CVEs contra el inventario
3. **Threat Modeling**: Integrar sesiones de modelado de amenazas en el ciclo de sprint
4. **Bug Bounty**: Programa de recompensas para investigadores de seguridad externos
5. **Chaos Engineering**: Inyectar fallos para validar la resiliencia de los controles de seguridad

## 2.8 Resumen del Lab 11

| Control | Implementacion | Estado |
|---------|---------------|--------|
| Health checks | curl /health post-deploy | Automatizado |
| Smoke tests | 5 tests funcionales | Automatizado |
| Test de rendimiento | 10 requests, umbral 2s | Automatizado |
| Alertas HTTP 500 | Azure Monitor metric | Configurado |
| Alertas brute force | Azure Monitor log query | Configurado |
| Dashboard | Azure DevOps Dashboard | Configurado |
| Metricas agregadas | security-summary.json | Artefacto por run |

!!! success "Paso Completado"
    Has completado el Lab 11 y con el, todo el workshop DevSecOps. Tu pipeline cubre el ciclo completo: desde la deteccion de secretos en el codigo hasta la monitorizacion de la aplicacion en produccion. Cada herramienta agrega una capa de seguridad, y juntas proporcionan una postura de seguridad robusta y medible.

---

<div style="display: flex; justify-content: space-between; margin-top: 2rem;">
  <a href="step1.md" class="md-button">Anterior: Health Checks y Alertas</a>
  <a href="../cierre/index.md" class="md-button md-button--primary">Siguiente: Cierre del Workshop</a>
</div>

---
title: "Resultado 9 — Deploy a Produccion"
description: Verificacion de firma con Cosign antes del despliegue a produccion y uso del GitHub Environment con aprobacion.
tags:
  - Resultados
  - Produccion
  - Cosign
  - Firma digital
  - Deploy
---

# Stage 9 — Deploy a Produccion

<div class="lab-meta">
  <div class="lab-meta-item">
    <strong>Herramienta</strong>
    Cosign (verificacion)
  </div>
  <div class="lab-meta-item">
    <strong>Environment</strong>
    production
  </div>
  <div class="lab-meta-item">
    <strong>Pre-condicion</strong>
    Firma keyless verificada
  </div>
  <div class="lab-meta-item">
    <strong>Aprobacion</strong>
    Manual (si esta configurada)
  </div>
</div>

---

## Que hace este stage

Antes de desplegar a produccion, este job usa **Cosign** para verificar que la imagen Docker fue firmada en el Stage 5 por el propio pipeline de GitHub Actions. Solo si la verificacion es exitosa, el despliegue procede. Ademas, usa el **GitHub Environment** `production`, que puede requerir aprobacion manual de un revisor designado.

---

## Output esperado en el log

### Step: Verificar firma de imagen

```text
Verification for ghcr.io/<org>/devsecops-vulnerable-app@sha256:abc123... --
The following checks were performed on each of these signatures:
  - The cosign claims were validated
  - Existence of the claims in the transparency log was verified offline
  - The code-signing certificate was verified using trusted certificate authority

Certificate subject: https://github.com/<org>/<repo>/.github/workflows/devsecops.yml@refs/heads/main
Certificate issuer URL: https://token.actions.githubusercontent.com

Firma de imagen verificada correctamente
```

!!! success "Mensaje clave"
    **"Firma de imagen verificada correctamente"** confirma que la imagen que se va a desplegar es exactamente la que fue construida y firmada por este pipeline, sin alteraciones.

### Step: Deploy a Produccion

```text
Desplegando a produccion...
```

---

## Job Summary esperado

El step final escribe un resumen en el **Job Summary** de GitHub Actions:

```markdown
### Deploy a Produccion :rocket:
- **Imagen:** ghcr.io/<org>/devsecops-vulnerable-app:42
- **Firma:** Verificada con Cosign keyless
```

---

## Aprobacion manual

!!! info "Environment protection rules"
    Si configuraste **protection rules** en el environment `production` (Settings > Environments), el pipeline se pausa con un boton **"Review deployments"**. Si no hay reglas configuradas, el job se ejecuta automaticamente.

---

## Donde verificar en GitHub

!!! tip "Puntos de verificacion"

    1. **Actions** > click en el run > job **9. Deploy a Produccion**
    2. Si hay aprobacion pendiente, veras un boton **"Review deployments"** en el run
    3. Expandir step **"Verificar firma de imagen"** para ver el output de Cosign
    4. **Actions** > click en el run > **Summary** > seccion "Deploy a Produccion"

---

## Que pasa si la firma falla

!!! danger "Si Cosign no puede verificar la firma"
    ```text
    Error: cosign verify: no matching signatures
    ```
    Esto significa que:

    - La imagen fue modificada despues de la firma
    - El digest no coincide con el firmado en Stage 5
    - Las claims de identidad del certificado no coinciden con el repositorio

    El job falla y **el despliegue a produccion no ocurre**. Este es el comportamiento esperado: protege contra imagenes alteradas.

---

<div style="display: flex; justify-content: space-between; margin-top: 2rem;">
  <a href="../08-dast/" class="md-button">:material-arrow-left: 8. DAST (ZAP)</a>
  <a href="../10-monitor/" class="md-button md-button--primary">10. Monitorizacion :material-arrow-right:</a>
</div>

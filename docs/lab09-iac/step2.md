---
tags:
  - lab
  - checkov
  - pipeline
  - sarif
---

# Paso 2 -- Stage IaC en el Pipeline

!!! abstract "Objetivo"
    Agregar el stage `IaCScan` al pipeline de GitHub Actions usando Checkov en Docker, configurar el gate para fallar en vulnerabilidades CRITICAL, y publicar el reporte SARIF como artefacto.

## 2.1 Agregar el stage IaCScan

Abre `vulnerable-app/.github/workflows/devsecops.yml` y agrega el stage `IaCScan` despues del stage `DAST`:

```yaml title="vulnerable-app/.github/workflows/devsecops.yml -- Job iac-scan"
  # ============================================================
  # Lab 9: Escaneo de IaC con Checkov + Conftest
  # ============================================================
  iac-scan:
    name: '6. Escaneo de IaC'
    runs-on: ubuntu-latest
    needs: image-scan
    steps:
      - uses: actions/checkout@v4

      # --- Escaneo con Checkov (accion oficial) ---
      - name: Checkov — IaC Scan
        uses: bridgecrewio/checkov-action@master
        with:
          directory: vulnerable-app/infrastructure/
          framework: terraform
          output_format: cli,sarif
          output_file_path: console,checkov-results.sarif
          soft_fail: true

      # --- Publicar SARIF en GitHub Security ---
      - name: Upload SARIF a GitHub Security
        uses: github/codeql-action/upload-sarif@v3
        if: always()
        with:
          sarif_file: checkov-results.sarif
          category: checkov
```

## 2.2 Entender la configuracion de Checkov en Docker

| Parametro | Valor | Descripcion |
|-----------|-------|-------------|
| `-v .../infrastructure:/tf:ro` | Volume mount read-only | Monta el directorio Terraform sin poder modificarlo |
| `-d /tf` | Directorio a escanear | Ruta dentro del contenedor |
| `--framework terraform` | Solo Terraform | Evita escanear otros tipos de archivos |
| `--output cli` | Formato tabla | Legible en los logs |
| `--output json` | Formato JSON | Para procesamiento automatizado |
| `--output sarif` | Formato SARIF | Para integracion con herramientas |
| `--check-severity HIGH` | Solo HIGH | Filtrar checks por severidad |
| `--compact` | Salida compacta | Menos verboso para los logs |

## 2.3 Configurar archivo .checkov.yml

Puedes crear un archivo de configuracion para Checkov que se aplique automaticamente:

```yaml title="vulnerable-app/infrastructure/.checkov.yml"
# Checkov configuration
# Referencia: https://www.checkov.io/2.Basics/CLI%20Command%20Reference.html

# Frameworks a escanear
framework:
  - terraform

# Formato de salida
output:
  - cli

# Compactar salida
compact: true

# Checks a saltar (falsos positivos confirmados)
skip-check:
  # - CKV2_AZURE_tag  # Descomentar si no usas tags en el workshop

# Severidad minima para reportar
# check-severity: HIGH

# Directorio a escanear
directory:
  - .
```

!!! tip "Archivo de configuracion vs parametros CLI"
    El archivo `.checkov.yml` es util para mantener la configuracion versionada. Los parametros CLI sobreescriben la configuracion del archivo.

## 2.4 Integrar SARIF con GitHub Actions

El formato SARIF permite visualizar los resultados directamente en GitHub Actions. Agrega este paso para publicar los resultados:

```yaml title="Publicar SARIF en GitHub Security (opcional)"
          # --- Publicar SARIF en la pestana Security de GitHub ---
          - name: Upload SARIF a GitHub Security
            uses: github/codeql-action/upload-sarif@v3
            if: always()
            with:
              sarif_file: checkov-results.sarif
              category: checkov
```

!!! info "GitHub Security Tab"
    Los resultados SARIF se visualizan directamente en la pestana **Security** > **Code scanning alerts** del repositorio en GitHub. No se necesita extension adicional.

## 2.5 Excluir checks especificos

En algunos casos necesitaras excluir checks que no aplican a tu contexto:

```yaml title="Checkov con exclusiones"
      - name: Checkov (con exclusiones)
        uses: bridgecrewio/checkov-action@master
        with:
          directory: vulnerable-app/infrastructure/
          framework: terraform
          skip_check: CKV2_AZURE_tag,CKV2_AZURE_18
          output_format: cli
          soft_fail: true
```

!!! warning "Documentar exclusiones"
    Cada check excluido debe tener una justificacion documentada. Nunca excluyas un check solo porque falla. Usa el archivo `.checkov.yml` con comentarios explicando por que se excluye cada check.

## 2.6 Verificar en GitHub Actions

1. Haz commit y push del pipeline actualizado
2. Ve a la pestana **Actions** en tu repositorio de GitHub > click en el ultimo workflow run
3. El job **Escaneo de IaC** deberia mostrar:
    - Checkov escaneando los archivos Terraform
    - Lista de checks PASSED y FAILED
    - Reporte SARIF subido a GitHub Security
4. Ve a **Security** > **Code scanning alerts** para ver los hallazgos de Checkov

!!! success "Paso Completado"
    Has integrado Checkov en el pipeline. Ahora el Terraform se escanea automaticamente en cada push, y los resultados estan disponibles como artefactos. En el siguiente paso agregaremos politicas personalizadas con OPA/Conftest.

---

<div style="display: flex; justify-content: space-between; margin-top: 2rem;">
  <a href="step1.md" class="md-button">Anterior: Checkov Local</a>
  <a href="step3.md" class="md-button md-button--primary">Siguiente: Politicas OPA</a>
</div>

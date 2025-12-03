# OCCT Linux Stress Test

Herramienta en Bash inspirada en OCCT para **probar la estabilidad de tu equipo en Linux** (CPU y RAM) y generar un informe con la información más importante del sistema y de la prueba.

Pensado para usarlo en **Kali Linux** (o cualquier distro basada en Debian) como utilidad rápida antes de hacer prácticas de ciberseguridad o montar laboratorios.

---

## Características

- 🔥 **Stress test de CPU y memoria RAM**
  - Lanza una prueba de carga configurable durante _X_ minutos.
  - Usa herramientas clásicas de estrés en Linux (por ejemplo `stress` / `stress-ng`).

- 🧠 **Información detallada del sistema**
  - Modelo de CPU y número aproximado de núcleos.
  - Memoria RAM total y disponible.
  - Información básica del sistema (hostname, kernel, distribución, etc.).

- 🌡️ **Monitorización de temperaturas**
  - Consulta de sensores (si `lm-sensors` está configurado).
  - Útil para ver cómo se comportan las temperaturas durante la prueba.

- 📝 **Generación de informe**
  - Guarda un archivo de informe con marca de tiempo en la carpeta `reports/`.
  - Incluye:
    - Fecha y hora de la prueba.
    - Parámetros usados (duración, tipo de estrés, etc.).
    - Resumen de recursos del sistema.
    - Resultados básicos del test.

---

## Requisitos

- Linux (probado en **Kali Linux**).
- Bash.
- Paquetes recomendados:
  - `stress` o `stress-ng`
  - `lm-sensors` (para ver temperaturas)
- Permisos para instalar paquetes (si no están ya en el sistema).

Para instalarlos en Debian/Kali:

```bash
sudo apt update
sudo apt install stress stress-ng lm-sensors
sudo sensors-detect

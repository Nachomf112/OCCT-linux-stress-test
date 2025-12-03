#!/usr/bin/env bash

# ============================================================
#  occt_linux.sh – Mini-OCCT Linux (CPU/RAM + HTML + System Info)
#  Autor: Nacho Menárguez - Menarguez-IA-Solutions
# ============================================================

# ------------------ COLORES -------------------------------
NC="\e[0m"
BOLD="\e[1m"
DIM="\e[2m"
RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
BLUE="\e[34m"
MAGENTA="\e[35m"
CYAN="\e[36m"

# ------------------ BANNER --------------------------------
banner() {
  clear
  echo -e "${CYAN}============================================================${NC}"
  echo -e "  ${BOLD}Mini-OCCT Linux - Menarguez-IA-Solutions${NC}"
  echo -e "  ${DIM}Stress test de CPU/RAM + informe HTML con gráficas${NC}"
  echo -e "${CYAN}============================================================${NC}"
  echo
}

# ------------------ MENÚ PRINCIPAL ------------------------
mostrar_menu() {
  banner
  echo -e "${GREEN}1)${NC} Test rápido   (${YELLOW}5 min${NC}, intervalo ${YELLOW}5 s${NC})"
  echo -e "${GREEN}2)${NC} Test intenso  (${YELLOW}15 min${NC}, intervalo ${YELLOW}3 s${NC})"
  echo -e "${GREEN}3)${NC} Test personalizado"
  echo -e "${GREEN}4)${NC} Salir"
  echo
  read -rp "Elige una opción [1-4]: " OPCION
}

# ------------------ RUTAS / ARCHIVOS ----------------------
LOG_DIR="$HOME/occt_linux_logs"
mkdir -p "$LOG_DIR"
BASE_NAME="occt_$(date +%Y%m%d_%H%M%S)"
LOG_FILE="$LOG_DIR/${BASE_NAME}.csv"
HTML_FILE="$LOG_DIR/${BASE_NAME}.html"
FECHA_HUMANA="$(date '+%d/%m/%Y %H:%M:%S')"

# ------------------ DEPENDENCIAS --------------------------
check_dep() {
    local cmd="$1"
    local pkg="$2"

    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo -e "  ${RED}[-] Falta '${cmd}'${NC} (paquete: ${pkg})"
        FALTAN+=("$pkg")
    fi
}

FALTAN=()
check_dep sensors lm-sensors
check_dep stress-ng stress-ng
check_dep mpstat sysstat

if lspci | grep -qi nvidia >/dev/null 2>&1; then
    check_dep nvidia-smi "nvidia-utils / nvidia-smi"
fi

if ((${#FALTAN[@]} > 0)); then
    echo
    echo -e "${YELLOW}[!] Faltan paquetes:${NC} ${FALTAN[*]}"
    read -rp "¿Quieres instalarlos con apt? [s/N] " resp
    if [[ "$resp" =~ ^[sS]$ ]]; then
        echo -e "${CYAN}[+] Instalando dependencias...${NC}"
        sudo apt update
        sudo apt install -y "${FALTAN[@]}"

        echo
        echo -e "${CYAN}[+] Verificando instalación...${NC}"
        FALTAN_POST=()
        command -v sensors >/dev/null 2>&1   || FALTAN_POST+=("lm-sensors")
        command -v stress-ng >/dev/null 2>&1 || FALTAN_POST+=("stress-ng")
        command -v mpstat >/dev/null 2>&1    || FALTAN_POST+=("sysstat")
        if lspci | grep -qi nvidia >/dev/null 2>&1; then
            command -v nvidia-smi >/dev/null 2>&1 || FALTAN_POST+=("nvidia-utils / nvidia-smi")
        fi

        if ((${#FALTAN_POST[@]} > 0)); then
            echo -e "${RED}[!] Siguen faltando paquetes:${NC} ${FALTAN_POST[*]}"
            echo "No se puede continuar de forma segura."
            exit 1
        else
            echo -e "${GREEN}[+] Todas las dependencias están instaladas.${NC}"
        fi
    else
        echo -e "${YELLOW}[!] Has elegido no instalar los paquetes faltantes.${NC}"
        if ! command -v stress-ng >/dev/null 2>&1; then
            echo -e "${RED}[-] Falta 'stress-ng'. Saliendo...${NC}"
            exit 1
        fi
    fi
fi

# ------------------ INFORMACIÓN DEL SISTEMA --------------
recoger_system_info() {
    SI_HOSTNAME="$(hostname 2>/dev/null || echo 'No detectado')"

    # SO
    if command -v lsb_release >/dev/null 2>&1; then
        SI_OS="$(lsb_release -d 2>/dev/null | cut -f2-)"
    elif [ -f /etc/os-release ]; then
        . /etc/os-release
        SI_OS="$PRETTY_NAME"
    else
        SI_OS="No detectado"
    fi

    # Kernel
    SI_KERNEL="$(uname -r 2>/dev/null || echo 'No detectado')"

    # CPU (forzamos locale en inglés para que los campos de lscpu sean consistentes)
    if command -v lscpu >/dev/null 2>&1; then
        SI_CPU_MODEL="$(LC_ALL=C lscpu 2>/dev/null | \
            awk -F: '/^Model name/ {sub(/^ +/,"",$2); print $2; exit}')"

        SI_CPU_CORES="$(LC_ALL=C lscpu 2>/dev/null | \
            awk -F: '/^Core\(s\) per socket/ {sub(/^ +/,"",$2); print $2; exit}')"
    fi
    [ -z "$SI_CPU_MODEL" ] && SI_CPU_MODEL="No detectado"
    [ -z "$SI_CPU_CORES" ] && SI_CPU_CORES="No detectado"

    # Hilos lógicos
    if command -v nproc >/dev/null 2>&1; then
        SI_CPU_THREADS="$(nproc)"
    else
        SI_CPU_THREADS="No detectado"
    fi

    # RAM total (RAM asignada a la VM / sistema actual)
    SI_RAM_TOTAL_MB="$(free -m | awk '/^Mem:/ {print $2}' 2>/dev/null)"
    [ -z "$SI_RAM_TOTAL_MB" ] && SI_RAM_TOTAL_MB="No detectado"

    # GPU (descripción)
    if command -v lspci >/dev/null 2>&1; then
        SI_GPU="$(lspci | grep -iE 'vga|3d|display' | head -n1 | cut -d: -f3- | sed 's/^ //')"
    fi
    [ -z "$SI_GPU" ] && SI_GPU="No detectado"

    # Discos físicos visibles desde el sistema actual (VM o físico)
    SI_DISKS_ROWS=""
    if command -v lsblk >/dev/null 2>&1; then
        while read -r name size type model; do
            [ "$type" != "disk" ] && continue
            [ -z "$model" ] && model="Desconocido"
            SI_DISKS_ROWS+="<tr><td>/dev/${name}</td><td>${size}</td><td>${model}</td></tr>"
        done < <(lsblk -d -o NAME,SIZE,TYPE,MODEL -n 2>/dev/null)
    fi
    if [ -z "$SI_DISKS_ROWS" ]; then
        SI_DISKS_ROWS="<tr><td colspan=\"3\">No se han podido enumerar discos (lsblk no disponible o sin permisos).</td></tr>"
    fi

    # Escapar comillas dobles por si acaso
    SI_OS=${SI_OS//\"/\'}
    SI_CPU_MODEL=${SI_CPU_MODEL//\"/\'}
    SI_GPU=${SI_GPU//\"/\'}
}

recoger_system_info

# ------------------ ELEGIR TIPO DE TEST -------------------
DURACION=""
INTERVALO=""

while true; do
  mostrar_menu
  case "$OPCION" in
    1)
      DURACION=300
      INTERVALO=5
      break
      ;;
    2)
      DURACION=900
      INTERVALO=3
      break
      ;;
    3)
      read -rp "Duración del test (segundos): " DURACION
      read -rp "Intervalo entre muestras (segundos): " INTERVALO
      [[ -z "$DURACION" ]] && DURACION=600
      [[ -z "$INTERVALO" ]] && INTERVALO=5
      break
      ;;
    4)
      echo -e "${CYAN}Saliendo...${NC}"
      exit 0
      ;;
    *)
      echo -e "${RED}Opción no válida.${NC}"
      sleep 1
      ;;
  esac
done

banner
echo -e "${BOLD}Mini-OCCT Linux – Stress test CPU+RAM con logging${NC}"
echo
echo -e "  ${CYAN}Autor   :${NC} Nacho Menárguez - Menarguez-IA-Solutions"
echo -e "  ${CYAN}Duración:${NC} ${DURACION} s"
echo -e "  ${CYAN}Intervalo:${NC} ${INTERVALO} s"
echo -e "  ${CYAN}Log CSV :${NC} ${LOG_FILE}"
echo
echo -e "${YELLOW}[!] Esto va a poner CPU y RAM al 100%. Vigila las temperaturas.${NC}"
echo
read -rp "¿Empezar el stress test ahora? [s/N] " resp
if [[ ! "$resp" =~ ^[sS]$ ]]; then
    echo -e "${CYAN}Cancelado por el usuario.${NC}"
    exit 0
fi

# ------------------ FUNCIÓN DE MÉTRICAS -------------------
obtener_metricas() {
    local timestamp cpu_temp cpu_freq cpu_usage mem_total mem_used
    local gpu_temp gpu_usage gpu_mem_used gpu_mem_total

    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"

    # Temperatura CPU
    local sline
    sline="$(sensors 2>/dev/null | egrep 'Package id 0:|Tctl:|Tdie:' | head -n1)"
    if [ -n "$sline" ]; then
        cpu_temp="${sline#*+}"
        cpu_temp="${cpu_temp%%°C*}"
    else
        cpu_temp="NA"
    fi

    # Frecuencia CPU (cpu0) desde sysfs (kHz -> MHz)
    if [ -f /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq ]; then
        local khz
        khz="$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq 2>/dev/null)"
        if [ -n "$khz" ]; then
            cpu_freq=$((khz / 1000))
        else
            cpu_freq="NA"
        fi
    else
        cpu_freq="NA"
    fi

    # Uso CPU con mpstat (100 - idle) con coma decimal
    if command -v mpstat >/dev/null 2>&1; then
        local line idle idle_int
        line="$(mpstat 1 1 | grep 'all' | tail -n1)"
        if [ -n "$line" ]; then
            line="$(echo "$line" | tr -s ' ')"
            set -- $line
            idle="${12:-0}"

            # mpstat puede devolver 2,08 -> lo pasamos a 2.08 y cogemos la parte entera
            idle="${idle/,/.}"
            idle_int="${idle%.*}"

            if [[ "$idle_int" =~ ^[0-9]+$ ]]; then
                cpu_usage=$((100 - idle_int))
            else
                cpu_usage="NA"
            fi
        else
            cpu_usage="NA"
        fi
    else
        cpu_usage="NA"
    fi

    # Memoria (MB) con free
    local mem_line
    mem_line="$(free -m | grep -E '^Mem:')"
    if [ -n "$mem_line" ]; then
        mem_line="$(echo "$mem_line" | tr -s ' ')"
        set -- $mem_line
        mem_total="$2"
        mem_used="$3"
    else
        mem_total="NA"
        mem_used="NA"
    fi

    # GPU NVIDIA
    if command -v nvidia-smi >/dev/null 2>&1; then
        local gl
        gl="$(nvidia-smi --query-gpu=temperature.gpu,utilization.gpu,memory.used,memory.total --format=csv,noheader,nounits 2>/dev/null | head -n1)"
        if [ -n "$gl" ]; then
            gl="${gl//,/ }"
            set -- $gl
            gpu_temp="$1"
            gpu_usage="$2"
            gpu_mem_used="$3"
            gpu_mem_total="$4"
        else
            gpu_temp="NA"; gpu_usage="NA"; gpu_mem_used="NA"; gpu_mem_total="NA"
        fi
    else
        gpu_temp="NA"; gpu_usage="NA"; gpu_mem_used="NA"; gpu_mem_total="NA"
    fi

    echo "$timestamp,$cpu_temp,$cpu_freq,$cpu_usage,$mem_used,$mem_total,$gpu_temp,$gpu_usage,$gpu_mem_used,$gpu_mem_total"
}

# ------------------ CABECERA CSV --------------------------
echo "timestamp,cpu_temp_c,cpu_freq_mhz,cpu_usage_pct,mem_used_mb,mem_total_mb,gpu_temp_c,gpu_usage_pct,gpu_mem_used_mb,gpu_mem_total_mb" > "$LOG_FILE"

# ------------------ STRESS TEST ---------------------------
echo -e "${CYAN}[+] Lanzando stress-ng...${NC}"
stress-ng --cpu 0 --vm 2 --vm-bytes 70% --timeout "${DURACION}s" --metrics-brief >/dev/null 2>&1 &
STRESS_PID=$!

sleep 1
echo -e "${CYAN}[+] Comenzando monitorización...${NC}"
FIN=$(( $(date +%s) + DURACION ))

while [ "$(date +%s)" -lt "$FIN" ]; do
    obtener_metricas >> "$LOG_FILE"
    sleep "$INTERVALO"
done

wait "$STRESS_PID" 2>/dev/null

echo
echo -e "${GREEN}[+] Prueba terminada. Procesando datos...${NC}"

# ------------------ ESTADÍSTICAS Y ARRAYS JS -------------
labels_js=""
cpu_temp_js=""
cpu_usage_js=""
mem_used_js=""
gpu_temp_js=""

max_cpu_temp=-1
sum_cpu_temp=0
count_cpu_temp=0
has_cpu_temp_data=false

max_cpu_usage=-1
sum_cpu_usage=0
count_cpu_usage=0
has_cpu_usage_data=false

max_mem_used=-1
mem_total_const=""
has_mem_data=false

first=1

while IFS=, read -r ts ttemp tfreq tusage mused mtotal gtemp gusage gmu gmt; do
    if [ "$ts" = "timestamp" ]; then
        continue
    fi

    if [ $first -eq 0 ]; then
        labels_js+=","
        cpu_temp_js+=","
        cpu_usage_js+=","
        mem_used_js+=","
        gpu_temp_js+=","
    fi
    first=0

    labels_js+="\"$ts\""

    if [ "$ttemp" = "NA" ] || [ -z "$ttemp" ]; then
        cpu_temp_js+="null"
    else
        cpu_temp_js+="$ttemp"
        has_cpu_temp_data=true
        val="${ttemp%%.*}"
        sum_cpu_temp=$((sum_cpu_temp + val))
        count_cpu_temp=$((count_cpu_temp + 1))
        if [ $max_cpu_temp -lt 0 ] || [ "$val" -gt "$max_cpu_temp" ]; then
            max_cpu_temp="$val"
        fi
    fi

    if [ "$tusage" = "NA" ] || [ -z "$tusage" ]; then
        cpu_usage_js+="null"
    else
        cpu_usage_js+="$tusage"
        has_cpu_usage_data=true
        val="${tusage%%.*}"
        sum_cpu_usage=$((sum_cpu_usage + val))
        count_cpu_usage=$((count_cpu_usage + 1))
        if [ $max_cpu_usage -lt 0 ] || [ "$val" -gt "$max_cpu_usage" ]; then
            max_cpu_usage="$val"
        fi
    fi

    if [ "$mused" = "NA" ] || [ -z "$mused" ]; then
        mem_used_js+="null"
    else
        mem_used_js+="$mused"
        has_mem_data=true
        val="$mused"
        if [ $max_mem_used -lt 0 ] || [ "$val" -gt "$max_mem_used" ]; then
            max_mem_used="$val"
        fi
    fi

    if [ -z "$mem_total_const" ] && [ "$mtotal" != "NA" ] && [ -n "$mtotal" ]; then
        mem_total_const="$mtotal"
    fi

    if [ "$gtemp" = "NA" ] || [ -z "$gtemp" ]; then
        gpu_temp_js+="null"
    else
        gpu_temp_js+="$gtemp"
    fi

done < "$LOG_FILE"

if [ $count_cpu_temp -gt 0 ]; then
    avg_cpu_temp=$((sum_cpu_temp / count_cpu_temp))
else
    max_cpu_temp="NA"
    avg_cpu_temp="NA"
fi

if [ $count_cpu_usage -gt 0 ]; then
    avg_cpu_usage=$((sum_cpu_usage / count_cpu_usage))
else
    max_cpu_usage="NA"
    avg_cpu_usage="NA"
fi

if [ $max_mem_used -lt 0 ]; then
    max_mem_used="NA"
fi

if [ -z "$mem_total_const" ]; then
    mem_total_const="NA"
fi

if [ "$max_cpu_temp" = "NA" ]; then
    texto_temp_max="No disponible (sin sensores CPU accesibles, por ejemplo en máquina virtual)"
    texto_temp_media="$texto_temp_max"
else
    texto_temp_max="${max_cpu_temp} °C"
    texto_temp_media="${avg_cpu_temp} °C"
fi

if [ "$max_mem_used" = "NA" ] || [ "$mem_total_const" = "NA" ]; then
    texto_mem="No disponible"
else
    texto_mem="${max_mem_used} MB de ${mem_total_const} MB"
fi

# ---- Interpretaciones ------------------------------------
if [ "$max_cpu_temp" = "NA" ]; then
    eval_temp="No se puede evaluar el comportamiento térmico porque no hay lecturas de sensores CPU. Esto suele ocurrir cuando la prueba se ejecuta dentro de una máquina virtual o cuando el sistema no expone los sensores al sistema operativo invitado. Para un análisis detallado de temperaturas sería recomendable repetir el test en un sistema Linux instalado directamente sobre el hardware físico."
else
    if [ "$max_cpu_temp" -lt 70 ]; then
        eval_temp="La temperatura máxima de la CPU, en torno a ${max_cpu_temp} °C, se sitúa en un rango conservador para un stress test sostenido. Esto indica que el disipador, la ventilación del chasis y la curva de ventiladores están trabajando de forma eficiente. En condiciones reales de uso (navegación, ofimática, juegos ligeros) las temperaturas deberían ser sensiblemente inferiores."
    elif [ "$max_cpu_temp" -lt 85 ]; then
        eval_temp="La temperatura máxima de la CPU, en torno a ${max_cpu_temp} °C, es elevada pero aceptable para una carga sintética que mantiene todos los núcleos al 100 %. Este comportamiento sugiere que la refrigeración es funcional, aunque con poco margen térmico. Conviene comprobar que el equipo está limpio de polvo, que el flujo de aire dentro de la caja es correcto y que la pasta térmica no está excesivamente degradada."
    else
        eval_temp="La temperatura máxima de la CPU, en torno a ${max_cpu_temp} °C, se considera muy alta incluso para un stress test. Con este nivel térmico existe riesgo de thermal throttling y de degradación prematura de componentes si se mantiene en el tiempo. Se recomienda revisar el sistema de refrigeración (disipador, ventiladores, flujo de aire), renovar la pasta térmica y, si es posible, ajustar la curva de ventiladores o aplicar una ligera reducción de voltaje en BIOS para contener las temperaturas."
    fi
fi

if [ "$avg_cpu_usage" = "NA" ]; then
    eval_cpu="No hay datos suficientes de uso de CPU para realizar una valoración. Esto suele indicar que mpstat no ha podido recoger muestras durante la prueba."
else
    if [ "$avg_cpu_usage" -lt 50 ]; then
        eval_cpu="El uso medio de CPU durante la prueba, aproximadamente ${avg_cpu_usage} %, refleja que el sistema ha mantenido un margen de capacidad de cómputo incluso bajo stress-ng. Es un perfil de carga más cercano a escenarios mixtos (aplicaciones de usuario + procesos en segundo plano) que a una saturación total. En la práctica, el equipo no debería sufrir cuellos de botella de CPU en tareas habituales."
    elif [ "$avg_cpu_usage" -lt 85 ]; then
        eval_cpu="El uso medio de CPU durante la prueba, alrededor de ${avg_cpu_usage} %, indica una carga alta y sostenida, con varios núcleos trabajando cerca de su límite. Este tipo de comportamiento es propio de workloads pesados (compilación, virtualización, renderizado). La CPU responde de forma estable, pero bajo escenarios reales exigentes el margen adicional de rendimiento será limitado."
    else
        eval_cpu="El uso medio de CPU durante la prueba, en torno a ${avg_cpu_usage} %, está muy próximo a la saturación total de los núcleos disponibles. Esto significa que bajo este escenario la CPU trabaja prácticamente al límite continuo, lo que facilita detectar problemas de estabilidad, throttling o falta de refrigeración. En usos intensivos (por ejemplo, virtualización pesada o cargas de análisis) podría ser conveniente valorar una CPU con más núcleos o elevar la frecuencia de reloj si la refrigeración lo permite."
    fi
fi

if [ "$max_mem_used" = "NA" ] || [ "$mem_total_const" = "NA" ]; then
    eval_mem="No hay información completa de memoria para valorar el uso de RAM, probablemente porque el comando free no ha devuelto valores estándar en el momento de la captura."
    mem_ratio="NA"
else
    mem_ratio="NA"
    if [[ "$max_mem_used" =~ ^[0-9]+$ ]] && [[ "$mem_total_const" =~ ^[0-9]+$ ]] && [ "$mem_total_const" -ne 0 ]; then
        mem_ratio=$((max_mem_used * 100 / mem_total_const))
        if [ "$mem_ratio" -lt 60 ]; then
            eval_mem="El uso máximo de memoria se sitúa en torno al ${mem_ratio} % de la RAM disponible, lo que deja un margen amplio antes de llegar a situaciones de swapping. Para tareas de ciberseguridad, navegación intensiva y varias máquinas virtuales ligeras, este nivel de consumo es cómodo y no debería suponer un cuello de botella."
        elif [ "$mem_ratio" -lt 85 ]; then
            eval_mem="El uso máximo de memoria ronda el ${mem_ratio} % de la RAM total. Es un nivel elevado pero aceptable para escenarios de stress. En un uso real con navegadores, IDEs y alguna máquina virtual conviene controlar cuántas aplicaciones se mantienen abiertas simultáneamente para evitar que el sistema empiece a usar memoria de intercambio de forma agresiva."
        else
            eval_mem="El uso máximo de memoria se aproxima al ${mem_ratio} % de la RAM total, lo que indica que el sistema opera muy cerca de su límite de capacidad. Bajo cargas reales exigentes (varias máquinas virtuales, herramientas de análisis pesado, navegadores con muchas pestañas) es probable que aparezcan ralentizaciones por swapping. En ese contexto sería recomendable ampliar RAM o reducir el número de procesos concurrentes."
        fi
    else
        eval_mem="No se ha podido calcular correctamente el porcentaje de uso de memoria porque los datos recogidos no son numéricos o no son coherentes."
    fi
fi

if [ "$avg_cpu_usage" = "NA" ] && [ "$mem_ratio" = "NA" ]; then
    eval_global="No se puede elaborar una valoración global con detalle porque faltan datos clave de CPU y memoria. Aun así, el hecho de que el stress test se haya completado sin errores visibles sugiere que el sistema mantiene un nivel básico de estabilidad bajo carga sintética."
else
    eval_global="El sistema ha completado el stress test de forma correcta, sin indicios inmediatos de inestabilidad grave. A partir de los datos de uso de CPU y memoria, el equipo parece capaz de soportar cargas intensas típicas de entornos técnicos (laboratorios de ciberseguridad, análisis, compilación) siempre que se mantenga un control razonable sobre la temperatura y el número de procesos simultáneos. Para una validación definitiva sería aconsejable repetir la prueba directamente sobre hardware físico y monitorizar también tensiones, VRM y comportamiento de la GPU bajo carga real (juegos, benchmarks gráficos o tareas GPGPU)."
fi

if [ "$has_cpu_temp_data" = true ]; then
    has_cpu_temp_data_js="true"
else
    has_cpu_temp_data_js="false"
fi

if [ "$has_mem_data" = true ]; then
    has_mem_data_js="true"
else
    has_mem_data_js="false"
fi

# ------------------ FUNCIÓN PARA ABRIR ARCHIVOS ----------
abrir_archivo() {
    local f="$1"
    if command -v xdg-open >/dev/null 2>&1; then
        xdg-open "$f" >/dev/null 2>&1 &
    elif command -v sensible-browser >/dev/null 2>&1; then
        sensible-browser "$f" >/dev/null 2>&1 &
    elif command -v firefox >/dev/null 2>&1; then
        firefox "$f" >/dev/null 2>&1 &
    else
        echo "No he encontrado un navegador gráfico. Abre el archivo manualmente: $f"
    fi
}

# ------------------ HTML CON CHART.JS ---------------------
echo -e "${GREEN}[+] Generando informe HTML...${NC}"

cat > "$HTML_FILE" <<EOF
<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="UTF-8">
  <title>Informe OCCT Linux - Menarguez-IA-Solutions</title>
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <style>
    body {
      margin: 0;
      font-family: system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
      background: #0b1020;
      color: #f5f5f5;
    }
    header {
      background: linear-gradient(135deg, #00e1ff, #7b2cff);
      padding: 20px 30px;
      box-shadow: 0 4px 20px rgba(0,0,0,0.4);
    }
    header h1 {
      margin: 0;
      font-size: 24px;
    }
    header p {
      margin: 5px 0 0;
      font-size: 14px;
      opacity: 0.9;
    }
    .container {
      max-width: 1200px;
      margin: 20px auto 40px;
      padding: 0 20px;
    }
    .card {
      background: rgba(15, 20, 40, 0.9);
      border-radius: 16px;
      padding: 20px;
      margin-bottom: 20px;
      box-shadow: 0 6px 24px rgba(0,0,0,0.5);
      border: 1px solid rgba(0, 225, 255, 0.12);
    }
    .card h2 {
      margin-top: 0;
      font-size: 18px;
      color: #00e1ff;
    }
    table {
      width: 100%;
      border-collapse: collapse;
      margin-top: 10px;
      font-size: 14px;
    }
    th, td {
      padding: 8px 10px;
      border-bottom: 1px solid rgba(255,255,255,0.08);
      text-align: left;
    }
    th {
      background: rgba(255,255,255,0.04);
      font-weight: 600;
    }
    .footer {
      text-align: center;
      font-size: 12px;
      opacity: 0.7;
      margin-top: 20px;
    }
    canvas {
      max-width: 100%;
      height: 160px;
    }
    .msg {
      margin-top: 8px;
      font-size: 13px;
      color: #ffcc88;
    }
    ul {
      margin-top: 8px;
      padding-left: 20px;
      font-size: 14px;
    }
  </style>
  <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
</head>
<body>
  <header>
    <h1>Informe de Stress Test - Menarguez-IA-Solutions</h1>
    <p>Generado por Nacho Menárguez · Fecha: ${FECHA_HUMANA}</p>
  </header>

  <div class="container">

    <div class="card">
      <h2>Información del sistema</h2>
      <table>
        <tr><th>Parámetro</th><th>Valor</th></tr>
        <tr><td>Hostname</td><td>${SI_HOSTNAME}</td></tr>
        <tr><td>Sistema operativo</td><td>${SI_OS}</td></tr>
        <tr><td>Kernel</td><td>${SI_KERNEL}</td></tr>
        <tr><td>CPU</td><td>${SI_CPU_MODEL}</td></tr>
        <tr><td>Núcleos físicos (aprox.)</td><td>${SI_CPU_CORES}</td></tr>
        <tr><td>Hilos lógicos</td><td>${SI_CPU_THREADS}</td></tr>
        <tr><td>RAM asignada a esta máquina</td><td>${SI_RAM_TOTAL_MB} MB</td></tr>
        <tr><td>GPU principal</td><td>${SI_GPU}</td></tr>
      </table>
      <br>
      <h2>Discos detectados</h2>
      <table>
        <tr><th>Dispositivo</th><th>Tamaño</th><th>Modelo</th></tr>
        ${SI_DISKS_ROWS}
      </table>
    </div>

    <div class="card">
      <h2>Resumen ejecutivo</h2>
      <table>
        <tr><th>Parámetro</th><th>Valor</th></tr>
        <tr><td>Duración prueba</td><td>${DURACION} segundos (intervalo ${INTERVALO}s)</td></tr>
        <tr><td>Temperatura CPU máxima</td><td>${texto_temp_max}</td></tr>
        <tr><td>Temperatura CPU media</td><td>${texto_temp_media}</td></tr>
        <tr><td>Uso CPU máximo</td><td>${max_cpu_usage} %</td></tr>
        <tr><td>Uso CPU medio</td><td>${avg_cpu_usage} %</td></tr>
        <tr><td>Memoria máxima utilizada</td><td>${texto_mem}</td></tr>
        <tr><td>Ruta log CSV</td><td>${LOG_FILE}</td></tr>
      </table>
    </div>

    <div class="card">
      <h2>Interpretación de resultados</h2>
      <ul>
        <li><strong>Temperatura CPU:</strong> ${eval_temp}</li>
        <li><strong>Carga de CPU:</strong> ${eval_cpu}</li>
        <li><strong>Uso de memoria:</strong> ${eval_mem}</li>
        <li><strong>Valoración global:</strong> ${eval_global}</li>
      </ul>
    </div>

    <div class="card">
      <h2>Temperatura CPU (°C)</h2>
      <canvas id="cpuTempChart"></canvas>
      <p id="cpuTempMsg" class="msg"></p>
    </div>

    <div class="card">
      <h2>Memoria utilizada (MB)</h2>
      <canvas id="memChart"></canvas>
    </div>

    <div class="card">
      <h2>Temperatura GPU (°C) - si hay datos</h2>
      <canvas id="gpuTempChart"></canvas>
    </div>

    <div class="footer">
      Nota: si este informe se genera dentro de una máquina virtual, todos los valores de CPU, RAM y discos
      corresponden a los recursos asignados a dicha VM y no necesariamente al equipo físico completo.
      <br>Informe generado automáticamente por occt_linux.sh · Menarguez-IA-Solutions
    </div>
  </div>

  <script>
    const labels = [${labels_js}];
    const cpuTempData = [${cpu_temp_js}];
    const memUsedData = [${mem_used_js}];
    const gpuTempData = [${gpu_temp_js}];

    const hasCpuTempData = ${has_cpu_temp_data_js};
    const hasMemData = ${has_mem_data_js};

    const commonOptions = {
      responsive: true,
      maintainAspectRatio: false,
      scales: {
        x: {
          ticks: { color: "#cccccc", maxRotation: 0, autoSkip: true },
          grid: { color: "rgba(255,255,255,0.05)" }
        },
        y: {
          ticks: { color: "#cccccc" },
          grid: { color: "rgba(255,255,255,0.05)" }
        }
      },
      plugins: {
        legend: {
          labels: { color: "#ffffff" }
        }
      }
    };

    function createLineChart(canvasId, label, data, color) {
      const ctx = document.getElementById(canvasId).getContext("2d");
      return new Chart(ctx, {
        type: "line",
        data: {
          labels: labels,
          datasets: [{
            label: label,
            data: data,
            borderColor: color,
            backgroundColor: "rgba(0,0,0,0)",
            borderWidth: 2,
            pointRadius: 0
          }]
        },
        options: commonOptions
      });
    }

    if (hasCpuTempData) {
      createLineChart("cpuTempChart", "CPU Temp (°C)", cpuTempData, "#00e1ff");
    } else {
      document.getElementById("cpuTempChart").style.display = "none";
      document.getElementById("cpuTempMsg").textContent =
        "No hay datos de temperatura CPU (probablemente ejecutando en máquina virtual sin acceso a sensores físicos).";
    }

    if (hasMemData) {
      createLineChart("memChart", "Mem used (MB)", memUsedData, "#00ff9d");
    }

    createLineChart("gpuTempChart", "GPU Temp (°C)", gpuTempData, "#ffcc00");
  </script>
</body>
</html>
EOF

echo
echo -e "${GREEN}[+] Log CSV guardado en :${NC} $LOG_FILE"
echo -e "${GREEN}[+] Informe HTML creado  :${NC} $HTML_FILE"
echo

# ------------------ MENÚ POST-INFORME ---------------------
while true; do
  echo -e "${CYAN}==============================================${NC}"
  echo -e "${BOLD}Acciones sobre informes${NC}"
  echo -e "${GREEN}1)${NC} Abrir informe HTML actual"
  echo -e "${GREEN}2)${NC} Listar todos los informes HTML"
  echo -e "${GREEN}3)${NC} Abrir otro informe por ruta"
  echo -e "${GREEN}4)${NC} Salir"
  echo -e "${CYAN}==============================================${NC}"
  read -rp "Elige una opción [1-4]: " post

  case "$post" in
    1)
      echo "Abriendo: $HTML_FILE"
      abrir_archivo "$HTML_FILE"
      ;;
    2)
      echo
      echo "Informes HTML en $LOG_DIR:"
      ls -1 "$LOG_DIR"/*.html 2>/dev/null || echo "No hay informes todavía."
      echo
      ;;
    3)
      read -rp "Introduce la ruta del informe a abrir: " otro
      if [ -n "$otro" ]; then
        abrir_archivo "$otro"
      fi
      ;;
    4)
      echo -e "${CYAN}Fin.${NC}"
      break
      ;;
    *)
      echo -e "${RED}Opción no válida.${NC}"
      ;;
  esac
done

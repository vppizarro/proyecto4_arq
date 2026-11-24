
# Proyecto 4 — Pochoco Trader

**Arquitectura de Computadores — Universidad de los Andes**  
**Semestre:** 2026-2  
**Profesor:** Jorge Gómez Mir  
**Integrantes:** Sebastián Germain, Florencia Osandón, Valentina Pizarro

## 1. Descripción del proyecto

Pochoco Trader es un sistema de trading automático implementado
sobre el procesador RISC-V Espino Core y la FPGA Lattice iCE40
HX1K de la Go Board.

El sistema recibe precios de una acción mediante SPI y utiliza
un algoritmo de predicción para decidir si debe comprar,
vender o mantener acciones.

El objetivo principal del proyecto es realizar co-diseño
hardware/software, evaluando modificaciones a la arquitectura
del procesador que permitan mejorar el rendimiento sin exceder
los recursos de la FPGA.

## 2. Funcionamiento general

La FPGA maestra transmite un precio normalizado entre 1 y 255
en cada tick.

El procesador Espino:

1. Espera la recepción de un nuevo precio.
2. Lee el precio recibido por SPI.
3. Actualiza su estado financiero y el historial.
4. Calcula la señal de trading.
5. Determina si debe comprar, vender o mantener.
6. Escribe la decisión en el periférico SPI.

La decisión calculada a partir del precio actual se transmite
durante la siguiente transacción SPI.

### Protocolo SPI

- Modo: SPI 0 (CPOL = 0, CPHA = 0).
- Tamaño de transferencia: 8 bits.
- Orden: MSB primero.
- Frecuencia SCLK: máximo 1 MHz.
- Niveles lógicos: 3,3 V.

Formato del byte de decisión:

| Bits | Significado |
|---|---|
| [7:6] = 00 | HOLD |
| [7:6] = 01 | BUY |
| [7:6] = 10 | SELL |
| [5:0] | Cantidad de acciones |

La FPGA maestra controla la contabilidad oficial.

## 3. Algoritmo de trading

Se implementó una estrategia Momentum basada en la
comparación del precio actual con un precio histórico.

Parámetros:

- Ventana histórica: K = 100 precios.
- Umbral: U = 8.
- Compra: 10 acciones como máximo.
- Venta: totalidad de las acciones disponibles,
  respetando el límite del byte de decisión.

La señal se obtiene mediante:

delta = precio_actual - precio_hace_100_ticks

Reglas:

- Si no hay acciones y delta > 8: BUY.
- Si hay acciones y delta < -8: SELL.
- En los demás casos: HOLD.

Se utiliza un buffer circular de 100 precios para almacenar
el historial necesario.

La implementación Assembly está en `sw/trade.s`.

El programa utiliza instrucciones RV32E y evita las
operaciones de multiplicación, división y desplazamiento
no disponibles en la ALU original.

Las operaciones financieras que requieren productos se
implementan mediante sumas o restas repetidas.

## 4. Herramientas utilizadas

- Yosys: síntesis RTL.
- Icarus Verilog: simulación.
- nextpnr-ice40: ubicación y ruteo.
- IceStorm: generación de bitstream y programación.
- Binutils RISC-V: ensamblado del programa.
- Python 3: algoritmo de referencia y análisis.
- Nix: entorno de desarrollo.

### Entorno Nix

Desde la raíz del repositorio:

    nix-shell -I nixpkgs=channel:nixos-unstable \
      -p yosys iverilog nextpnr icestorm \
      pkgsCross.riscv32-embedded.buildPackages.binutils



### Versiones de las herramientas

| Herramienta | Versión |
|---|---|
| Yosys | 0.71+post |
| Icarus Verilog | 13.0 (stable) |
| nextpnr-ice40 | 0.11.1 |
| IceStorm | 0-unstable-2025-06-03 |
| GNU Binutils RISC-V | 2.46 |
| Python | 3.11.7 |

Las herramientas de hardware se ejecutaron
en macOS mediante un entorno Nix.

IceStorm corresponde a una versión de desarrollo
identificada por la fecha 2025-06-03.



## 5. Ensamblado del programa

Desde la raíz del repositorio:

    make -B -C sw PREFIX=riscv32-none-elf- trade.hex

El archivo generado es:

    sw/trade.hex

Este archivo es cargado en la memoria del SoC durante
la simulación y se incorpora a la configuración FPGA
durante la síntesis.

## 6. Alternativas de hardware

Se evaluaron tres implementaciones del procesador.

### Versión original

Utiliza el banco de registros síncrono basado en BRAM
y el mecanismo de espera original de Espino.

### Alternativa 1: banco de registros combinacional

Se reemplazó el banco de registros BRAM por una
implementación con flip-flops y lectura combinacional.

Esta alternativa redujo considerablemente los ciclos
de ejecución, pero superó los recursos disponibles
en la FPGA HX1K.

Por este motivo fue descartada como implementación final.

Archivos modificados:

    variantes/alternativa1/espino_core/
        espino_register_file.v
        espino_id_stage.v

### Alternativa 2: optimización mediante bypass

Se conservaron las BRAM originales y se modificó
la etapa de decodificación.

Primero se implementó una reducción selectiva de esperas
para instrucciones sin lectura de registros.

Posteriormente se incorporó un bypass que permite
reutilizar el último resultado escrito cuando una
instrucción OP-IMM necesita ese mismo registro.

Esta alternativa reduce los ciclos promedio y
mantiene la compatibilidad con la FPGA HX1K.

Archivo final:

    variantes/final/espino_core/espino_id_stage.v

La versión final también se conserva en:

    variantes/alternativa2/espino_core/espino_id_stage.v

## 7. Comparación de hardware

Resultados de la serie Meta 2022:

| Métrica | Base | Alternativa 1 | Alternativa 2 |
|---|---:|---:|---:|
| Ciclos promedio | 51.055 | 30.677 | 49.804 |
| CPI | 2.424 | 1.441 | 2.359 |
| Celdas lógicas | 1082 | 2401 | 1171 |
| BRAM | 12 | 8 | 12 |
| Fmax (MHz) | 43.34 | N/D | 42.03 |
| Speedup | 1.000x | 1.664x | 1.025x |
| Cabe en HX1K | Sí | No | Sí |

La Alternativa 2 fue seleccionada como implementación
final debido al mejor equilibrio entre rendimiento
y recursos de hardware.

A 25 MHz, la reducción de ciclos promedio fue de
aproximadamente 2,45 % respecto del procesador original.

## 8. Simulación funcional

Las simulaciones se ejecutan desde la raíz del repositorio.

### Compilar el procesador original

    iverilog -g2012 -s tb_proyecto_4 \
      -o /tmp/tb_base \
      "$(yosys-config --datdir)/ice40/cells_sim.v" \
      rtl/*.v rtl/espino_core/*.v \
      tb/tb_performance.sv

### Compilar la Alternativa 2 final

    iverilog -g2012 -s tb_proyecto_4 \
      -o /tmp/tb_final \
      "$(yosys-config --datdir)/ice40/cells_sim.v" \
      rtl/*.v \
      rtl/espino_core/espino_alu.v \
      rtl/espino_core/espino_core.v \
      rtl/espino_core/espino_controller.v \
      rtl/espino_core/espino_decoder.v \
      rtl/espino_core/espino_if_stage.v \
      rtl/espino_core/espino_load_store_unit.v \
      rtl/espino_core/espino_register_file.v \
      variantes/final/espino_core/espino_id_stage.v \
      tb/tb_performance.sv

### Ejecutar la simulación

    vvp -n /tmp/tb_final

El testbench genera el archivo:

    decisiones.csv

Este contiene, para cada tick:

- Precio.
- Byte de decisión.
- Caja.
- Cantidad de acciones.
- Patrimonio.

El testbench también reporta instrucciones,
ciclos, CPI, tiempos de respuesta y tráfico
lógico de memoria.

Nota: las simulaciones utilizan `decisiones.csv`
como archivo de salida, por lo que no deben
ejecutarse simultáneamente desde la misma carpeta.

## 9. Validación de las ocho series

Se utilizaron ocho series de 20.000 ticks.

| Serie | Patrimonio final | Órdenes | Drawdown |
|---|---:|---:|---:|
| AMD enero 2022 | 10275 | 61 | 870 |
| AMD mayo 2022 | 10050 | 44 | 970 |
| Apple 2022 | 10060 | 48 | 950 |
| Apple 2023 | 10020 | 58 | 905 |
| Meta 2022 | 10810 | 42 | 450 |
| Netflix 2022 | 9690 | 52 | 1160 |
| Netflix 2023 | 9255 | 59 | 1650 |
| Tesla 2022 | 10215 | 51 | 940 |

Resultados de validación:

- Series simuladas: 8/8.
- Ticks procesados: 160.000.
- Testbenches funcionales: 32/32 PASS.
- Diferencias entre la versión original y la final: 0.
- Peor tiempo de respuesta observado: 185 ciclos.

La equivalencia fue comprobada comparando los archivos
CSV de ambas implementaciones fila por fila.

Estos resultados corresponden a simulación, no a la
competencia física con la FPGA maestra.

## 10. Síntesis de la implementación final

La síntesis final utiliza el RTL original excepto
por `espino_id_stage.v`, que se reemplaza por
la implementación con bypass.

Desde la raíz del repositorio:

    mkdir -p resultados/sintesis/alternativa2_bypass

    yosys -p "
    read_verilog rtl/*.v \
    rtl/espino_core/espino_alu.v \
    rtl/espino_core/espino_core.v \
    rtl/espino_core/espino_controller.v \
    rtl/espino_core/espino_decoder.v \
    rtl/espino_core/espino_if_stage.v \
    rtl/espino_core/espino_load_store_unit.v \
    rtl/espino_core/espino_register_file.v \
    variantes/final/espino_core/espino_id_stage.v

    synth_ice40 -top pochoco_soc \
    -json resultados/sintesis/alternativa2_bypass/pochoco_soc.json
    stat
    "

### Place-and-route

    nextpnr-ice40 --hx1k --package vq100 \
      --json resultados/sintesis/alternativa2_bypass/pochoco_soc.json \
      --pcf goboard.pcf \
      --asc resultados/sintesis/alternativa2_bypass/pochoco_soc.asc \
      --freq 25

### Generación del bitstream

    icepack \
      resultados/sintesis/alternativa2_bypass/pochoco_soc.asc \
      resultados/sintesis/alternativa2_bypass/pochoco_soc.bin

El diseño final utilizó 1171 celdas lógicas
y 12 bloques BRAM.

nextpnr reportó una frecuencia máxima de 42,03 MHz
y cumplimiento del objetivo de 25 MHz.

## 11. Programación de la Go Board

Conectar la Go Board al computador mediante USB.

Comprobar la comunicación con la memoria flash:

    iceprog -t

Programar la implementación final:

    iceprog \
      resultados/sintesis/alternativa2_bypass/pochoco_soc.bin

La programación realizada finalizó correctamente
con el mensaje:

    VERIFY OK

Esto confirma la escritura y verificación del
bitstream en la memoria flash.

No constituye por sí solo una validación de
la comunicación SPI externa.

## 12. Conexión con la FPGA maestra

La conexión física utiliza las siguientes señales:

- SCLK: reloj SPI enviado por la maestra.
- MOSI: precio enviado por la maestra.
- MISO: decisión generada por nuestra Go Board.
- CS_n: selección de la transacción SPI.
- GND: tierra compartida.

Los pines concretos están definidos en `goboard.pcf`.

Ambas placas deben utilizar niveles de 3,3 V
y compartir tierra.

La prueba con la FPGA maestra real está pendiente.

En dicha prueba se debe verificar:

1. Recepción correcta de los precios.
2. Entrega del byte de decisión por MISO.
3. Correspondencia entre decisión y tick.
4. Cumplimiento del plazo de cada ronda.
5. Patrimonio final calculado por la maestra.

## 13. Limitaciones y trabajo pendiente

La implementación fue validada mediante
simulaciones funcionales, comparación de
160.000 ticks y síntesis física para HX1K.

También se programó correctamente la Go Board.

Queda pendiente validar experimentalmente
la comunicación con la FPGA maestra y registrar
los resultados reales de las tres rondas.

Los análisis de Amdahl, rendimiento e intensidad
operacional se documentan en el informe técnico.

El roofline utiliza un modelo teórico simplificado
con supuestos explícitos sobre el rendimiento
y el ancho de banda de memoria.

## 14. Referencias

- Repositorio base Pochoco SoC:
  https://github.com/nic0villegasc/pochoco_soc

- Documentación de Go Board:
  https://nandland.com/the-go-board/

- Arquitectura RISC-V:
  https://docs.riscv.org/

- Documentación de Yosys:
  https://yosyshq.readthedocs.io/

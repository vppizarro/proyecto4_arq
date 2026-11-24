
# Proyecto 4 - Pochoco Trader
# Etapa 1: buffer circular de 100 precios
# Arquitectura RV32E - sin shifts

.section .text
.global _start

_start:
    # Registros SPI
    lui  x1, 0x80010       # STATUS: 0x80010000
    addi x2, x1, 4         # PRICE
    addi x3, x1, 8         # DECISION

    # Buffer circular
    addi x4, x0, 1648      # Inicio: 0x670
    addi x5, x0, 2044      # Ultima posicion: 0x7FC
    addi x6, x4, 0         # Puntero actual

    # Contador de precios, saturado en 100
    addi x7, x0, 0
    addi x8, x0, 100

    # Decision inicial: HOLD
    sw   x0, 0(x3)

loop:
    # Esperar nuevo precio
    lw   x9, 0(x1)
    andi x9, x9, 1
    beq  x9, x0, loop

    # Leer precio actual
    lw   x10, 0(x2)

    # Guardarlo en el buffer
    sw   x10, 0(x6)

    # Avanzar puntero
    addi x6, x6, 4

    # Si pasa del final, volver al inicio
    blt  x5, x6, reiniciar

continuar:
    # Contar hasta llenar 100 posiciones
    bge  x7, x8, listo
    addi x7, x7, 1

listo:
    # Mantener por ahora
    sw   x0, 0(x3)
    jal  x0, loop

reiniciar:
    addi x6, x4, 0
    jal  x0, continuar


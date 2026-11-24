
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

    # Inicializar estado financiero
    addi x13, x0, 1632     # 0x660: caja
    lui  x14, 0x2
    addi x14, x14, 1808    # x14 = 10000
    sw   x14, 0(x13)       # caja = 10000

    sw   x0, 4(x13)        # acciones = 0
    sw   x0, 8(x13)        # decision pendiente = HOLD

    # Decision inicial: HOLD
    sw   x0, 0(x3)


loop:
    # Esperar nuevo precio
    lw   x9, 0(x1)
    andi x9, x9, 1
    beq  x9, x0, loop

    # Leer precio actual
    lw   x10, 0(x2)

    
    # Recuperar precio antiguo antes de sobrescribirlo
    # El buffer solo es valido despues de 100 precios
    blt  x7, x8, guardar_precio

    
    # Calcular Momentum
    lw   x11, 0(x6)       # Precio hace 100 ticks
    sub  x12, x10, x11    # Delta de Momentum

    # Guardar resultado para verificacion
    addi x13, x0, 1644    # Direccion 0x66C
    sw   x12, 0(x13)      # RAM mem[411]

    jal  x0, guardar_precio


guardar_precio:
    # Actualizar buffer con el precio actual
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


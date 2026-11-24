
# Proyecto 4 - Pochoco Trader
# Momentum K=100, U=8
# RV32E sin shifts, multiplicacion ni division

.section .text
.global _start

_start:
    # Registros SPI
    lui  x1, 0x80010
    addi x2, x1, 4       # PRICE
    addi x3, x1, 8       # DECISION

    # Buffer circular de 100 precios
    addi x4, x0, 1648    # Inicio 0x670
    addi x5, x0, 2044    # Ultima posicion
    addi x6, x4, 0      # Puntero

    addi x7, x0, 0      # Contador
    addi x8, x0, 100    # K = 100

    # Estado financiero en RAM
    addi x13, x0, 1632  # Base 0x660

    lui  x14, 0x2
    addi x14, x14, 1808 # Caja inicial = 10000

    sw x14, 0(x13)      # Caja
    sw x0, 4(x13)       # Acciones
    sw x0, 8(x13)       # Decision pendiente

    sw x0, 0(x3)        # HOLD inicial

loop:
    # Esperar nuevo precio
    lw   x9, 0(x1)
    andi x9, x9, 1
    beq  x9, x0, loop

    # Leer precio actual
    lw x10, 0(x2)

    # Ejecutar decision del tick anterior
    lw x15, 8(x13)
    beq x15, x0, calcular

    addi x14, x0, 74   # 0x4A = comprar 10
    beq x15, x14, comprar

    # En otro caso: vender
    jal x0, vender


comprar:
    # Caja disponible menos comision
    lw   x14, 0(x13)
    addi x14, x14, -5

    addi x15, x0, 0    # Acciones compradas
    addi x11, x0, 10   # Maximo 10

comprar_loop:
    bge x15, x11, comprar_fin
    blt x14, x10, comprar_fin

    sub  x14, x14, x10
    addi x15, x15, 1

    jal x0, comprar_loop

comprar_fin:
    beq x15, x0, calcular

    sw x14, 0(x13)

    lw  x11, 4(x13)
    add x11, x11, x15
    sw  x11, 4(x13)

    jal x0, calcular


vender:
    # Extraer cantidad de acciones
    andi x15, x15, 63

    lw x14, 4(x13)

    # No vender mas de lo disponible
    bge x14, x15, cantidad_lista
    addi x15, x14, 0

cantidad_lista:
    beq x15, x0, calcular

    # Actualizar acciones
    sub x14, x14, x15
    sw  x14, 4(x13)

    # Calcular ingreso mediante sumas
    lw x14, 0(x13)

vender_loop:
    add  x14, x14, x10
    addi x15, x15, -1
    bne  x15, x0, vender_loop

    addi x14, x14, -5
    sw x14, 0(x13)

    jal x0, calcular


calcular:
    # Decision por defecto: HOLD
    addi x15, x0, 0

    # Esperar a tener 100 precios
    blt x7, x8, guardar_precio

    # Calcular Momentum
    lw  x11, 0(x6)
    sub x12, x10, x11

    # Revisar si tenemos acciones
    lw x11, 4(x13)
    beq x11, x0, evaluar_compra

    # Vender si delta < -8
    addi x14, x0, -8
    bge x12, x14, guardar_precio

    # Codificar venta de todas las acciones
    addi x15, x11, 128
    jal x0, guardar_precio


evaluar_compra:
    # Comprar si delta > 8
    addi x14, x0, 8
    bge x14, x12, guardar_precio

    addi x15, x0, 74   # Comprar 10


guardar_precio:
    # Actualizar buffer circular
    sw x10, 0(x6)
    addi x6, x6, 4

    blt x5, x6, reiniciar

continuar:
    # Contar hasta 100
    bge x7, x8, escribir_decision
    addi x7, x7, 1

escribir_decision:
    # Guardar decision pendiente
    sw x15, 8(x13)

    # Enviar decision por SPI
    sw x15, 0(x3)

    jal x0, loop


reiniciar:
    addi x6, x4, 0
    jal x0, continuar

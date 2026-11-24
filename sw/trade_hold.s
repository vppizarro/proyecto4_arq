
# Proyecto 4 - Pochoco Trader
# Primera version: mantener (HOLD)
# Arquitectura: RV32E

.section .text
.global _start

_start:
    # Direcciones SPI
    lui  x2, 0x80010       # Base SPI: 0x80010000
    addi x3, x2, 4         # PRICE: 0x80010004
    addi x4, x2, 8         # DECISION: 0x80010008

loop:
    # Leer STATUS
    lw   x5, 0(x2)

    # Revisar bit 0: new_price
    andi x5, x5, 1

    # Esperar mientras no exista precio nuevo
    beq  x5, x0, loop

    # Leer el precio recibido
    lw   x6, 0(x3)

    # Decision: HOLD, cantidad 0
    sw   x0, 0(x4)

    # Esperar el siguiente precio
    jal  x0, loop

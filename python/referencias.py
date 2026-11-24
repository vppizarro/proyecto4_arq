
import csv

CAJA_INICIAL = 10000
COMISION = 5

precios = []

with open("tb/practica.csv", "r") as f:
    lector = csv.DictReader(f)
    for fila in lector:
        precios.append(int(fila["price"]))

# Referencia 1: no operar
no_operar = CAJA_INICIAL

# Referencia 2: comprar y mantener
# La primera decisión posible se ejecuta en el tick 1.
precio_compra = precios[1]

acciones = (CAJA_INICIAL - COMISION) // precio_compra
caja = CAJA_INICIAL - acciones * precio_compra - COMISION

comprar_mantener = caja + acciones * precios[-1]

print("REFERENCIAS - SERIE COMPLETA")
print("----------------------------")
print("Ticks:", len(precios))
print("Precio de compra:", precio_compra)
print("Precio final:", precios[-1])
print("Acciones compradas:", acciones)
print("No operar:", no_operar)
print("Comprar y mantener:", comprar_mantener)
print()
print("Mejor Momentum:", 10810)
print("Diferencia vs comprar y mantener:",
      10810 - comprar_mantener)


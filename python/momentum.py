
import csv

# Parámetros del mercado
CAJA_INICIAL = 10000
COMISION = 5
K = 50
UMBRAL = 5
CANTIDAD = 10

# Leer precios
precios = []

with open("tb/practica.csv", "r") as f:
    lector = csv.DictReader(f)
    for fila in lector:
        precios.append(int(fila["price"]))

# Estado inicial
caja = CAJA_INICIAL
acciones = 0
senales_compra = 0
senales_venta = 0
ordenes = 0
peak = CAJA_INICIAL
max_dd = 0

# La decisión inicial es mantener
decision = 0

for n, precio in enumerate(precios):

    # 1. Ejecutar la decisión calculada previamente
    accion = decision >> 6
    q = decision & 0x3F

    if accion == 1:
        disponibles = max(0, (caja - COMISION) // precio)
        q = min(q, disponibles)

        if q > 0:
            caja -= q * precio + COMISION
            acciones += q
            ordenes += 1

    elif accion == 2:
        q = min(q, acciones)

        if q > 0 and caja + q * precio >= COMISION:
            caja += q * precio - COMISION
            acciones -= q
            ordenes += 1

    # 2. Calcular patrimonio y pérdida máxima
    patrimonio = caja + acciones * precio

    peak = max(peak, patrimonio)
    max_dd = max(max_dd, peak - patrimonio)




    # 3. Decidir según la tendencia y posición actual
    decision = 0

    if n >= K:
        diferencia = precio - precios[n - K]

        if diferencia > UMBRAL and acciones == 0:
            decision = (1 << 6) | CANTIDAD
            senales_compra += 1

        elif diferencia < -UMBRAL and acciones > 0:
            decision = (2 << 6) | min(acciones, 63)
            senales_venta += 1




# Resultados
print("RESULTADOS MOMENTUM")
print("-------------------")
print("Patrimonio final:", caja + acciones * precios[-1])
print("Caja final:", caja)
print("Acciones finales:", acciones)
print("Órdenes ejecutadas:", ordenes)
print("Comisiones pagadas:", ordenes * COMISION)
print("Pérdida máxima:", max_dd)
print("Señales de compra:", senales_compra)
print("Señales de venta:", senales_venta)



import csv

# Parámetros del mercado
CAJA_INICIAL = 10000
COMISION = 5
CANTIDAD = 10

# Parámetros que evaluaremos
ventanas = [10, 20, 50, 100, 200]
umbrales = [2, 3, 5, 8, 10]

# Leer precios
precios = []

with open("tb/practica.csv", "r") as f:
    lector = csv.DictReader(f)
    for fila in lector:
        precios.append(int(fila["price"]))


def simular(k, umbral):
    caja = CAJA_INICIAL
    acciones = 0
    ordenes = 0
    peak = CAJA_INICIAL
    max_dd = 0
    decision = 0

    for n, precio in enumerate(precios):

        # 1. Ejecutar la decisión del tick anterior
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

        # 2. Actualizar patrimonio y pérdida máxima
        patrimonio = caja + acciones * precio
        peak = max(peak, patrimonio)
        max_dd = max(max_dd, peak - patrimonio)

        # 3. Calcular siguiente decisión
        decision = 0

        if n >= k:
            diferencia = precio - precios[n - k]

            if diferencia > umbral and acciones == 0:
                decision = (1 << 6) | CANTIDAD

            elif diferencia < -umbral and acciones > 0:
                decision = (2 << 6) | min(acciones, 63)

    return {
        "k": k,
        "umbral": umbral,
        "patrimonio": caja + acciones * precios[-1],
        "ordenes": ordenes,
        "comisiones": ordenes * COMISION,
        "max_dd": max_dd,
    }


# Evaluar todas las configuraciones
resultados = []

for k in ventanas:
    for umbral in umbrales:
        resultados.append(simular(k, umbral))

# Ordenar por patrimonio final
resultados.sort(
    key=lambda x: x["patrimonio"],
    reverse=True
)

print("RESULTADOS MOMENTUM")
print("-" * 70)

print(
    f"{'K':>5} {'Umbral':>8} "
    f"{'Patrimonio':>12} {'Órdenes':>10} "
    f"{'Comisiones':>12} {'Max DD':>10}"
)

for r in resultados:
    print(
        f"{r['k']:>5} "
        f"{r['umbral']:>8} "
        f"{r['patrimonio']:>12} "
        f"{r['ordenes']:>10} "
        f"{r['comisiones']:>12} "
        f"{r['max_dd']:>10}"
    )

# Guardar resultados para el informe
with open("python/resultados_momentum.csv", "w", newline="") as f:
    campos = [
        "k", "umbral", "patrimonio",
        "ordenes", "comisiones", "max_dd"
    ]

    escritor = csv.DictWriter(f, fieldnames=campos)
    escritor.writeheader()
    escritor.writerows(resultados)

print()
print("Resultados guardados en python/resultados_momentum.csv")

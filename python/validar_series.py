
import csv
from pathlib import Path

# Parámetros de la estrategia
CAJA_INICIAL = 10000
COMISION = 5
K = 100
UMBRAL = 8
CANTIDAD = 10


def leer_precios(archivo):
    precios = []

    with open(archivo, "r") as f:
        lector = csv.DictReader(f)

        for fila in lector:
            precios.append(int(fila["price"]))

    return precios


def simular(precios):
    caja = CAJA_INICIAL
    acciones = 0
    ordenes = 0
    peak = CAJA_INICIAL
    max_dd = 0
    decision = 0

    for n, precio in enumerate(precios):

        # Ejecutar decisión anterior al precio actual
        accion = decision >> 6
        q = decision & 0x3F

        if accion == 1:
            disponibles = max(
                0, (caja - COMISION) // precio
            )
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

        # Actualizar patrimonio y drawdown
        patrimonio = caja + acciones * precio
        peak = max(peak, patrimonio)
        max_dd = max(max_dd, peak - patrimonio)

        # Calcular siguiente decisión
        decision = 0

        if n >= K:
            diferencia = precio - precios[n - K]

            if diferencia > UMBRAL and acciones == 0:
                decision = (1 << 6) | CANTIDAD

            elif diferencia < -UMBRAL and acciones > 0:
                decision = (2 << 6) | min(acciones, 63)

    return {
        "patrimonio": caja + acciones * precios[-1],
        "ordenes": ordenes,
        "comisiones": ordenes * COMISION,
        "max_dd": max_dd,
    }


def comprar_mantener(precios):
    precio_compra = precios[1]

    q = min(
        63,
        max(0, (CAJA_INICIAL - COMISION) // precio_compra)
    )

    caja = CAJA_INICIAL - q * precio_compra
    if q > 0:
        caja -= COMISION

    return caja + q * precios[-1]


# Buscar todas las series
archivos = sorted(
    Path("tb/series").glob("*.csv")
)

resultados = []

for archivo in archivos:
    precios = leer_precios(archivo)

    resultado = simular(precios)
    referencia = comprar_mantener(precios)

    resultados.append({
        "serie": archivo.stem,
        "momentum": resultado["patrimonio"],
        "no_operar": CAJA_INICIAL,
        "comprar_mantener": referencia,
        "ordenes": resultado["ordenes"],
        "comisiones": resultado["comisiones"],
        "max_dd": resultado["max_dd"],
    })


print("VALIDACIÓN MULTISERIE - MOMENTUM")
print("-" * 100)

print(
    f"{'Serie':<29}"
    f"{'Momentum':>11}"
    f"{'No operar':>12}"
    f"{'Buy & Hold':>12}"
    f"{'Órdenes':>10}"
    f"{'Max DD':>10}"
)

for r in resultados:
    print(
        f"{r['serie']:<29}"
        f"{r['momentum']:>11}"
        f"{r['no_operar']:>12}"
        f"{r['comprar_mantener']:>12}"
        f"{r['ordenes']:>10}"
        f"{r['max_dd']:>10}"
    )

# Guardar para el informe
with open(
    "python/resultados_multiserie.csv",
    "w",
    newline=""
) as f:

    campos = [
        "serie", "momentum", "no_operar",
        "comprar_mantener", "ordenes",
        "comisiones", "max_dd"
    ]

    escritor = csv.DictWriter(
        f, fieldnames=campos
    )
    escritor.writeheader()
    escritor.writerows(resultados)

print()
print("Resultados guardados en python/resultados_multiserie.csv")

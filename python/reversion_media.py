
import csv
from pathlib import Path

CAJA_INICIAL = 10000
COMISION = 5

K = 64
UMBRAL = 5
CANTIDAD = 10


def leer_precios(archivo):
    with open(archivo, "r") as f:
        lector = csv.DictReader(f)
        return [int(fila["price"]) for fila in lector]


def simular(precios):
    caja = CAJA_INICIAL
    acciones = 0
    ordenes = 0
    peak = CAJA_INICIAL
    max_dd = 0

    decision = 0
    suma = 0

    for n, precio in enumerate(precios):

        # 1. Ejecutar la decisión del tick anterior
        accion = decision >> 6
        q = decision & 63

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

        # 2. Medir patrimonio
        patrimonio = caja + acciones * precio
        peak = max(peak, patrimonio)
        max_dd = max(max_dd, peak - patrimonio)

        # 3. Actualizar suma móvil
        suma += precio

        if n >= K:
            suma -= precios[n - K]

        # 4. Calcular siguiente decisión
        decision = 0

        if n >= K - 1:

            # Evitamos dividir usando comparación entera
            diferencia = K * precio - suma

            # Precio bajo la media: comprar
            if diferencia < -K * UMBRAL and acciones == 0:
                decision = (1 << 6) | CANTIDAD

            # Precio sobre la media: vender
            elif diferencia > K * UMBRAL and acciones > 0:
                decision = (2 << 6) | min(acciones, 63)

    return {
        "patrimonio": caja + acciones * precios[-1],
        "ordenes": ordenes,
        "comisiones": ordenes * COMISION,
        "max_dd": max_dd,
    }


# Evaluar las ocho series
archivos = sorted(Path("tb/series").glob("*.csv"))

print("RESULTADOS - REVERSION A LA MEDIA")
print("-" * 76)

print(
    f"{'Serie':<29}"
    f"{'Patrimonio':>12}"
    f"{'Ordenes':>10}"
    f"{'Comisiones':>12}"
    f"{'Max DD':>10}"
)

resultados = []

for archivo in archivos:
    precios = leer_precios(archivo)
    r = simular(precios)

    resultados.append({
        "serie": archivo.stem,
        **r
    })

    print(
        f"{archivo.stem:<29}"
        f"{r['patrimonio']:>12}"
        f"{r['ordenes']:>10}"
        f"{r['comisiones']:>12}"
        f"{r['max_dd']:>10}"
    )

if resultados:
    promedio = sum(
        r["patrimonio"] for r in resultados
    ) / len(resultados)

    ganancias = sum(
        r["patrimonio"] > CAJA_INICIAL
        for r in resultados
    )

    print("-" * 76)
    print("Patrimonio promedio:", round(promedio, 2))
    print("Series con ganancias:", ganancias, "/", len(resultados))

with open(
    "python/resultados_reversion.csv",
    "w",
    newline=""
) as f:
    campos = [
        "serie", "patrimonio",
        "ordenes", "comisiones", "max_dd"
    ]
    escritor = csv.DictWriter(f, fieldnames=campos)
    escritor.writeheader()
    escritor.writerows(resultados)


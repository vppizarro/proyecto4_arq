
from pathlib import Path

from validar_series import leer_precios

# Parámetros a evaluar
VENTANAS = [10, 20, 50, 100, 200]
UMBRALES = [2, 3, 5, 8, 10]

CAJA_INICIAL = 10000
COMISION = 5
CANTIDAD = 10


def simular(precios, k, umbral):
    caja = CAJA_INICIAL
    acciones = 0
    ordenes = 0
    decision = 0
    peak = CAJA_INICIAL
    max_dd = 0

    for n, precio in enumerate(precios):

        accion = decision >> 6
        q = decision & 63

        # Ejecutar decisión anterior
        if accion == 1:
            q = min(
                q,
                max(0, (caja - COMISION) // precio)
            )

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

        patrimonio = caja + acciones * precio
        peak = max(peak, patrimonio)
        max_dd = max(max_dd, peak - patrimonio)

        decision = 0

        if n >= k:
            diferencia = precio - precios[n - k]

            if diferencia > umbral and acciones == 0:
                decision = (1 << 6) | CANTIDAD

            elif diferencia < -umbral and acciones > 0:
                decision = (2 << 6) | min(acciones, 63)

    return caja + acciones * precios[-1], max_dd


# Cargar series una sola vez
series = {
    archivo.stem: leer_precios(archivo)
    for archivo in sorted(Path("tb/series").glob("*.csv"))
}

resultados = []

for k in VENTANAS:
    for umbral in UMBRALES:

        patrimonios = []
        drawdowns = []

        for precios in series.values():
            patrimonio, dd = simular(
                precios, k, umbral
            )

            patrimonios.append(patrimonio)
            drawdowns.append(dd)

        resultados.append({
            "k": k,
            "umbral": umbral,
            "promedio": sum(patrimonios) / len(patrimonios),
            "minimo": min(patrimonios),
            "ganancias": sum(
                p > CAJA_INICIAL for p in patrimonios
            ),
            "peor_dd": max(drawdowns),
        })

resultados.sort(
    key=lambda x: (
        x["promedio"],
        x["minimo"]
    ),
    reverse=True
)

print("OPTIMIZACIÓN MOMENTUM - OCHO SERIES")
print("-" * 68)

print(
    f"{'K':>5} {'Umbral':>8} "
    f"{'Promedio':>12} {'Mínimo':>10} "
    f"{'Ganancias':>10} {'Peor DD':>10}"
)

for r in resultados:
    print(
        f"{r['k']:>5} "
        f"{r['umbral']:>8} "
        f"{r['promedio']:>12.2f} "
        f"{r['minimo']:>10} "
        f"{r['ganancias']:>10} "
        f"{r['peor_dd']:>10}"
    )


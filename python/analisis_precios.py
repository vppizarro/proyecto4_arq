
import csv

# Archivo con los precios de práctica
archivo = "tb/practica.csv"

precios = []

with open(archivo, "r") as f:
    lector = csv.DictReader(f)

    for fila in lector:
        precios.append(int(fila["price"]))

# Estadísticas descriptivas
print("ANÁLISIS DE PRECIOS - META")
print("-------------------------")
print("Cantidad de precios:", len(precios))
print("Precio inicial:", precios[0])
print("Precio final:", precios[-1])
print("Precio mínimo:", min(precios))
print("Precio máximo:", max(precios))
print("Precio promedio:", round(sum(precios) / len(precios), 2))


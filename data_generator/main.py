import os
import random
import psycopg2
from datetime import datetime, timedelta
from faker import Faker
from dotenv import load_dotenv

# Cargar configuración
load_dotenv()
fake = Faker()

DB_CONFIG = {
    "host": os.getenv("DB_HOST", "localhost"),
    "port": os.getenv("DB_PORT", "5432"),
    "user": os.getenv("DB_USER", "postgres"),
    "password": os.getenv("DB_PASSWORD", "admin")
}

# --- CATÁLOGOS MAESTROS (En memoria para consistencia entre bases de datos) ---
PRODUCTOS = [
    {"sku": f"SKU-{i:03}", "nombre": n, "cat": c, "frio": f}
    for i, (n, c, f) in enumerate([
        ("Ibuprofeno 500mg", "Generico", False),
        ("Amoxicilina 1g", "Generico", False),
        ("Jarabe Antigripal EMB", "Marca Propia", False),
        ("Vitamina C Kids EMB", "Marca Propia", False),
        ("Insulina Glargina", "Marca Externa", True),
        ("Loratadina 10mg", "Generico", False),
        ("Paracetamol 500mg", "Generico", False),
        ("Gel Antibacterial EMB", "Marca Propia", False),
        ("Suero Rehidratante", "Marca Externa", False),
        ("Antibiótico Premium", "Marca Externa", True)
    ] * 5)  # Generamos 50 productos
]

PROVEEDORES = ["PharmaCorp India", "Berlin Labs",
               "China Health", "EuroMed", "USA Pharma"]
LABORATORIOS = [
    (1, "Lab Oriente", "Zacapa"),
    (2, "Lab Centro", "Guatemala"),
    (3, "Lab Occidente", "Quetzaltenango")
]


def get_connection(dbname):
    return psycopg2.connect(**DB_CONFIG, dbname=dbname)


def insert_logistics():
    print("Inyectando datos en logistics_db...")
    conn = get_connection("logistics_db")
    cur = conn.cursor()

    # 1. Catálogo de Productos
    for p in PRODUCTOS:
        cur.execute("""
            INSERT INTO catalogo_productos (sku, nombre_comercial, categoria, requiere_cadena_frio, costo_almacenamiento_diario)
            VALUES (%s, %s, %s, %s, %s) ON CONFLICT (sku) DO NOTHING""",
                    (p['sku'], p['nombre'], p['cat'], p['frio'], random.uniform(0.01, 0.05)))

    # 2. Inventario Bodega Central
    cur.execute("SELECT id_producto FROM catalogo_productos")
    ids = [r[0] for r in cur.fetchall()]
    for id_p in ids:
        cantidad = random.randint(500, 5000) if random.random(
        ) > 0.8 else random.randint(50, 500)
        fecha = datetime.now() - timedelta(days=random.randint(0, 200))
        cur.execute("""
            INSERT INTO inventario_bodega_central (id_producto, cantidad_actual, punto_reorden, fecha_ultimo_ingreso, ubicacion_pasillo, nivel_estante)
            VALUES (%s, %s, %s, %s, %s, %s)""",
                    (id_p, cantidad, 100, fecha, random.choice(['A', 'B', 'C', 'D']), random.randint(1, 5)))

    # 3. Pedidos de Sucursal
    for _ in range(50):
        fecha_solicitud = fake.date_time_between(
            start_date='-6m', end_date='now')
        cur.execute("""
            INSERT INTO pedidos_sucursal (id_sucursal, fecha_solicitud, prioridad, estado_envio)
            VALUES (%s, %s, %s, %s) RETURNING id_pedido_suc""",
                    (random.randint(1, 3), fecha_solicitud, random.choice(['Urgente', 'Normal']), random.choice(['Pendiente', 'En Ruta', 'Entregado'])))
        id_pedido = cur.fetchone()[0]

        # Detalle del pedido
        for _ in range(random.randint(1, 5)):
            cur.execute("""
                INSERT INTO detalle_pedido_sucursal (id_pedido_suc, id_producto, cantidad_solicitada)
                VALUES (%s, %s, %s)""",
                        (id_pedido, random.choice(ids), random.randint(50, 200)))

    conn.commit()
    cur.close()
    conn.close()


def insert_purchasing():
    print("Inyectando datos en purchasing_db...")
    conn = get_connection("purchasing_db")
    cur = conn.cursor()

    # 1. Proveedores
    for p in PROVEEDORES:
        cur.execute("INSERT INTO proveedores (nombre_empresa, pais_origen, tiempo_entrega_promedio_dias) VALUES (%s, %s, %s) RETURNING id_proveedor",
                    (p, random.choice(["India", "Alemania", "China", "EEUU"]), random.randint(15, 45)))

    cur.execute("SELECT id_proveedor FROM proveedores")
    prov_ids = [r[0] for r in cur.fetchall()]

    # 2. Órdenes de Compra y Detalles
    for _ in range(30):
        fecha_pedido = fake.date_time_between(start_date='-1y', end_date='now')
        cur.execute("""
            INSERT INTO ordenes_compra (id_proveedor, fecha_pedido, estado_pedido, numero_contenedor, costo_flete)
            VALUES (%s, %s, %s, %s, %s) RETURNING id_orden_compra""",
                    (random.choice(prov_ids), fecha_pedido, random.choice(['Cotizado', 'En Transito', 'Puerto', 'Recibido']),
                     fake.bothify(text='CONT-####-??'), random.uniform(1000, 5000)))
        id_orden = cur.fetchone()[0]

        for _ in range(random.randint(2, 6)):
            sku = random.choice(
                [p['sku'] for p in PRODUCTOS if p['cat'] != 'Marca Propia'])
            cur.execute("""
                INSERT INTO detalle_compra (id_orden_compra, sku_producto, nombre_producto, cantidad_pedida, precio_unitario_dolares)
                VALUES (%s, %s, %s, %s, %s)""",
                        (id_orden, sku, "Producto Importado", random.randint(1000, 5000), random.uniform(2.5, 25.0)))

    conn.commit()
    conn.close()


def insert_production():
    print("Inyectando datos en production_db...")
    conn = get_connection("production_db")
    cur = conn.cursor()

    # 1. Labs y Maquinaria
    for l in LABORATORIOS:
        cur.execute("INSERT INTO laboratorios (id_laboratorio, nombre_lab, region_guatemala) VALUES (%s, %s, %s) ON CONFLICT (id_laboratorio) DO NOTHING", l)
        for i in range(2):
            cur.execute("INSERT INTO maquinaria (id_laboratorio, nombre_maquina, capacidad_unidades_por_hora, estado_maquina) VALUES (%s, %s, %s, %s)",
                        (l[0], f"Prensa-{l[0]}-{i}", random.randint(100, 500), random.choice(['Operativa', 'Mantenimiento'])))

    # 2. Órdenes de Producción (Corregido nombre de tabla y columnas faltantes)
    cur.execute("SELECT id_maquina, id_laboratorio FROM maquinaria")
    maquinas = cur.fetchall()
    for m_id, l_id in maquinas:
        # Subutilización en Lab 3 (Occidente)
        num_ordenes = random.randint(
            1, 3) if l_id == 3 else random.randint(15, 30)
        for _ in range(num_ordenes):
            sku = random.choice(
                [p['sku'] for p in PRODUCTOS if p['cat'] == 'Marca Propia'])
            cant = random.randint(500, 2000)
            fecha_inicio = fake.date_time_between(
                start_date='-6m', end_date='now')
            fecha_fin = fecha_inicio + timedelta(hours=random.randint(2, 12))

            cur.execute("""
                INSERT INTO ordenes_produccion (id_maquina, sku_interno, fecha_inicio, fecha_fin, cantidad_producida, materia_prima_kg, consumo_energia_kwh)
                VALUES (%s, %s, %s, %s, %s, %s, %s)""",
                        (m_id, sku, fecha_inicio, fecha_fin, cant, cant * random.uniform(0.1, 0.5), cant * random.uniform(0.05, 0.2)))

    conn.commit()
    conn.close()


def insert_pos(dbname, sucursal_id):
    print(f"Inyectando datos en {dbname}...")
    conn = get_connection(dbname)
    cur = conn.cursor()

    # 1. Stock Local
    for p in PRODUCTOS:
        existencia = random.randint(
            0, 20) if random.random() > 0.7 else random.randint(50, 150)
        cur.execute("""
            INSERT INTO stock_local (id_producto_sku, existencia_actual, minimo_requerido)
            VALUES (%s, %s, %s) ON CONFLICT (id_producto_sku) DO UPDATE SET existencia_actual = EXCLUDED.existencia_actual""",
                    (p['sku'], existencia, 40))

    # 2. Ventas y Detalle (Corregido: Agregado nit_cliente e id_vendedor)
    for _ in range(300):
        fecha = fake.date_time_between(start_date='-1y', end_date='now')
        # Picos de venta estacionales
        iteraciones = 3 if 6 <= fecha.month <= 8 else 1

        for _ in range(iteraciones):
            nit_cliente = fake.bothify(text='########-#')
            id_vendedor = random.randint(1, 10)

            cur.execute("""
                INSERT INTO ventas_encabezado (fecha_venta, nit_cliente, total_venta, id_vendedor) 
                VALUES (%s, %s, %s, %s) RETURNING id_venta""",
                        (fecha, nit_cliente, 0, id_vendedor))
            v_id = cur.fetchone()[0]

            total_venta = 0
            for _ in range(random.randint(1, 4)):
                sku = random.choice([p['sku'] for p in PRODUCTOS])
                cant = random.randint(1, 5)
                precio = random.uniform(10.0, 150.0)

                cur.execute("""
                    INSERT INTO ventas_detalle (id_venta, id_producto_sku, cantidad, precio_unitario) 
                    VALUES (%s, %s, %s, %s)""",
                            (v_id, sku, cant, precio))
                total_venta += (cant * precio)

            cur.execute(
                "UPDATE ventas_encabezado SET total_venta = %s WHERE id_venta = %s", (total_venta, v_id))

    conn.commit()
    conn.close()


if __name__ == "__main__":
    try:
        insert_logistics()
        insert_purchasing()
        insert_production()
        insert_pos("pos_sucursal_1", 1)
        insert_pos("pos_sucursal_2", 2)
        insert_pos("pos_sucursal_3", 3)
        print("¡Proceso completado exitosamente en todas las bases de datos!")
    except Exception as e:
        print(f"Ocurrió un error: {e}")

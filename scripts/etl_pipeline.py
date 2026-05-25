import os
import pandas as pd
from sqlalchemy import create_engine, text
from dotenv import load_dotenv
from datetime import datetime

load_dotenv()

USER = os.getenv("DB_USER")
PASSWORD = os.getenv("DB_PASSWORD")
HOST = os.getenv("DB_HOST")
PORT = os.getenv("DB_PORT")


def get_engine(db_name):
    return create_engine(f"postgresql://{USER}:{PASSWORD}@{HOST}:{PORT}/{db_name}")


# Crear un diccionario con todas las conexiones
engines = {
    'logistics': get_engine('logistics_db'),
    'production': get_engine('production_db'),
    'pos1': get_engine('pos_sucursal_1'),
    'pos2': get_engine('pos_sucursal_2'),
    'pos3': get_engine('pos_sucursal_3'),
    'dwh': get_engine('dwh')
}


def get_existing_keys(table, natural_key):
    """Obtiene las llaves naturales existentes en el DWH para evitar duplicados."""
    query = f"SELECT {natural_key} FROM {table}"
    try:
        return pd.read_sql(query, engines['dwh'])[natural_key].tolist()
    except:
        return []


def clean_fact_tables():
    """Limpia los hechos antes de recargar (Estrategia Full Load para hechos)"""
    print("Limpiando tablas de hechos...")
    with engines['dwh'].begin() as conn:
        conn.execute(text(
            "TRUNCATE TABLE fact_ventas, fact_produccion, fact_inventario RESTART IDENTITY CASCADE;"))

# CARGA DE DIMENSIONES (Upsert / Insert New)


def load_dim_tiempo():
    print("Cargando dim_tiempo...")
    existentes = get_existing_keys('dim_tiempo', 'tiempo_key')

    # Generar fechas
    fechas = pd.date_range(start='2023-01-01', end='2026-12-31')
    df = pd.DataFrame({'fecha': fechas})
    df['tiempo_key'] = df['fecha'].dt.strftime('%Y%m%d').astype(int)
    df['anio'] = df['fecha'].dt.year
    df['mes'] = df['fecha'].dt.month
    df['nombre_mes'] = df['fecha'].dt.month_name()
    df['trimestre'] = df['fecha'].dt.quarter
    df['es_temporada_alta'] = df['mes'].isin([5, 6, 7, 8])

    # Filtrar solo las nuevas
    df_nuevas = df[~df['tiempo_key'].isin(existentes)]
    if not df_nuevas.empty:
        df_nuevas.to_sql(
            'dim_tiempo', engines['dwh'], if_exists='append', index=False)


def load_dim_producto():
    print("Cargando dim_producto...")
    existentes = get_existing_keys('dim_producto', 'sku')

    df = pd.read_sql(
        "SELECT sku, nombre_comercial, categoria, requiere_cadena_frio as requiere_frio FROM catalogo_productos", engines['logistics'])
    df['nombre_comercial'] = df['nombre_comercial'].str.upper()
    df['marca'] = df['categoria'].apply(
        lambda x: 'EMB' if x == 'Marca Propia' else 'Internacional')

    df_nuevas = df[~df['sku'].isin(existentes)]
    if not df_nuevas.empty:
        df_nuevas.to_sql(
            'dim_producto', engines['dwh'], if_exists='append', index=False)


def load_dim_sucursal():
    print("Cargando dim_sucursal...")
    existentes = get_existing_keys('dim_sucursal', 'id_original_sucursal')

    data = [
        {'id_original_sucursal': 1, 'nombre_sucursal': 'Sucursal Central',
            'region': 'Centro', 'departamento': 'Guatemala'},
        {'id_original_sucursal': 2, 'nombre_sucursal': 'Sucursal Xela',
            'region': 'Occidente', 'departamento': 'Quetzaltenango'},
        {'id_original_sucursal': 3, 'nombre_sucursal': 'Sucursal Zacapa',
            'region': 'Oriente', 'departamento': 'Zacapa'}
    ]
    df = pd.DataFrame(data)

    df_nuevas = df[~df['id_original_sucursal'].isin(existentes)]
    if not df_nuevas.empty:
        df_nuevas.to_sql(
            'dim_sucursal', engines['dwh'], if_exists='append', index=False)


def load_dim_laboratorio():
    print("Cargando dim_laboratorio...")
    existentes = get_existing_keys('dim_laboratorio', 'laboratorio_key')

    df = pd.read_sql(
        "SELECT id_laboratorio as laboratorio_key, nombre_lab, region_guatemala FROM laboratorios", engines['production'])
    # Valor por defecto o extraíble de maquinaria
    df['capacidad_instalada_total'] = 1000

    df_nuevas = df[~df['laboratorio_key'].isin(existentes)]
    if not df_nuevas.empty:
        df_nuevas.to_sql('dim_laboratorio',
                         engines['dwh'], if_exists='append', index=False)

# CARGA DE HECHOS


def load_fact_ventas():
    print("Procesando fact_ventas...")
    # Obtener llaves del DWH para hacer el cruce (Lookup)
    dim_prod = pd.read_sql(
        "SELECT producto_key, sku FROM dim_producto", engines['dwh'])
    dim_suc = pd.read_sql(
        "SELECT sucursal_key, id_original_sucursal FROM dim_sucursal", engines['dwh'])

    dfs = []
    for pos_id, engine_key in zip([1, 2, 3], ['pos1', 'pos2', 'pos3']):
        query = """
            SELECT v.fecha_venta, d.id_producto_sku as sku, d.cantidad, d.precio_unitario,
                   s.existencia_actual, s.minimo_requerido
            FROM ventas_encabezado v
            JOIN ventas_detalle d ON v.id_venta = d.id_venta
            LEFT JOIN stock_local s ON d.id_producto_sku = s.id_producto_sku
        """
        df = pd.read_sql(query, engines[engine_key])
        df['id_original_sucursal'] = pos_id
        dfs.append(df)

    df_ventas = pd.concat(dfs, ignore_index=True)

    # Transformaciones
    df_ventas['tiempo_key'] = df_ventas['fecha_venta'].dt.strftime(
        '%Y%m%d').astype(int)
    df_ventas['monto_total'] = df_ventas['cantidad'] * \
        df_ventas['precio_unitario']
    df_ventas['riesgo_desabasto'] = df_ventas['existencia_actual'] < df_ventas['minimo_requerido']
    df_ventas['stock_al_momento'] = df_ventas['existencia_actual']

    # Cruce con dimensiones
    df_ventas = df_ventas.merge(dim_prod, on='sku', how='inner')
    df_ventas = df_ventas.merge(
        dim_suc, on='id_original_sucursal', how='inner')

    # Seleccionar columnas finales
    fact_cols = ['tiempo_key', 'producto_key', 'sucursal_key',
                 'cantidad', 'monto_total', 'stock_al_momento', 'riesgo_desabasto']
    df_final = df_ventas[fact_cols].rename(
        columns={'cantidad': 'cantidad_vendida'})

    df_final.to_sql(
        'fact_ventas', engines['dwh'], if_exists='append', index=False)


def load_fact_produccion():
    print("Procesando fact_produccion...")
    dim_prod = pd.read_sql(
        "SELECT producto_key, sku FROM dim_producto", engines['dwh'])

    query = """
        SELECT o.sku_interno as sku, o.fecha_fin, o.cantidad_producida, o.consumo_energia_kwh,
               m.id_laboratorio as laboratorio_key, m.capacidad_unidades_por_hora,
               EXTRACT(EPOCH FROM (o.fecha_fin - o.fecha_inicio))/3600 AS horas_trabajadas
        FROM ordenes_produccion o
        JOIN maquinaria m ON o.id_maquina = m.id_maquina
    """
    df = pd.read_sql(query, engines['production'])

    if df.empty:
        return

    # Transformaciones
    df['tiempo_key'] = df['fecha_fin'].dt.strftime('%Y%m%d').astype(int)
    df['capacidad_teorica'] = (
        df['capacidad_unidades_por_hora'] * df['horas_trabajadas']).astype(int)

    # Evitar división por cero
    df['capacidad_teorica'] = df['capacidad_teorica'].replace(0, 1)
    df['eficiencia_porcentaje'] = (
        df['cantidad_producida'] / df['capacidad_teorica']) * 100
    df['consumo_energia_por_unidad'] = df['consumo_energia_kwh'] / \
        df['cantidad_producida']

    # Cruce
    df = df.merge(dim_prod, on='sku', how='inner')

    fact_cols = ['tiempo_key', 'producto_key', 'laboratorio_key', 'cantidad_producida',
                 'capacidad_teorica', 'eficiencia_porcentaje', 'consumo_energia_por_unidad']
    df_final = df[fact_cols]

    df_final.to_sql('fact_produccion',
                    engines['dwh'], if_exists='append', index=False)


def load_fact_inventario():
    print("Procesando fact_inventario...")
    dim_prod = pd.read_sql(
        "SELECT producto_key, sku FROM dim_producto", engines['dwh'])

    query = """
        SELECT i.cantidad_actual as bodega_central_stock, i.fecha_ultimo_ingreso, 
               c.sku, c.costo_almacenamiento_diario
        FROM inventario_bodega_central i
        JOIN catalogo_productos c ON i.id_producto = c.id_producto
    """
    df = pd.read_sql(query, engines['logistics'])

    if df.empty:
        return

    hoy = pd.Timestamp.now().normalize()
    df['fecha_ultimo_ingreso'] = pd.to_datetime(
        df['fecha_ultimo_ingreso']).fillna(hoy)

    # Cálculos clave
    df['tiempo_key'] = df['fecha_ultimo_ingreso'].dt.strftime(
        '%Y%m%d').astype(int)
    df['dias_sin_movimiento'] = (hoy - df['fecha_ultimo_ingreso']).dt.days
    # Asegurar que los días no sean negativos si hay un error en data
    df['dias_sin_movimiento'] = df['dias_sin_movimiento'].clip(lower=0)

    df['costo_almacenamiento_acumulado'] = df['bodega_central_stock'] * \
        df['costo_almacenamiento_diario'] * df['dias_sin_movimiento']
    df['ocupacion_volumen_mt3'] = df['bodega_central_stock'] * \
        0.05  # 0.05 mt3 por unidad promedio

    df = df.merge(dim_prod, on='sku', how='inner')

    fact_cols = ['tiempo_key', 'producto_key', 'bodega_central_stock',
                 'costo_almacenamiento_acumulado', 'dias_sin_movimiento', 'ocupacion_volumen_mt3']
    df_final = df[fact_cols]

    df_final.to_sql('fact_inventario',
                    engines['dwh'], if_exists='append', index=False)


# EJECUCIÓN PRINCIPAL
if __name__ == "__main__":
    try:
        print("--- INICIANDO PROCESO ETL ---")
        load_dim_tiempo()
        load_dim_producto()
        load_dim_sucursal()
        load_dim_laboratorio()

        clean_fact_tables()

        load_fact_ventas()
        load_fact_produccion()
        load_fact_inventario()
        print("--- PROCESO ETL FINALIZADO CON ÉXITO ---")
    except Exception as e:
        print(f"Error durante la ejecución del ETL: {e}")

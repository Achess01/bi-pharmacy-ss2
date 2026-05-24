\connect dwh
CREATE SCHEMA staging;

-- Tabla temporal para unificar las 3 sucursales
CREATE TABLE staging.stg_ventas (
    fuente_sucursal INT,
    id_venta_original INT,
    sku_producto VARCHAR(50),
    fecha_venta TIMESTAMP,
    cantidad INT,
    precio_unitario NUMERIC(10,2),
    total_venta NUMERIC(12,2)
);

-- Tabla temporal para producción
CREATE TABLE staging.stg_produccion (
    id_lab INT,
    sku VARCHAR(50),
    fecha_inicio TIMESTAMP,
    fecha_fin TIMESTAMP,
    cantidad INT,
    maquina_id INT
);

-- Extracción
INSERT INTO staging.stg_ventas
SELECT 1, v.id_venta, d.id_producto_sku, v.fecha_venta, d.cantidad, d.precio_unitario, v.total_venta
FROM pos_sucursal_1.ventas_encabezado v
JOIN pos_sucursal_1.ventas_detalle d ON v.id_venta = d.id_venta;

INSERT INTO staging.stg_ventas
SELECT 2, v.id_venta, d.id_producto_sku, v.fecha_venta, d.cantidad, d.precio_unitario, v.total_venta
FROM pos_sucursal_2.ventas_encabezado v
JOIN pos_sucursal_2.ventas_detalle d ON v.id_venta = d.id_venta;

INSERT INTO staging.stg_ventas
SELECT 3, v.id_venta, d.id_producto_sku, v.fecha_venta, d.cantidad, d.precio_unitario, v.total_venta
FROM pos_sucursal_3.ventas_encabezado v
JOIN pos_sucursal_3.ventas_detalle d ON v.id_venta = d.id_venta;

-- Transformación
INSERT INTO dim_producto (sku, nombre_comercial, categoria, marca, requiere_frio)
SELECT
    sku,
    UPPER(nombre_comercial), -- Normalización a mayúsculas
    categoria,
    CASE WHEN categoria = 'Marca Propia' THEN 'EMB' ELSE 'Internacional' END,
    requiere_cadena_frio
FROM logistics_db.public.catalogo_productos
ON CONFLICT (sku) DO NOTHING;

-- Carga

-- Sucursales
INSERT INTO dim_sucursal (id_original_sucursal, nombre_sucursal, region)
VALUES
(1, 'Sucursal Central', 'Centro'),
(2, 'Sucursal Xela', 'Occidente'),
(3, 'Sucursal Zacapa', 'Oriente')
ON CONFLICT (id_original_sucursal) DO UPDATE
SET nombre_sucursal = EXCLUDED.nombre_sucursal, region = EXCLUDED.region;

-- Laboratorios
INSERT INTO dim_laboratorio (id_original, nombre_lab, region_guatemala)
SELECT id_laboratorio, nombre_lab, region_guatemala
FROM production_db.public.laboratorios
ON CONFLICT (id_original) DO UPDATE
SET nombre_lab = EXCLUDED.nombre_lab;

-- Tiempo
INSERT INTO dim_tiempo (tiempo_key, fecha, anio, mes, nombre_mes, trimestre, es_temporada_alta)
SELECT
    CAST(TO_CHAR(datum, 'YYYYMMDD') AS INT) AS tiempo_key,
    datum AS fecha,
    EXTRACT(YEAR FROM datum) AS anio,
    EXTRACT(MONTH FROM datum) AS mes,
    TO_CHAR(datum, 'Month') AS nombre_mes,
    EXTRACT(QUARTER FROM datum) AS trimestre,
    CASE WHEN EXTRACT(MONTH FROM datum) IN (5, 6, 7, 8) THEN TRUE ELSE FALSE END -- Temporada de lluvia/gripe en Guate
FROM generate_series('2023-01-01'::DATE, '2026-05-31'::DATE, '1 day'::interval) datum;

-- Fact ventas
INSERT INTO fact_ventas (tiempo_key, producto_key, sucursal_key, cantidad_vendida, monto_total, riesgo_desabasto)
SELECT
    CAST(TO_CHAR(stg.fecha_venta, 'YYYYMMDD') AS INT), -- Transformación de fecha a Key
    p.producto_key,
    s.sucursal_key,
    stg.cantidad,
    (stg.cantidad * stg.precio_unitario),
    CASE WHEN (stg.cantidad > 100) THEN TRUE ELSE FALSE END -- Lógica simple de riesgo
FROM staging.stg_ventas stg
JOIN dim_producto p ON stg.sku_producto = p.sku
JOIN dim_sucursal s ON stg.fuente_sucursal = s.id_original_sucursal;

-- Fact producción
INSERT INTO fact_produccion (tiempo_key, producto_key, laboratorio_key, cantidad_producida, eficiencia_porcentaje)
SELECT
    CAST(TO_CHAR(stg.fecha_fin, 'YYYYMMDD') AS INT),
    p.producto_key,
    l.laboratorio_key,
    stg.cantidad,
    (stg.cantidad::float / 1000) * 100 -- Asumiendo capacidad diaria de 1000 para el ejemplo
FROM staging.stg_produccion stg
JOIN dim_producto p ON stg.sku = p.sku
JOIN dim_laboratorio l ON stg.id_lab = l.id_original;
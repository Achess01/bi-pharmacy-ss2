-- DS Ventas analítica
SELECT
    v.venta_key,
    t.fecha,
    t.anio,
    t.nombre_mes,
    p.sku,
    p.nombre_comercial,
    p.categoria,
    p.marca,
    s.nombre_sucursal,
    s.region,
    v.cantidad_vendida,
    v.monto_total,
    v.stock_al_momento,
    v.riesgo_desabasto
FROM
    fact_ventas v
    JOIN dim_tiempo t ON v.tiempo_key = t.tiempo_key
    JOIN dim_producto p ON v.producto_key = p.producto_key
    JOIN dim_sucursal s ON v.sucursal_key = s.sucursal_key;

-- DS Inventario muerto
SELECT
    i.inventario_key,
    t.fecha,
    p.sku,
    p.nombre_comercial,
    p.categoria,
    i.bodega_central_stock,
    i.costo_almacenamiento_acumulado,
    i.dias_sin_movimiento,
    i.ocupacion_volumen_mt3,
    CASE
        WHEN i.dias_sin_movimiento > 90 THEN 'Stock Muerto'
        ELSE 'Rotación Activa'
    END as estado_stock
FROM
    fact_inventario i
    JOIN dim_tiempo t ON i.tiempo_key = t.tiempo_key
    JOIN dim_producto p ON i.producto_key = p.producto_key;

-- DS Produccion eficiencia
SELECT
    pr.produccion_key,
    t.fecha,
    p.nombre_comercial,
    l.nombre_lab,
    l.region_guatemala,
    pr.cantidad_producida,
    pr.capacidad_teorica,
    pr.eficiencia_porcentaje,
    pr.consumo_energia_por_unidad
FROM
    fact_produccion pr
    JOIN dim_tiempo t ON pr.tiempo_key = t.tiempo_key
    JOIN dim_producto p ON pr.producto_key = p.producto_key
    JOIN dim_laboratorio l ON pr.laboratorio_key = l.laboratorio_key;
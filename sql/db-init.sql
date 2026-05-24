CREATE DATABASE logistics_db;
\connect logistics_db

CREATE TABLE catalogo_productos (
    id_producto SERIAL PRIMARY KEY,
    sku VARCHAR(50) UNIQUE,
    nombre_comercial VARCHAR(150),
    categoria VARCHAR(50), -- 'Generico', 'Marca Propia', 'Marca Externa'
    requiere_cadena_frio BOOLEAN DEFAULT FALSE,
    costo_almacenamiento_diario NUMERIC(10, 4)
);

CREATE TABLE inventario_bodega_central (
    id_inventario SERIAL PRIMARY KEY,
    id_producto INT REFERENCES catalogo_productos(id_producto),
    cantidad_actual INT,
    punto_reorden INT, -- Para evitar desabasto
    fecha_ultimo_ingreso DATE,
    ubicacion_pasillo VARCHAR(10),
    nivel_estante INT
);

CREATE TABLE pedidos_sucursal (
    id_pedido_suc SERIAL PRIMARY KEY,
    id_sucursal INT, -- Referencia al sistema de ventas
    fecha_solicitud TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    prioridad VARCHAR(20), -- 'Urgente', 'Normal'
    estado_envio VARCHAR(20) -- 'Pendiente', 'En Ruta', 'Entregado'
);

CREATE TABLE detalle_pedido_sucursal (
    id_detalle_ped SERIAL PRIMARY KEY,
    id_pedido_suc INT REFERENCES pedidos_sucursal(id_pedido_suc),
    id_producto INT REFERENCES catalogo_productos(id_producto),
    cantidad_solicitada INT
);

CREATE DATABASE purchasing_db;
\connect purchasing_db

CREATE TABLE proveedores (
    id_proveedor SERIAL PRIMARY KEY,
    nombre_empresa VARCHAR(100) NOT NULL,
    pais_origen VARCHAR(50),
    tiempo_entrega_promedio_dias INT
);

CREATE TABLE ordenes_compra (
    id_orden_compra SERIAL PRIMARY KEY,
    id_proveedor INT REFERENCES proveedores(id_proveedor),
    fecha_pedido TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    estado_pedido VARCHAR(20), -- 'Cotizado', 'En Transito', 'Puerto', 'Recibido'
    numero_contenedor VARCHAR(50),
    costo_flete NUMERIC(12, 2)
);

CREATE TABLE detalle_compra (
    id_detalle SERIAL PRIMARY KEY,
    id_orden_compra INT REFERENCES ordenes_compra(id_orden_compra),
    sku_producto VARCHAR(50), -- Código internacional
    nombre_producto VARCHAR(100),
    cantidad_pedida INT,
    precio_unitario_dolares NUMERIC(10, 2)
);

CREATE DATABASE production_db;
\connect production_db

CREATE TABLE laboratorios (
    id_laboratorio SERIAL PRIMARY KEY,
    nombre_lab VARCHAR(50), -- 'Lab Oriente', 'Lab Centro', 'Lab Occidente'
    region_guatemala VARCHAR(50)
);

CREATE TABLE maquinaria (
    id_maquina SERIAL PRIMARY KEY,
    id_laboratorio INT REFERENCES laboratorios(id_laboratorio),
    nombre_maquina VARCHAR(50),
    capacidad_unidades_por_hora INT,
    estado_maquina VARCHAR(20) -- 'Operativa', 'Mantenimiento', 'Inactiva'
);

CREATE TABLE ordenes_produccion (
    id_op SERIAL PRIMARY KEY,
    id_maquina INT REFERENCES maquinaria(id_maquina),
    sku_interno VARCHAR(50),
    fecha_inicio TIMESTAMP,
    fecha_fin TIMESTAMP,
    cantidad_producida INT,
    materia_prima_kg NUMERIC(10, 2),
    consumo_energia_kwh NUMERIC(10, 2)
);

CREATE DATABASE pos_sucursal_1;
\connect pos_sucursal_1

CREATE TABLE ventas_encabezado (
    id_venta SERIAL PRIMARY KEY,
    fecha_venta TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    nit_cliente VARCHAR(15),
    total_venta NUMERIC(12, 2),
    id_vendedor INT
);

CREATE TABLE stock_local (
    id_producto_sku VARCHAR(50) PRIMARY KEY,
    existencia_actual INT,
    minimo_requerido INT -- Si la existencia < minimo, hay riesgo de desabasto
);

CREATE TABLE ventas_detalle (
    id_detalle SERIAL PRIMARY KEY,
    id_venta INT REFERENCES ventas_encabezado(id_venta),
    id_producto_sku VARCHAR(50) REFERENCES stock_local(id_producto_sku),
    cantidad INT,
    precio_unitario NUMERIC(10, 2)
);

CREATE DATABASE pos_sucursal_2;
\connect pos_sucursal_2

CREATE TABLE ventas_encabezado (
    id_venta SERIAL PRIMARY KEY,
    fecha_venta TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    nit_cliente VARCHAR(15),
    total_venta NUMERIC(12, 2),
    id_vendedor INT
);

CREATE TABLE stock_local (
    id_producto_sku VARCHAR(50) PRIMARY KEY,
    existencia_actual INT,
    minimo_requerido INT -- Si la existencia < minimo, hay riesgo de desabasto
);

CREATE TABLE ventas_detalle (
    id_detalle SERIAL PRIMARY KEY,
    id_venta INT REFERENCES ventas_encabezado(id_venta),
    id_producto_sku VARCHAR(50) REFERENCES stock_local(id_producto_sku),
    cantidad INT,
    precio_unitario NUMERIC(10, 2)
);

CREATE DATABASE pos_sucursal_3;
\connect pos_sucursal_3

CREATE TABLE ventas_encabezado (
    id_venta SERIAL PRIMARY KEY,
    fecha_venta TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    nit_cliente VARCHAR(15),
    total_venta NUMERIC(12, 2),
    id_vendedor INT
);

CREATE TABLE stock_local (
    id_producto_sku VARCHAR(50) PRIMARY KEY,
    existencia_actual INT,
    minimo_requerido INT -- Si la existencia < minimo, hay riesgo de desabasto
);

CREATE TABLE ventas_detalle (
    id_detalle SERIAL PRIMARY KEY,
    id_venta INT REFERENCES ventas_encabezado(id_venta),
    id_producto_sku VARCHAR(50) REFERENCES stock_local(id_producto_sku),
    cantidad INT,
    precio_unitario NUMERIC(10, 2)
);



CREATE DATABASE dwh;
\connect dwh

-- Dimensión Tiempo
CREATE TABLE dim_tiempo (
    tiempo_key INT PRIMARY KEY, -- Formato YYYYMMDD
    fecha DATE,
    anio INT,
    mes INT,
    nombre_mes VARCHAR(20),
    trimestre INT,
    es_temporada_alta BOOLEAN
);

-- Dimensión Producto
CREATE TABLE dim_producto (
    producto_key SERIAL PRIMARY KEY,
    sku VARCHAR(50) UNIQUE,
    nombre_comercial VARCHAR(150),
    categoria VARCHAR(50),
    marca VARCHAR(50), -- 'EMB-Propia' o 'Internacional'
    requiere_frio BOOLEAN
);

-- Dimensión Sucursal
CREATE TABLE dim_sucursal (
    sucursal_key SERIAL PRIMARY KEY,
    id_original_sucursal INT, -- El ID que viene de los POS
    nombre_sucursal VARCHAR(100),
    region VARCHAR(50), -- Oriente, Centro, Occidente, Norte, Sur
    departamento VARCHAR(50) -- Para decidir ubicación de nueva bodega
);

-- Dimensión Laboratorio
CREATE TABLE dim_laboratorio (
    laboratorio_key SERIAL PRIMARY KEY,
    nombre_lab VARCHAR(50),
    region_guatemala VARCHAR(50),
    capacidad_instalada_total INT
);

-- Hechos
CREATE TABLE fact_ventas (
    venta_key SERIAL PRIMARY KEY,
    tiempo_key INT REFERENCES dim_tiempo(tiempo_key),
    producto_key INT REFERENCES dim_producto(producto_key),
    sucursal_key INT REFERENCES dim_sucursal(sucursal_key),
    cantidad_vendida INT,
    monto_total NUMERIC(12, 2),
    stock_al_momento INT, -- Para detectar si se vendió poco porque no había
    riesgo_desabasto BOOLEAN -- Calculado: si stock < minimo_requerido
);

CREATE TABLE fact_inventario (
    inventario_key SERIAL PRIMARY KEY,
    tiempo_key INT REFERENCES dim_tiempo(tiempo_key),
    producto_key INT REFERENCES dim_producto(producto_key),
    bodega_central_stock INT,
    costo_almacenamiento_acumulado NUMERIC(12, 4),
    dias_sin_movimiento INT, -- Para detectar productos "muertos"
    ocupacion_volumen_mt3 NUMERIC(10, 2) -- Para ver qué tanto espacio queda
);

CREATE TABLE fact_produccion (
    produccion_key SERIAL PRIMARY KEY,
    tiempo_key INT REFERENCES dim_tiempo(tiempo_key),
    producto_key INT REFERENCES dim_producto(producto_key),
    laboratorio_key INT REFERENCES dim_laboratorio(laboratorio_key),
    cantidad_producida INT,
    capacidad_teorica INT,
    eficiencia_porcentaje NUMERIC(5, 2), -- (Producida / Capacidad) * 100
    consumo_energia_por_unidad NUMERIC(10, 4)
);
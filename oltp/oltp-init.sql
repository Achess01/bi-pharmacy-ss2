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

CREATE TABLE ventas_detalle (
    id_detalle SERIAL PRIMARY KEY,
    id_venta INT REFERENCES ventas_encabezado(id_venta),
    id_producto_sku VARCHAR(50),
    cantidad INT,
    precio_unitario NUMERIC(10, 2)
);

CREATE TABLE stock_local (
    id_producto_sku VARCHAR(50) PRIMARY KEY,
    existencia_actual INT,
    minimo_requerido INT -- Si la existencia < minimo, hay riesgo de desabasto
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

CREATE TABLE ventas_detalle (
    id_detalle SERIAL PRIMARY KEY,
    id_venta INT REFERENCES ventas_encabezado(id_venta),
    id_producto_sku VARCHAR(50),
    cantidad INT,
    precio_unitario NUMERIC(10, 2)
);

CREATE TABLE stock_local (
    id_producto_sku VARCHAR(50) PRIMARY KEY,
    existencia_actual INT,
    minimo_requerido INT
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

CREATE TABLE ventas_detalle (
    id_detalle SERIAL PRIMARY KEY,
    id_venta INT REFERENCES ventas_encabezado(id_venta),
    id_producto_sku VARCHAR(50),
    cantidad INT,
    precio_unitario NUMERIC(10, 2)
);

CREATE TABLE stock_local (
    id_producto_sku VARCHAR(50) PRIMARY KEY,
    existencia_actual INT,
    minimo_requerido INT
);

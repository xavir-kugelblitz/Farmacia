CREATE DATABASE IF NOT EXISTS farmacia_db
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_general_ci;

USE farmacia_db;

CREATE TABLE IF NOT EXISTS roles (
    id_rol TINYINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(30) NOT NULL UNIQUE,
    descripcion VARCHAR(150) NULL
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS usuarios (
    id_usuario BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    id_rol TINYINT UNSIGNED NOT NULL,
    nombre_completo VARCHAR(120) NOT NULL,
    nombre_usuario VARCHAR(50) NOT NULL UNIQUE,
    correo VARCHAR(150) NULL UNIQUE,
    hash_contrasena VARCHAR(255) NOT NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    fecha_creacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_actualizacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT fk_usuarios_rol FOREIGN KEY (id_rol) REFERENCES roles(id_rol),
    INDEX idx_usuarios_rol_activo (id_rol, activo)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS clientes (
    id_cliente BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(120) NOT NULL,
    apellido_paterno VARCHAR(80) NULL,
    apellido_materno VARCHAR(80) NULL,
    fecha_nacimiento DATE NULL,
    rfc VARCHAR(13) NULL,
    correo VARCHAR(150) NULL,
    telefono VARCHAR(25) NULL,
    ciudad VARCHAR(100) NULL,
    estado VARCHAR(100) NULL,
    puntos_acumulados SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    fecha_registro DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_actualizacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT uq_clientes_rfc UNIQUE (rfc),
    CONSTRAINT chk_clientes_puntos CHECK (puntos_acumulados < 50),
    INDEX idx_clientes_ubicacion (estado, ciudad),
    INDEX idx_clientes_nombre (nombre, apellido_paterno)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS datos_fiscales_cliente (
    id_datos_fiscales BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    id_cliente BIGINT UNSIGNED NOT NULL,
    razon_social VARCHAR(150) NOT NULL,
    rfc VARCHAR(13) NOT NULL,
    regimen_fiscal VARCHAR(5) NULL,
    codigo_postal_fiscal VARCHAR(5) NULL,
    uso_cfdi VARCHAR(5) NULL,
    correo_facturacion VARCHAR(150) NULL,
    predeterminado BOOLEAN NOT NULL DEFAULT TRUE,
    fecha_registro DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_datos_fiscales_cliente FOREIGN KEY (id_cliente)
        REFERENCES clientes(id_cliente),
    INDEX idx_datos_fiscales_rfc (rfc),
    INDEX idx_datos_fiscales_cliente (id_cliente, predeterminado)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS clasificaciones (
    id_clasificacion INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(80) NOT NULL UNIQUE,
    descripcion VARCHAR(255) NULL,
    activa BOOLEAN NOT NULL DEFAULT TRUE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS medicamentos (
    id_medicamento BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    id_clasificacion INT UNSIGNED NOT NULL,
    codigo_barras VARCHAR(50) NULL UNIQUE,
    nombre VARCHAR(150) NOT NULL,
    descripcion VARCHAR(500) NULL,
    presentacion VARCHAR(100) NULL,
    unidad_medida VARCHAR(30) NOT NULL DEFAULT 'pieza',
    costo_compra DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    precio_venta DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    descuento_porcentaje DECIMAL(5,2) NOT NULL DEFAULT 0.00,
    existencias INT UNSIGNED NOT NULL DEFAULT 0,
    stock_minimo INT UNSIGNED NOT NULL DEFAULT 0,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    fecha_creacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_actualizacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT fk_medicamentos_clasificacion FOREIGN KEY (id_clasificacion)
        REFERENCES clasificaciones(id_clasificacion),
    CONSTRAINT chk_medicamentos_costo CHECK (costo_compra >= 0),
    CONSTRAINT chk_medicamentos_precio CHECK (precio_venta >= 0),
    CONSTRAINT chk_medicamentos_descuento CHECK (descuento_porcentaje BETWEEN 0 AND 100),
    INDEX idx_medicamentos_nombre (nombre),
    INDEX idx_medicamentos_clasificacion (id_clasificacion),
    INDEX idx_medicamentos_stock (existencias, stock_minimo)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS proveedores (
    id_proveedor BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    nombre_empresa VARCHAR(150) NOT NULL,
    nombre_contacto VARCHAR(120) NULL,
    correo_pedidos VARCHAR(150) NOT NULL,
    telefono VARCHAR(25) NULL,
    direccion VARCHAR(255) NULL,
    ciudad VARCHAR(100) NULL,
    estado VARCHAR(100) NULL,
    notas VARCHAR(500) NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    fecha_registro DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_proveedores_empresa (nombre_empresa),
    INDEX idx_proveedores_activo (activo)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS proveedor_medicamento (
    id_proveedor BIGINT UNSIGNED NOT NULL,
    id_medicamento BIGINT UNSIGNED NOT NULL,
    precio_compra DECIMAL(12,2) NOT NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    PRIMARY KEY (id_proveedor, id_medicamento),
    CONSTRAINT fk_pm_proveedor FOREIGN KEY (id_proveedor) REFERENCES proveedores(id_proveedor),
    CONSTRAINT fk_pm_medicamento FOREIGN KEY (id_medicamento) REFERENCES medicamentos(id_medicamento),
    CONSTRAINT chk_pm_precio CHECK (precio_compra >= 0),
    INDEX idx_pm_medicamento (id_medicamento)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS pedidos (
    id_pedido BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    folio_pedido VARCHAR(30) NOT NULL UNIQUE,
    id_proveedor BIGINT UNSIGNED NOT NULL,
    id_usuario BIGINT UNSIGNED NOT NULL,
    fecha_pedido DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    estado ENUM('PENDIENTE','CONFIRMADO','ENVIADO','PARCIALMENTE_RECIBIDO','RECIBIDO','CANCELADO')
        NOT NULL DEFAULT 'PENDIENTE',
    subtotal DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    descuento DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    total DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    correo_destino VARCHAR(150) NOT NULL,
    fecha_envio DATETIME NULL,
    referencia_correo VARCHAR(255) NULL,
    observaciones VARCHAR(500) NULL,
    CONSTRAINT fk_pedidos_proveedor FOREIGN KEY (id_proveedor) REFERENCES proveedores(id_proveedor),
    CONSTRAINT fk_pedidos_usuario FOREIGN KEY (id_usuario) REFERENCES usuarios(id_usuario),
    CONSTRAINT chk_pedidos_importes CHECK (subtotal >= 0 AND descuento >= 0 AND total >= 0),
    INDEX idx_pedidos_fecha (fecha_pedido),
    INDEX idx_pedidos_estado (estado),
    INDEX idx_pedidos_proveedor (id_proveedor, fecha_pedido)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS detalle_pedidos (
    id_detalle_pedido BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    id_pedido BIGINT UNSIGNED NOT NULL,
    id_medicamento BIGINT UNSIGNED NOT NULL,
    cantidad_solicitada INT UNSIGNED NOT NULL,
    precio_unitario DECIMAL(12,2) NOT NULL,
    descuento_porcentaje DECIMAL(5,2) NOT NULL DEFAULT 0.00,
    importe DECIMAL(12,2) NOT NULL,
    CONSTRAINT fk_dp_pedido FOREIGN KEY (id_pedido) REFERENCES pedidos(id_pedido),
    CONSTRAINT fk_dp_medicamento FOREIGN KEY (id_medicamento) REFERENCES medicamentos(id_medicamento),
    CONSTRAINT chk_dp_cantidad CHECK (cantidad_solicitada > 0),
    CONSTRAINT chk_dp_precio CHECK (precio_unitario >= 0 AND importe >= 0),
    CONSTRAINT chk_dp_descuento CHECK (descuento_porcentaje BETWEEN 0 AND 100),
    UNIQUE KEY uq_pedido_medicamento (id_pedido, id_medicamento),
    INDEX idx_dp_medicamento (id_medicamento)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS compras (
    id_compra BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    folio_compra VARCHAR(30) NOT NULL UNIQUE,
    id_proveedor BIGINT UNSIGNED NOT NULL,
    id_pedido BIGINT UNSIGNED NULL,
    id_usuario BIGINT UNSIGNED NOT NULL,
    fecha_compra DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    referencia_documento VARCHAR(80) NULL,
    subtotal DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    descuento DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    total DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    observaciones VARCHAR(500) NULL,
    CONSTRAINT fk_compras_proveedor FOREIGN KEY (id_proveedor) REFERENCES proveedores(id_proveedor),
    CONSTRAINT fk_compras_pedido FOREIGN KEY (id_pedido) REFERENCES pedidos(id_pedido),
    CONSTRAINT fk_compras_usuario FOREIGN KEY (id_usuario) REFERENCES usuarios(id_usuario),
    CONSTRAINT chk_compras_importes CHECK (subtotal >= 0 AND descuento >= 0 AND total >= 0),
    INDEX idx_compras_fecha (fecha_compra),
    INDEX idx_compras_proveedor (id_proveedor, fecha_compra)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS detalle_compras (
    id_detalle_compra BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    id_compra BIGINT UNSIGNED NOT NULL,
    id_detalle_pedido BIGINT UNSIGNED NULL,
    id_medicamento BIGINT UNSIGNED NOT NULL,
    cantidad_recibida INT UNSIGNED NOT NULL,
    costo_unitario DECIMAL(12,2) NOT NULL,
    descuento_porcentaje DECIMAL(5,2) NOT NULL DEFAULT 0.00,
    importe DECIMAL(12,2) NOT NULL,
    CONSTRAINT fk_dc_compra FOREIGN KEY (id_compra) REFERENCES compras(id_compra),
    CONSTRAINT fk_dc_detalle_pedido FOREIGN KEY (id_detalle_pedido) REFERENCES detalle_pedidos(id_detalle_pedido),
    CONSTRAINT fk_dc_medicamento FOREIGN KEY (id_medicamento) REFERENCES medicamentos(id_medicamento),
    CONSTRAINT chk_dc_cantidad CHECK (cantidad_recibida > 0),
    CONSTRAINT chk_dc_importes CHECK (costo_unitario >= 0 AND importe >= 0),
    CONSTRAINT chk_dc_descuento CHECK (descuento_porcentaje BETWEEN 0 AND 100),
    INDEX idx_dc_compra (id_compra),
    INDEX idx_dc_medicamento (id_medicamento)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ventas (
    id_venta BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    folio_venta VARCHAR(30) NOT NULL UNIQUE,
    id_cliente BIGINT UNSIGNED NULL,
    id_usuario BIGINT UNSIGNED NOT NULL,
    fecha_venta DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    subtotal DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    descuento_productos DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    descuento_puntos DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    total DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    puntos_antes SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    puntos_ganados SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    puntos_redimidos SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    puntos_despues SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    estado ENUM('COMPLETADA','CANCELADA') NOT NULL DEFAULT 'COMPLETADA',
    observaciones VARCHAR(500) NULL,
    CONSTRAINT fk_ventas_cliente FOREIGN KEY (id_cliente) REFERENCES clientes(id_cliente),
    CONSTRAINT fk_ventas_usuario FOREIGN KEY (id_usuario) REFERENCES usuarios(id_usuario),
    CONSTRAINT chk_ventas_importes CHECK (
        subtotal >= 0 AND descuento_productos >= 0 AND descuento_puntos >= 0 AND total >= 0
    ),
    CONSTRAINT chk_ventas_puntos CHECK (
        puntos_antes < 50 AND puntos_despues < 50
    ),
    INDEX idx_ventas_fecha (fecha_venta),
    INDEX idx_ventas_cliente (id_cliente, fecha_venta),
    INDEX idx_ventas_estado (estado)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS detalle_ventas (
    id_detalle_venta BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    id_venta BIGINT UNSIGNED NOT NULL,
    id_medicamento BIGINT UNSIGNED NOT NULL,
    cantidad INT UNSIGNED NOT NULL,
    precio_unitario DECIMAL(12,2) NOT NULL,
    descuento_porcentaje DECIMAL(5,2) NOT NULL DEFAULT 0.00,
    importe DECIMAL(12,2) NOT NULL,
    CONSTRAINT fk_dv_venta FOREIGN KEY (id_venta) REFERENCES ventas(id_venta),
    CONSTRAINT fk_dv_medicamento FOREIGN KEY (id_medicamento) REFERENCES medicamentos(id_medicamento),
    CONSTRAINT chk_dv_cantidad CHECK (cantidad > 0),
    CONSTRAINT chk_dv_importes CHECK (precio_unitario >= 0 AND importe >= 0),
    CONSTRAINT chk_dv_descuento CHECK (descuento_porcentaje BETWEEN 0 AND 100),
    INDEX idx_dv_venta (id_venta),
    INDEX idx_dv_medicamento (id_medicamento)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS historial_puntos (
    id_movimiento BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    id_cliente BIGINT UNSIGNED NOT NULL,
    id_venta BIGINT UNSIGNED NOT NULL,
    tipo_movimiento ENUM('ACUMULACION','CANJE','AJUSTE') NOT NULL,
    puntos SMALLINT NOT NULL,
    saldo_anterior SMALLINT UNSIGNED NOT NULL,
    saldo_nuevo SMALLINT UNSIGNED NOT NULL,
    descripcion VARCHAR(255) NULL,
    fecha_movimiento DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_hp_cliente FOREIGN KEY (id_cliente) REFERENCES clientes(id_cliente),
    CONSTRAINT fk_hp_venta FOREIGN KEY (id_venta) REFERENCES ventas(id_venta),
    CONSTRAINT chk_hp_saldos CHECK (saldo_anterior < 50 AND saldo_nuevo < 50),
    INDEX idx_hp_cliente_fecha (id_cliente, fecha_movimiento)
) ENGINE=InnoDB;

-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS facturas_simuladas (
    id_factura BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    folio_factura VARCHAR(30) NOT NULL UNIQUE,
    id_venta BIGINT UNSIGNED NOT NULL UNIQUE,
    id_datos_fiscales BIGINT UNSIGNED NOT NULL,
    fecha_emision DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_limite_solicitud DATE NOT NULL,
    correo_destino VARCHAR(150) NULL,
    ruta_pdf VARCHAR(500) NULL,
    estado_envio ENUM('PENDIENTE','ENVIADO','ERROR') NOT NULL DEFAULT 'PENDIENTE',
    fecha_envio DATETIME NULL,
    es_simulada BOOLEAN NOT NULL DEFAULT TRUE,
    nota_legal VARCHAR(255) NOT NULL DEFAULT 'Documento interno de prueba; no es un CFDI valido ante el SAT.',
    CONSTRAINT fk_factura_venta FOREIGN KEY (id_venta) REFERENCES ventas(id_venta),
    CONSTRAINT fk_factura_datos FOREIGN KEY (id_datos_fiscales) REFERENCES datos_fiscales_cliente(id_datos_fiscales),
    CONSTRAINT chk_factura_simulada CHECK (es_simulada = TRUE),
    INDEX idx_facturas_fecha (fecha_emision),
    INDEX idx_facturas_limite (fecha_limite_solicitud)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS movimientos_inventario (
    id_movimiento BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    id_medicamento BIGINT UNSIGNED NOT NULL,
    id_usuario BIGINT UNSIGNED NOT NULL,
    id_detalle_compra BIGINT UNSIGNED NULL,
    id_detalle_venta BIGINT UNSIGNED NULL,
    tipo_movimiento ENUM('ENTRADA_COMPRA','SALIDA_VENTA','AJUSTE_ENTRADA','AJUSTE_SALIDA') NOT NULL,
    cantidad INT UNSIGNED NOT NULL,
    stock_anterior INT UNSIGNED NOT NULL,
    stock_nuevo INT UNSIGNED NOT NULL,
    fecha_movimiento DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    observaciones VARCHAR(255) NULL,
    CONSTRAINT fk_mi_medicamento FOREIGN KEY (id_medicamento) REFERENCES medicamentos(id_medicamento),
    CONSTRAINT fk_mi_usuario FOREIGN KEY (id_usuario) REFERENCES usuarios(id_usuario),
    CONSTRAINT fk_mi_detalle_compra FOREIGN KEY (id_detalle_compra) REFERENCES detalle_compras(id_detalle_compra),
    CONSTRAINT fk_mi_detalle_venta FOREIGN KEY (id_detalle_venta) REFERENCES detalle_ventas(id_detalle_venta),
    CONSTRAINT chk_mi_cantidad CHECK (cantidad > 0),
    CONSTRAINT chk_mi_referencia CHECK (
        (tipo_movimiento = 'ENTRADA_COMPRA' AND id_detalle_compra IS NOT NULL AND id_detalle_venta IS NULL)
        OR (tipo_movimiento = 'SALIDA_VENTA' AND id_detalle_venta IS NOT NULL AND id_detalle_compra IS NULL)
        OR (tipo_movimiento IN ('AJUSTE_ENTRADA','AJUSTE_SALIDA') AND id_detalle_compra IS NULL AND id_detalle_venta IS NULL)
    ),
    INDEX idx_mi_medicamento_fecha (id_medicamento, fecha_movimiento)
) ENGINE=InnoDB;

INSERT IGNORE INTO roles (nombre, descripcion) VALUES
('Admin', 'Acceso completo al sistema'),
('Gerente', 'Administracion operativa, compras, ventas y reportes'),
('Encargado', 'Busqueda de productos, registro de clientes y ventas');

INSERT IGNORE INTO clasificaciones (nombre, descripcion) VALUES
('Analgesicos', 'Medicamentos para aliviar el dolor'),
('Antibioticos', 'Medicamentos antibioticos'),
('Antiinflamatorios', 'Medicamentos antiinflamatorios'),
('Antigripales', 'Medicamentos para sintomas de gripe y resfriado'),
('Antihistaminicos', 'Medicamentos para alergias'),
('Vitaminas y suplementos', 'Vitaminas y suplementos'),
('Gastrointestinales', 'Medicamentos para padecimientos gastrointestinales'),
('Material de curacion', 'Material e insumos de curacion'),
('Bebidas y productos', 'Productos comerciales distintos de medicamentos'),
('Otros', 'Productos sin clasificacion especifica');

-- No se inserta un administrador con contrasena predeterminada.
-- El primer usuario Admin debe crearse desde un proceso de inicializacion
-- en Python, generando un hash seguro de contrasena (Argon2 o bcrypt).

-- Clientes agrupados por estado y ciudad:
-- SELECT estado, ciudad, COUNT(*) AS total_clientes
-- FROM clientes WHERE activo = TRUE
-- GROUP BY estado, ciudad ORDER BY estado, ciudad;

-- Ventas por rango de fechas (usar limites inclusivos/exclusivos):
-- SELECT DATE(fecha_venta) AS fecha, COUNT(*) AS operaciones,
--        SUM(total) AS total_vendido
-- FROM ventas
-- WHERE estado = 'COMPLETADA'
--   AND fecha_venta >= '2026-01-01'
--   AND fecha_venta <  '2026-02-01'
-- GROUP BY DATE(fecha_venta) ORDER BY fecha;

-- Compras recibidas por rango de fechas:
-- SELECT DATE(c.fecha_compra) AS fecha, COUNT(*) AS operaciones,
--        SUM(c.total) AS total_comprado
-- FROM compras c
-- WHERE c.fecha_compra >= '2026-01-01'
--   AND c.fecha_compra <  '2026-02-01'
-- GROUP BY DATE(c.fecha_compra) ORDER BY fecha;

-- Facturas simuladas con mayores ventas:
-- SELECT f.folio_factura, v.folio_venta, v.fecha_venta, v.total
-- FROM facturas_simuladas f
-- INNER JOIN ventas v ON v.id_venta = f.id_venta
-- WHERE v.estado = 'COMPLETADA'
-- ORDER BY v.total DESC;

-- Medicamentos con existencias iguales o inferiores al minimo:
-- SELECT id_medicamento, nombre, existencias, stock_minimo
-- FROM medicamentos
-- WHERE activo = TRUE AND existencias <= stock_minimo
-- ORDER BY existencias ASC;

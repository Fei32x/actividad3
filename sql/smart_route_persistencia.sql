-- ==============================================================
-- SmartRoute / FlashRoute DSS - Arquitectura de Persistencia
-- Caso: FlashLogistics
-- Motor sugerido: PostgreSQL 14+
-- ==============================================================

DROP VIEW IF EXISTS vw_ranking_rutas_retraso;
DROP VIEW IF EXISTS vw_consumo_por_ruta_conductor;
DROP VIEW IF EXISTS vw_kpi_entregas_diarias;

DROP TABLE IF EXISTS importacion_detalles CASCADE;
DROP TABLE IF EXISTS importaciones CASCADE;
DROP TABLE IF EXISTS kpis_diarios CASCADE;
DROP TABLE IF EXISTS consumos_ruta CASCADE;
DROP TABLE IF EXISTS alertas CASCADE;
DROP TABLE IF EXISTS incidencias CASCADE;
DROP TABLE IF EXISTS historial_estados CASCADE;
DROP TABLE IF EXISTS ruta_paradas CASCADE;
DROP TABLE IF EXISTS rutas CASCADE;
DROP TABLE IF EXISTS pedidos CASCADE;
DROP TABLE IF EXISTS vehiculos CASCADE;
DROP TABLE IF EXISTS direcciones_entrega CASCADE;
DROP TABLE IF EXISTS clientes CASCADE;
DROP TABLE IF EXISTS conductores CASCADE;
DROP TABLE IF EXISTS usuarios CASCADE;
DROP TABLE IF EXISTS zonas CASCADE;

CREATE TABLE zonas (
    id_zona                BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre                 VARCHAR(80) NOT NULL UNIQUE,
    descripcion            VARCHAR(250),
    radio_km               NUMERIC(8,2) NOT NULL DEFAULT 0,
    CONSTRAINT chk_zonas_radio CHECK (radio_km >= 0)
);

CREATE TABLE usuarios (
    id_usuario             BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre                 VARCHAR(120) NOT NULL,
    correo                 VARCHAR(120) NOT NULL UNIQUE,
    telefono               VARCHAR(30),
    rol                    VARCHAR(20) NOT NULL,
    activo                 BOOLEAN NOT NULL DEFAULT TRUE,
    creado_en              TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_usuarios_rol CHECK (rol IN ('GERENTE','DESPACHADOR','CONDUCTOR'))
);

CREATE TABLE conductores (
    id_usuario             BIGINT PRIMARY KEY,
    nro_licencia           VARCHAR(40) NOT NULL UNIQUE,
    capacidad_entregas     INT NOT NULL DEFAULT 10,
    estado_disponibilidad  VARCHAR(20) NOT NULL DEFAULT 'DISPONIBLE',
    id_zona_base           BIGINT,
    CONSTRAINT fk_conductores_usuario
        FOREIGN KEY (id_usuario) REFERENCES usuarios(id_usuario)
        ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_conductores_zona
        FOREIGN KEY (id_zona_base) REFERENCES zonas(id_zona)
        ON UPDATE CASCADE ON DELETE SET NULL,
    CONSTRAINT chk_conductores_capacidad CHECK (capacidad_entregas BETWEEN 1 AND 30),
    CONSTRAINT chk_conductores_disponibilidad CHECK (estado_disponibilidad IN ('DISPONIBLE','EN_RUTA','DESCANSO','INACTIVO'))
);

CREATE TABLE clientes (
    id_cliente             BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre                 VARCHAR(120) NOT NULL,
    telefono               VARCHAR(30),
    correo                 VARCHAR(120),
    documento              VARCHAR(30),
    creado_en              TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE direcciones_entrega (
    id_direccion           BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_zona                BIGINT NOT NULL,
    calle                  VARCHAR(180) NOT NULL,
    referencia             VARCHAR(250),
    latitud                NUMERIC(10,7),
    longitud               NUMERIC(10,7),
    CONSTRAINT fk_direcciones_zona
        FOREIGN KEY (id_zona) REFERENCES zonas(id_zona)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT chk_latitud CHECK (latitud IS NULL OR latitud BETWEEN -90 AND 90),
    CONSTRAINT chk_longitud CHECK (longitud IS NULL OR longitud BETWEEN -180 AND 180)
);

CREATE TABLE vehiculos (
    id_vehiculo            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    placa                  VARCHAR(15) NOT NULL UNIQUE,
    tipo                   VARCHAR(40) NOT NULL,
    capacidad_kg           NUMERIC(10,2) NOT NULL,
    rendimiento_km_litro   NUMERIC(10,2) NOT NULL,
    activo                 BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT chk_vehiculos_capacidad CHECK (capacidad_kg > 0),
    CONSTRAINT chk_vehiculos_rendimiento CHECK (rendimiento_km_litro > 0)
);

CREATE TABLE pedidos (
    id_pedido              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    codigo                 VARCHAR(30) NOT NULL UNIQUE,
    id_cliente             BIGINT NOT NULL,
    id_direccion_entrega   BIGINT NOT NULL,
    id_despachador         BIGINT NOT NULL,
    fecha_pedido           DATE NOT NULL DEFAULT CURRENT_DATE,
    peso_kg                NUMERIC(10,2) NOT NULL,
    hora_limite            TIME NOT NULL,
    prioridad              VARCHAR(10) NOT NULL DEFAULT 'MEDIA',
    estado                 VARCHAR(25) NOT NULL DEFAULT 'PENDIENTE_RUTA',
    fecha_entrega          TIMESTAMP,
    observacion            VARCHAR(300),
    creado_en              TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    actualizado_en         TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_pedidos_cliente
        FOREIGN KEY (id_cliente) REFERENCES clientes(id_cliente)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_pedidos_direccion
        FOREIGN KEY (id_direccion_entrega) REFERENCES direcciones_entrega(id_direccion)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_pedidos_despachador
        FOREIGN KEY (id_despachador) REFERENCES usuarios(id_usuario)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT chk_pedidos_peso CHECK (peso_kg > 0),
    CONSTRAINT chk_pedidos_prioridad CHECK (prioridad IN ('BAJA','MEDIA','ALTA','URGENTE')),
    CONSTRAINT chk_pedidos_estado CHECK (estado IN ('PENDIENTE_RUTA','ASIGNADO','EN_RUTA','ENTREGADO','RETRASADO','CANCELADO','INCIDENCIA'))
);

CREATE TABLE rutas (
    id_ruta                BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    codigo                 VARCHAR(30) NOT NULL UNIQUE,
    fecha_programada       DATE NOT NULL,
    id_conductor           BIGINT NOT NULL,
    id_vehiculo            BIGINT NOT NULL,
    id_despachador         BIGINT NOT NULL,
    id_zona                BIGINT NOT NULL,
    distancia_total_km     NUMERIC(10,2) NOT NULL DEFAULT 0,
    tiempo_estimado_min    INT NOT NULL DEFAULT 0,
    costo_combustible_estimado NUMERIC(12,2) NOT NULL DEFAULT 0,
    estado                 VARCHAR(20) NOT NULL DEFAULT 'PLANIFICADA',
    creado_en              TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_rutas_conductor
        FOREIGN KEY (id_conductor) REFERENCES conductores(id_usuario)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_rutas_vehiculo
        FOREIGN KEY (id_vehiculo) REFERENCES vehiculos(id_vehiculo)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_rutas_despachador
        FOREIGN KEY (id_despachador) REFERENCES usuarios(id_usuario)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_rutas_zona
        FOREIGN KEY (id_zona) REFERENCES zonas(id_zona)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT chk_rutas_distancia CHECK (distancia_total_km >= 0),
    CONSTRAINT chk_rutas_tiempo CHECK (tiempo_estimado_min >= 0),
    CONSTRAINT chk_rutas_costo CHECK (costo_combustible_estimado >= 0),
    CONSTRAINT chk_rutas_estado CHECK (estado IN ('PLANIFICADA','EN_PROGRESO','FINALIZADA','CANCELADA'))
);

CREATE TABLE ruta_paradas (
    id_parada              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_ruta                BIGINT NOT NULL,
    id_pedido              BIGINT NOT NULL UNIQUE,
    orden                  INT NOT NULL,
    hora_estimada          TIMESTAMP,
    km_estimado            NUMERIC(10,2) NOT NULL DEFAULT 0,
    estado_parada          VARCHAR(20) NOT NULL DEFAULT 'PENDIENTE',
    CONSTRAINT fk_paradas_ruta
        FOREIGN KEY (id_ruta) REFERENCES rutas(id_ruta)
        ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_paradas_pedido
        FOREIGN KEY (id_pedido) REFERENCES pedidos(id_pedido)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT uq_paradas_orden UNIQUE (id_ruta, orden),
    CONSTRAINT chk_paradas_orden CHECK (orden > 0),
    CONSTRAINT chk_paradas_km CHECK (km_estimado >= 0),
    CONSTRAINT chk_paradas_estado CHECK (estado_parada IN ('PENDIENTE','EN_CAMINO','ENTREGADO','INCIDENCIA','CANCELADO'))
);

CREATE TABLE historial_estados (
    id_historial           BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_pedido              BIGINT NOT NULL,
    estado_anterior        VARCHAR(25),
    estado_nuevo           VARCHAR(25) NOT NULL,
    actualizado_por        BIGINT NOT NULL,
    fecha_cambio           TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    comentario             VARCHAR(300),
    CONSTRAINT fk_historial_pedido
        FOREIGN KEY (id_pedido) REFERENCES pedidos(id_pedido)
        ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_historial_usuario
        FOREIGN KEY (actualizado_por) REFERENCES usuarios(id_usuario)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT chk_historial_estado_nuevo CHECK (estado_nuevo IN ('PENDIENTE_RUTA','ASIGNADO','EN_RUTA','ENTREGADO','RETRASADO','CANCELADO','INCIDENCIA'))
);

CREATE TABLE incidencias (
    id_incidencia          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_pedido              BIGINT NOT NULL,
    id_conductor           BIGINT NOT NULL,
    tipo                   VARCHAR(30) NOT NULL,
    descripcion            TEXT NOT NULL,
    latitud                NUMERIC(10,7),
    longitud               NUMERIC(10,7),
    fecha_reporte          TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    resuelta               BOOLEAN NOT NULL DEFAULT FALSE,
    CONSTRAINT fk_incidencias_pedido
        FOREIGN KEY (id_pedido) REFERENCES pedidos(id_pedido)
        ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_incidencias_conductor
        FOREIGN KEY (id_conductor) REFERENCES conductores(id_usuario)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT chk_incidencias_tipo CHECK (tipo IN ('TRAFICO','VEHICULO','CLIENTE_AUSENTE','DIRECCION_ERRONEA','OTRO')),
    CONSTRAINT chk_incidencias_lat CHECK (latitud IS NULL OR latitud BETWEEN -90 AND 90),
    CONSTRAINT chk_incidencias_lon CHECK (longitud IS NULL OR longitud BETWEEN -180 AND 180)
);

CREATE TABLE alertas (
    id_alerta              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_pedido              BIGINT NOT NULL,
    id_ruta                BIGINT,
    tipo                   VARCHAR(30) NOT NULL,
    mensaje                TEXT NOT NULL,
    fecha_generacion       TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    atendida               BOOLEAN NOT NULL DEFAULT FALSE,
    CONSTRAINT fk_alertas_pedido
        FOREIGN KEY (id_pedido) REFERENCES pedidos(id_pedido)
        ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_alertas_ruta
        FOREIGN KEY (id_ruta) REFERENCES rutas(id_ruta)
        ON UPDATE CASCADE ON DELETE SET NULL,
    CONSTRAINT chk_alertas_tipo CHECK (tipo IN ('RETRASO','INCIDENCIA','CAPACIDAD','COMBUSTIBLE'))
);

CREATE TABLE consumos_ruta (
    id_consumo             BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_ruta                BIGINT NOT NULL UNIQUE,
    km_recorridos          NUMERIC(10,2) NOT NULL,
    litros_estimados       NUMERIC(10,2) NOT NULL,
    precio_litro           NUMERIC(10,2) NOT NULL,
    costo_estimado         NUMERIC(12,2) NOT NULL,
    creado_en              TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_consumos_ruta
        FOREIGN KEY (id_ruta) REFERENCES rutas(id_ruta)
        ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT chk_consumos_km CHECK (km_recorridos >= 0),
    CONSTRAINT chk_consumos_litros CHECK (litros_estimados >= 0),
    CONSTRAINT chk_consumos_precio CHECK (precio_litro > 0),
    CONSTRAINT chk_consumos_costo CHECK (costo_estimado >= 0)
);

CREATE TABLE importaciones (
    id_importacion         BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre_archivo         VARCHAR(180) NOT NULL,
    tipo_archivo           VARCHAR(10) NOT NULL,
    cargado_por            BIGINT NOT NULL,
    total_registros        INT NOT NULL DEFAULT 0,
    registros_exitosos     INT NOT NULL DEFAULT 0,
    registros_error        INT NOT NULL DEFAULT 0,
    fecha_importacion      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_importaciones_usuario
        FOREIGN KEY (cargado_por) REFERENCES usuarios(id_usuario)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT chk_importaciones_tipo CHECK (tipo_archivo IN ('CSV','XLSX')),
    CONSTRAINT chk_importaciones_totales CHECK (total_registros >= 0 AND registros_exitosos >= 0 AND registros_error >= 0)
);

CREATE TABLE importacion_detalles (
    id_detalle             BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_importacion         BIGINT NOT NULL,
    numero_fila            INT NOT NULL,
    estado                 VARCHAR(10) NOT NULL,
    mensaje_error          VARCHAR(300),
    id_pedido              BIGINT,
    CONSTRAINT fk_detalles_importacion
        FOREIGN KEY (id_importacion) REFERENCES importaciones(id_importacion)
        ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_detalles_pedido
        FOREIGN KEY (id_pedido) REFERENCES pedidos(id_pedido)
        ON UPDATE CASCADE ON DELETE SET NULL,
    CONSTRAINT chk_detalles_fila CHECK (numero_fila > 0),
    CONSTRAINT chk_detalles_estado CHECK (estado IN ('OK','ERROR'))
);

CREATE TABLE kpis_diarios (
    id_kpi                 BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    fecha                  DATE NOT NULL UNIQUE,
    entregas_total         INT NOT NULL DEFAULT 0,
    entregas_tarde         INT NOT NULL DEFAULT 0,
    porcentaje_tardias     NUMERIC(5,2) NOT NULL DEFAULT 0,
    tiempo_planificacion_prom_min NUMERIC(10,2) NOT NULL DEFAULT 0,
    llamadas_cliente       INT NOT NULL DEFAULT 0,
    consumo_total_estimado NUMERIC(12,2) NOT NULL DEFAULT 0,
    actualizado_en         TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_kpis_entregas CHECK (entregas_total >= 0 AND entregas_tarde >= 0),
    CONSTRAINT chk_kpis_porcentaje CHECK (porcentaje_tardias BETWEEN 0 AND 100),
    CONSTRAINT chk_kpis_tiempo CHECK (tiempo_planificacion_prom_min >= 0),
    CONSTRAINT chk_kpis_llamadas CHECK (llamadas_cliente >= 0),
    CONSTRAINT chk_kpis_consumo CHECK (consumo_total_estimado >= 0)
);

-- Índices para consultas frecuentes del DSS
CREATE INDEX idx_pedidos_estado_fecha ON pedidos (estado, fecha_pedido);
CREATE INDEX idx_pedidos_hora_limite ON pedidos (fecha_pedido, hora_limite);
CREATE INDEX idx_rutas_fecha_estado ON rutas (fecha_programada, estado);
CREATE INDEX idx_paradas_ruta_orden ON ruta_paradas (id_ruta, orden);
CREATE INDEX idx_alertas_atendida ON alertas (atendida, fecha_generacion);
CREATE INDEX idx_historial_pedido_fecha ON historial_estados (id_pedido, fecha_cambio);

-- Vistas analíticas para el dashboard gerencial
CREATE VIEW vw_kpi_entregas_diarias AS
SELECT
    p.fecha_pedido AS fecha,
    COUNT(*) AS total_pedidos,
    SUM(CASE
            WHEN p.estado = 'RETRASADO'
              OR (p.fecha_entrega IS NOT NULL AND CAST(p.fecha_entrega AS TIME) > p.hora_limite)
            THEN 1 ELSE 0
        END) AS entregas_tardias,
    ROUND(
        100.0 * SUM(CASE
            WHEN p.estado = 'RETRASADO'
              OR (p.fecha_entrega IS NOT NULL AND CAST(p.fecha_entrega AS TIME) > p.hora_limite)
            THEN 1 ELSE 0
        END) / NULLIF(COUNT(*), 0), 2
    ) AS porcentaje_tardias
FROM pedidos p
GROUP BY p.fecha_pedido;

CREATE VIEW vw_consumo_por_ruta_conductor AS
SELECT
    r.id_ruta,
    r.codigo AS codigo_ruta,
    r.fecha_programada,
    u.nombre AS conductor,
    v.placa,
    r.distancia_total_km,
    cr.litros_estimados,
    cr.costo_estimado
FROM rutas r
JOIN conductores c ON c.id_usuario = r.id_conductor
JOIN usuarios u ON u.id_usuario = c.id_usuario
JOIN vehiculos v ON v.id_vehiculo = r.id_vehiculo
LEFT JOIN consumos_ruta cr ON cr.id_ruta = r.id_ruta;

CREATE VIEW vw_ranking_rutas_retraso AS
SELECT
    r.id_ruta,
    r.codigo AS codigo_ruta,
    r.fecha_programada,
    COUNT(rp.id_parada) AS total_paradas,
    SUM(CASE WHEN p.estado = 'RETRASADO' THEN 1 ELSE 0 END) AS pedidos_retrasados,
    ROUND(100.0 * SUM(CASE WHEN p.estado = 'RETRASADO' THEN 1 ELSE 0 END) / NULLIF(COUNT(rp.id_parada), 0), 2) AS porcentaje_retraso
FROM rutas r
JOIN ruta_paradas rp ON rp.id_ruta = r.id_ruta
JOIN pedidos p ON p.id_pedido = rp.id_pedido
GROUP BY r.id_ruta, r.codigo, r.fecha_programada
ORDER BY porcentaje_retraso DESC;

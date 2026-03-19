
-- UD7 - SQL: Manipulación de Datos y Gestión de Transacciones
-- Actividad 1: Ejercicios DML y Control TCL

-- ============================================================
-- PASO 1: ESPEJO DE DATOS
-- ============================================================
CREATE TABLE productos_u4 AS SELECT * FROM OE.PRODUCT_INFORMATION;
CREATE TABLE inventario_u4 AS SELECT * FROM OE.INVENTORIES;

-- ============================================================
-- PASO 2: BLOQUE DE INSERCIÓN (INSERT)
-- ============================================================

-- 1. Simple: producto ID 7000
INSERT INTO productos_u4 (product_id, product_name, list_price)
VALUES (7000, 'Cable HDMI 2.1', 25);

-- 2. Columnas específicas: producto 7001
INSERT INTO productos_u4 (product_id, product_name, category_id)
VALUES (7001, 'Hub USB-C', 10);

-- 3. Uso de Nulos: producto 7002 con warranty_period NULL
INSERT INTO productos_u4 (
    product_id, product_name, product_description,
    category_id, weight_class, warranty_period,
    supplier_id, product_status, list_price, min_price,
    catalog_url
)
VALUES (
    7002, 'Ratón Inalámbrico', 'Ratón ergonómico sin cable',
    10, 1, NULL,
    102, 'available', 35, 20,
    'http://ejemplo.com/raton'
);

-- 4. Sintaxis de Fecha: tabla de log con SYSDATE
CREATE TABLE log_pedidos (
    log_id     NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    descripcion VARCHAR2(200),
    fecha_log  DATE
);

INSERT INTO log_pedidos (descripcion, fecha_log)
VALUES ('Pedido de prueba automático', SYSDATE);

-- 5. Copia de fila: idéntico al producto 1797 pero con ID 7003
INSERT INTO productos_u4
SELECT 7003,
       product_name, product_description, category_id,
       weight_class, warranty_period, supplier_id,
       product_status, list_price, min_price, catalog_url
FROM   productos_u4
WHERE  product_id = 1797;

-- 6. Inserción Masiva: productos con list_price > 5000
INSERT INTO productos_u4
SELECT *
FROM   OE.PRODUCT_INFORMATION
WHERE  list_price > 5000;

-- 7. Subconsulta con Filtro: categoría 11 no existentes en productos_u4
INSERT INTO productos_u4
SELECT *
FROM   OE.PRODUCT_INFORMATION p
WHERE  p.category_id = 11
  AND  p.product_id NOT IN (
           SELECT product_id FROM productos_u4
       );

-- 8. Carga Parcial: product_id y product_name de productos con stock en almacén 1
--    (usamos una tabla auxiliar para almacenar solo esas columnas)
CREATE TABLE productos_almacen1 (
    product_id   NUMBER,
    product_name VARCHAR2(50)
);

INSERT INTO productos_almacen1 (product_id, product_name)
SELECT DISTINCT p.product_id, p.product_name
FROM   productos_u4 p
JOIN   inventario_u4 i ON p.product_id = i.product_id
WHERE  i.warehouse_id = 1;

-- 9. Cálculo en Inserción: producto 7005 con list_price = 2 × media categoría 10
INSERT INTO productos_u4 (product_id, product_name, category_id, list_price)
SELECT 7005,
       'Producto Calculado Cat10',
       10,
       2 * AVG(list_price)
FROM   productos_u4
WHERE  category_id = 10;

-- 10. Multitabla: tabla precios_altos con productos > 1000
CREATE TABLE precios_altos AS SELECT * FROM productos_u4 WHERE 1=0;  -- estructura vacía

INSERT INTO precios_altos
SELECT *
FROM   productos_u4
WHERE  list_price > 1000;


-- ============================================================
-- PASO 3: BLOQUE DE MODIFICACIÓN (UPDATE)
-- ============================================================

-- 1. Directo: product_status = 'obsolete' para el producto 1797
UPDATE productos_u4
SET    product_status = 'obsolete'
WHERE  product_id = 1797;

-- 2. Múltiple: min_price = 50 y list_price = 80 para el producto 7000
UPDATE productos_u4
SET    min_price  = 50,
       list_price = 80
WHERE  product_id = 7000;

-- 3. Filtro Simple: incremento de 10 en precio para categoría 12
UPDATE productos_u4
SET    list_price = list_price + 10
WHERE  category_id = 12;

-- 4. Uso de LIKE: 'discontinued' para productos cuyo nombre empiece por 'Software'
UPDATE productos_u4
SET    product_status = 'discontinued'
WHERE  product_name LIKE 'Software%';

-- 5. Basado en NULL: min_price = 5 donde sea nulo
UPDATE productos_u4
SET    min_price = 5
WHERE  min_price IS NULL;

-- 6. Cálculo Porcentual: rebaja 20% para weight_class = 5
UPDATE productos_u4
SET    list_price = list_price * 0.80
WHERE  weight_class = 5;

-- 7. Subconsulta Simple: subir 100 a productos de categoría 'Software/Other'
UPDATE productos_u4
SET    list_price = list_price + 100
WHERE  category_id = (
           SELECT category_id
           FROM   OE.PRODUCT_CATEGORIES
           WHERE  category_name = 'Software/Other'
       );

-- 8. Update Correlacionado: min_price = precio mínimo en order_items
UPDATE productos_u4 p
SET    p.min_price = (
           SELECT MIN(oi.unit_price)
           FROM   OE.ORDER_ITEMS oi
           WHERE  oi.product_id = p.product_id
       )
WHERE  EXISTS (
           SELECT 1
           FROM   OE.ORDER_ITEMS oi
           WHERE  oi.product_id = p.product_id
       );

-- 9. Condición de Existencia: status = 'available' si hay al menos 1 unidad en inventario
UPDATE productos_u4 p
SET    p.product_status = 'available'
WHERE  EXISTS (
           SELECT 1
           FROM   inventario_u4 i
           WHERE  i.product_id = p.product_id
             AND  i.quantity_on_hand >= 1
       );

-- 10. Lógica Compleja: reducir 5% si list_price > media global
UPDATE productos_u4
SET    list_price = list_price * 0.95
WHERE  list_price > (
           SELECT AVG(list_price) FROM productos_u4
       );


-- ============================================================
-- PASO 4: BLOQUE DE BORRADO (DELETE)
-- ============================================================

-- 1. ID Específico: borra el producto 7000
DELETE FROM productos_u4
WHERE  product_id = 7000;

-- 2. Filtro de Texto: productos que contengan 'Test' en la descripción
DELETE FROM productos_u4
WHERE  product_description LIKE '%Test%';

-- 3. Rango Numérico: list_price entre 0 y 1
DELETE FROM productos_u4
WHERE  list_price BETWEEN 0 AND 1;

-- 4. Estado y Categoría: categoría 10 en 'under development'
DELETE FROM productos_u4
WHERE  category_id    = 10
  AND  product_status = 'under development';

-- 5. Sin Inventario: productos sin ninguna entrada en inventario_u4
DELETE FROM productos_u4
WHERE  product_id NOT IN (
           SELECT DISTINCT product_id FROM inventario_u4
       );

-- 6. Subconsulta de Agregación: productos cuyo min_price sea el más bajo de la tabla
DELETE FROM productos_u4
WHERE  min_price = (
           SELECT MIN(min_price) FROM productos_u4
       );

-- 7. Relacional: productos que nunca hayan sido vendidos (no están en order_items)
DELETE FROM productos_u4
WHERE  product_id NOT IN (
           SELECT DISTINCT product_id FROM OE.ORDER_ITEMS
       );

-- 8. Basado en Almacén: inventario de almacenes en 'Japan'
DELETE FROM inventario_u4
WHERE  warehouse_id IN (
           SELECT w.warehouse_id
           FROM   OE.WAREHOUSES  w
           JOIN   OE.LOCATIONS   l ON w.location_id = l.location_id
           JOIN   OE.COUNTRIES   c ON l.country_id  = c.country_id
           WHERE  c.country_name = 'Japan'
       );

-- 9. Doble Condición Subquery: categorías con menos de 5 productos
DELETE FROM productos_u4
WHERE  category_id IN (
           SELECT category_id
           FROM   productos_u4
           GROUP  BY category_id
           HAVING COUNT(*) < 5
       );

-- 10. Limpieza Total: IDs entre 7000 y 8000 (los insertados en el Paso 2)
DELETE FROM productos_u4
WHERE  product_id BETWEEN 7000 AND 8000;


-- ============================================================
-- PASO 5: TRANSACCIONES Y CONCURRENCIA
-- ============================================================

-- Crear tabla bancaria
CREATE TABLE cuenta_bancaria (
    id      NUMBER PRIMARY KEY,
    titular VARCHAR2(50),
    saldo   NUMBER(10,2)
);
INSERT INTO cuenta_bancaria VALUES (1, 'Usuario A', 1000);
INSERT INTO cuenta_bancaria VALUES (2, 'Usuario B', 2000);
COMMIT;

-- -----------------------------------------------------------
-- ESCENARIO 1: Atomicidad (All-or-Nothing)
-- -----------------------------------------------------------
-- Script que falla a mitad (la cuenta 99 no existe)
UPDATE cuenta_bancaria SET saldo = saldo - 500 WHERE id = 1;
UPDATE cuenta_bancaria SET saldo = saldo + 500 WHERE id = 99; -- ERROR: no existe

-- Si la cuenta 1 tiene ya 500€ (transacción a medias), restaurar integridad:
ROLLBACK;
-- Verificación
SELECT * FROM cuenta_bancaria;

-- -----------------------------------------------------------
-- ESCENARIO 2: Puntos de Guardado (SAVEPOINT)
-- -----------------------------------------------------------
-- 1. Subida del 10% + primer savepoint
UPDATE cuenta_bancaria SET saldo = saldo * 1.10;
SAVEPOINT sp_subida;

-- 2. Nuevo usuario + segundo savepoint
INSERT INTO cuenta_bancaria VALUES (3, 'Usuario C', 500);
SAVEPOINT sp_nuevo_usuario;

-- 3. Borrado accidental
DELETE FROM cuenta_bancaria;

-- 4. Recuperación al punto justo antes del borrado
ROLLBACK TO SAVEPOINT sp_nuevo_usuario;

-- Verificación: deben aparecer los 3 usuarios con saldo ya subido 10%
SELECT * FROM cuenta_bancaria;
COMMIT;

-- -----------------------------------------------------------
-- ESCENARIO 3: Bloqueos y Tiempo de Espera
-- -----------------------------------------------------------
-- Terminal T1 (NO hacer COMMIT todavía):
UPDATE cuenta_bancaria SET saldo = 0 WHERE id = 1;

-- Terminal T2 (se queda bloqueada esperando que T1 libere el lock):
UPDATE cuenta_bancaria SET saldo = 5000 WHERE id = 1;

-- T1: libera el bloqueo
COMMIT;
-- T2 se desbloquea y aplica su UPDATE sobre el valor confirmado.

-- -----------------------------------------------------------
-- ESCENARIO 4: "Commit Fantasma" (DDL implica COMMIT)
-- -----------------------------------------------------------
-- 1. Borrar Usuario 2 (sin COMMIT)
DELETE FROM cuenta_bancaria WHERE id = 2;

-- 2. Crear tabla DDL → Oracle hace COMMIT implícito del DELETE anterior
CREATE TABLE log_errores (msg VARCHAR2(100));

-- 3. Intentar deshacer
ROLLBACK;

-- 4. Verificación: el Usuario 2 NO vuelve (el DELETE se confirmó implícitamente)
SELECT * FROM cuenta_bancaria;


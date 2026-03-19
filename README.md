# UD7 – SQL: Manipulación de Datos y Gestión de Transacciones
## Memoria de Prácticas · Actividad 1

---

## Paso 1 – Espejo de Datos

Antes de cualquier modificación se crean copias de trabajo para no alterar los datos maestros del esquema `OE`:

```sql
CREATE TABLE productos_u4  AS SELECT * FROM OE.PRODUCT_INFORMATION;
CREATE TABLE inventario_u4 AS SELECT * FROM OE.INVENTORIES;
```

Con `CREATE TABLE … AS SELECT` Oracle copia tanto la estructura como los datos en una sola sentencia, sin restricciones de integridad referencial.

---

## Paso 2 – Bloque de Inserción (INSERT)

### 1. Simple
```sql
INSERT INTO productos_u4 (product_id, product_name, list_price)
VALUES (7000, 'Cable HDMI 2.1', 25);
```
La forma más básica: se especifican solo las columnas necesarias; las demás quedan a `NULL`.

### 2. Columnas específicas
```sql
INSERT INTO productos_u4 (product_id, product_name, category_id)
VALUES (7001, 'Hub USB-C', 10);
```
Indicar la lista de columnas hace la sentencia robusta ante futuros cambios de esquema.

### 3. Uso de Nulos
```sql
INSERT INTO productos_u4 (product_id, product_name, ..., warranty_period, ...)
VALUES (7002, 'Ratón Inalámbrico', ..., NULL, ...);
```
`NULL` se inserta explícitamente en `warranty_period`. Las columnas con `NOT NULL` deben recibir valor.

### 4. Sintaxis de Fecha con SYSDATE
```sql
CREATE TABLE log_pedidos (log_id NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
                          descripcion VARCHAR2(200), fecha_log DATE);
INSERT INTO log_pedidos (descripcion, fecha_log)
VALUES ('Pedido de prueba automático', SYSDATE);
```
`SYSDATE` devuelve la fecha y hora actuales del servidor. No lleva paréntesis en Oracle.

### 5. Copia de fila
```sql
INSERT INTO productos_u4
SELECT 7003, product_name, product_description, category_id,
       weight_class, warranty_period, supplier_id,
       product_status, list_price, min_price, catalog_url
FROM   productos_u4
WHERE  product_id = 1797;
```
Se usa `INSERT … SELECT` para clonar un registro cambiando únicamente el `product_id`.

### 6. Inserción Masiva
```sql
INSERT INTO productos_u4
SELECT * FROM OE.PRODUCT_INFORMATION
WHERE  list_price > 5000;
```
Un solo `INSERT` puede cargar miles de filas.

### 7. Subconsulta con Filtro (NOT IN)
```sql
INSERT INTO productos_u4
SELECT * FROM OE.PRODUCT_INFORMATION p
WHERE  p.category_id = 11
  AND  p.product_id NOT IN (SELECT product_id FROM productos_u4);
```
Garantiza que no se dupliquen registros ya presentes en la tabla destino.

### 8. Carga Parcial
```sql
CREATE TABLE productos_almacen1 (product_id NUMBER, product_name VARCHAR2(50));
INSERT INTO productos_almacen1 (product_id, product_name)
SELECT DISTINCT p.product_id, p.product_name
FROM   productos_u4 p JOIN inventario_u4 i ON p.product_id = i.product_id
WHERE  i.warehouse_id = 1;
```
Solo se insertan las columnas relevantes para el caso de uso, reduciendo el tamaño de la tabla auxiliar.

### 9. Cálculo en Inserción
```sql
INSERT INTO productos_u4 (product_id, product_name, category_id, list_price)
SELECT 7005, 'Producto Calculado Cat10', 10, 2 * AVG(list_price)
FROM   productos_u4
WHERE  category_id = 10;
```
El `SELECT` puede incluir funciones de agregación; Oracle calcula el resultado antes de insertar.

### 10. Multitabla (INSERT … SELECT)
```sql
CREATE TABLE precios_altos AS SELECT * FROM productos_u4 WHERE 1=0;
INSERT INTO precios_altos SELECT * FROM productos_u4 WHERE list_price > 1000;
```
`WHERE 1=0` crea la tabla vacía con la estructura correcta. Luego se cargan los datos con un `INSERT … SELECT`.

---

## Paso 3 – Bloque de Modificación (UPDATE)

| # | Descripción | Clave técnica |
|---|-------------|---------------|
| 1 | Estado a `obsolete` para ID 1797 | `WHERE product_id = 1797` |
| 2 | Múltiple columnas en ID 7000 | `SET min_price=50, list_price=80` |
| 3 | +10 en precio categoría 12 | `SET list_price = list_price + 10` |
| 4 | `discontinued` con LIKE | `WHERE product_name LIKE 'Software%'` |
| 5 | `min_price=5` donde sea NULL | `WHERE min_price IS NULL` |
| 6 | Rebaja 20% weight_class=5 | `SET list_price = list_price * 0.80` |
| 7 | +100 subconsulta a categoría | `WHERE category_id = (SELECT ...)` |
| 8 | Update correlacionado | Subconsulta en `SET` con referencia exterior |
| 9 | Disponibles si hay stock | `WHERE EXISTS (SELECT 1 FROM inventario …)` |
| 10 | −5% si precio > media global | `WHERE list_price > (SELECT AVG …)` |

**Punto clave del Update Correlacionado (ejercicio 8):**

```sql
UPDATE productos_u4 p
SET    p.min_price = (SELECT MIN(oi.unit_price)
                     FROM OE.ORDER_ITEMS oi
                     WHERE oi.product_id = p.product_id)
WHERE  EXISTS (SELECT 1 FROM OE.ORDER_ITEMS oi
               WHERE oi.product_id = p.product_id);
```
La subconsulta del `SET` se ejecuta una vez por cada fila que cumple el `WHERE`. El `EXISTS` evita poner `NULL` en productos sin pedidos.

---

## Paso 4 – Bloque de Borrado (DELETE)

| # | Descripción | Técnica utilizada |
|---|-------------|-------------------|
| 1 | Borrar producto 7000 | `WHERE product_id = 7000` |
| 2 | Descripción contiene 'Test' | `LIKE '%Test%'` |
| 3 | Precio entre 0 y 1 | `BETWEEN 0 AND 1` |
| 4 | Categoría 10 + estado | Condición compuesta `AND` |
| 5 | Sin inventario | `NOT IN (SELECT DISTINCT …)` |
| 6 | min_price mínimo global | `= (SELECT MIN(min_price) …)` |
| 7 | Nunca vendidos | `NOT IN (SELECT DISTINCT … ORDER_ITEMS)` |
| 8 | Almacenes en Japan | `JOIN` de tres tablas en subconsulta |
| 9 | Categorías < 5 productos | `HAVING COUNT(*) < 5` |
| 10 | Limpieza IDs 7000–8000 | `BETWEEN 7000 AND 8000` |

> **Buena práctica:** Antes de ejecutar un `DELETE` masivo, lanzar primero el `SELECT` equivalente para revisar exactamente qué filas se eliminarán.

---

## Paso 5 – Transacciones y Concurrencia

### Escenario 1 – Atomicidad

Se simula una transferencia bancaria donde el segundo paso falla porque la cuenta destino (ID 99) no existe.

```sql
UPDATE cuenta_bancaria SET saldo = saldo - 500 WHERE id = 1;
UPDATE cuenta_bancaria SET saldo = saldo + 500 WHERE id = 99; -- ERROR ORA-02291
-- La cuenta 1 tiene 500€ pero el dinero no llegó a ningún lado.
ROLLBACK; -- Restaura los 1000€ originales de la cuenta 1.
```

**¿Por qué es vital el ROLLBACK?**
Sin él, la base de datos queda inconsistente: los 500€ desaparecen del sistema. El principio de **Atomicidad** (la A de ACID) exige que una transacción se complete entera o no se ejecute en absoluto. En un sistema real se usaría un bloque `BEGIN … EXCEPTION WHEN OTHERS THEN ROLLBACK; END;` para capturar el error automáticamente.

---

### Escenario 2 – Puntos de Guardado (SAVEPOINT)

```
Estado inicial: Usuario A=1000, Usuario B=2000
  │
  ▼  UPDATE × 1.10
  SAVEPOINT sp_subida          → A=1100, B=2200
  │
  ▼  INSERT Usuario C=500
  SAVEPOINT sp_nuevo_usuario   → A=1100, B=2200, C=500
  │
  ▼  DELETE FROM cuenta_bancaria  (¡accidental!)
  │
  ▼  ROLLBACK TO SAVEPOINT sp_nuevo_usuario
  │
  └─ Estado recuperado: A=1100, B=2200, C=500  ✓
```

Los `SAVEPOINT` permiten deshacer parcialmente una transacción sin perder todo el trabajo previo. Después del `ROLLBACK TO SAVEPOINT` la transacción sigue abierta; hay que hacer `COMMIT` para confirmar.

---

### Escenario 3 – Bloqueos y Tiempo de Espera

| Terminal T1 | Terminal T2 |
|-------------|-------------|
| `UPDATE … SET saldo=0 WHERE id=1;` | — |
| — | `UPDATE … SET saldo=5000 WHERE id=1;` → **BLOQUEADA** |
| `COMMIT;` | Se desbloquea y aplica el UPDATE |

Oracle usa **bloqueos a nivel de fila**. T1 adquiere un bloqueo exclusivo sobre la fila `id=1`. T2 debe esperar hasta que T1 libere ese bloqueo con `COMMIT` o `ROLLBACK`. Esto garantiza el principio de **Aislamiento** (la I de ACID) y evita lecturas sucias.

---

### Escenario 4 – "Commit Fantasma" (DDL implícito)

```sql
DELETE FROM cuenta_bancaria WHERE id = 2; -- DML pendiente (sin COMMIT)
CREATE TABLE log_errores (msg VARCHAR2(100)); -- DDL → COMMIT implícito del DELETE
ROLLBACK; -- No tiene efecto: el DELETE ya fue confirmado
SELECT * FROM cuenta_bancaria; -- El Usuario 2 NO aparece
```

**Comportamiento de Oracle ante DDL:**
Toda sentencia DDL (`CREATE`, `ALTER`, `DROP`, `TRUNCATE`…) emite un **COMMIT implícito** sobre la transacción DML activa antes de ejecutarse. Esto significa que el `DELETE` del Usuario 2 quedó confirmado permanentemente en cuanto se procesó el `CREATE TABLE`. El `ROLLBACK` posterior no tiene nada que deshacer.

---


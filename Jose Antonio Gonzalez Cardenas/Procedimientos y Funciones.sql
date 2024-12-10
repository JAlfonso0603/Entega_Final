-- ---------------------------------------------------------------------------------------------------

-- Operación creada por: Jose Antonio Gonzalez Cardenas
-- Funcionamiento: Gestionar asignación mangas en sucursales
-- Condiciones:
-- 1. Verificar Stock Disponible en Sucursal
-- 2. Verificar la Ubicación Física Disponible
-- 3. Asignar Mangas a Ubicación Física

-- ---------------------------------------------------------------------------------------------------

-- 1. Verificar Stock Disponible en Sucursal
CREATE OR REPLACE FUNCTION verificar_stock_disponible(id_manga INT, cantidad INT) 
RETURNS BOOLEAN AS $$
DECLARE
    stock_disponible INT;
BEGIN
    -- Paso 1: Obtener el stock disponible del manga desde la tabla Mangas
    SELECT stock INTO stock_disponible
    FROM Mangas
    WHERE idManga = id_manga;

    -- Paso 2: Validar si el manga existe
    IF stock_disponible IS NULL THEN
        RETURN FALSE; -- Retorna FALSE si el manga no existe o no tiene stock registrado
    END IF;

    -- Paso 3: Verificar si el stock disponible es suficiente
    IF stock_disponible >= cantidad THEN
        RETURN TRUE; -- Retorna TRUE si hay suficiente stock
    ELSE
        RETURN FALSE; -- Retorna FALSE si el stock no es suficiente
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Uso de la Función:
SELECT verificar_stock_disponible(2, 1);



-- 2. Verificar la Ubicación Física Disponible
CREATE OR REPLACE FUNCTION verificar_ubicacion_disponible(id_sucursal INT, id_manga INT, cantidad INT) 
RETURNS BOOLEAN AS $$
DECLARE
    espacio_disponible INT;
BEGIN
    -- Paso 1: Obtener el espacio disponible de la ubicación física asignada al manga en la sucursal
    SELECT estanteria INTO espacio_disponible
    FROM UbicacionFisica
    WHERE idSucursal = id_sucursal 
    AND idUbicacion = (
        SELECT idUbicacion -- Obtener la ubicación física del manga
        FROM Mangas 
        WHERE idManga = id_manga 
        LIMIT 1
    );
    
    -- Paso 2: Validar si la ubicación física existe en la sucursal
    IF espacio_disponible IS NULL THEN
        RETURN FALSE; -- Retorna FALSE si no hay ubicación registrada
    END IF;

    -- Paso 3: Verificar si el espacio disponible es suficiente para la cantidad de mangas solicitada
    IF espacio_disponible >= cantidad THEN
        RETURN TRUE; -- Retorna TRUE si hay suficiente espacio
    ELSE
        RETURN FALSE; -- Retorna FALSE si no hay suficiente espacio
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Uso de la Función:
SELECT verificar_ubicacion_disponible(1, 2, 1);



-- 3. Asignar Mangas a Ubicación Física
CREATE OR REPLACE PROCEDURE asignar_manga_a_sucursal(id_sucursal INT, id_manga INT, cantidad INT)
AS $$
BEGIN
    -- Paso 1: Verificar si hay stock disponible del manga solicitado
    IF NOT verificar_stock_disponible(id_manga, cantidad) THEN
        RAISE EXCEPTION 'No hay suficiente stock disponible para asignar. ID_Manga: %, Cantidad: %', id_manga, cantidad;
    END IF;

    -- Paso 2: Verificar si hay espacio suficiente en la ubicación física de la sucursal
    IF NOT verificar_ubicacion_disponible(id_sucursal, id_manga, cantidad) THEN
        RAISE EXCEPTION 'No hay espacio suficiente en la ubicación física de la sucursal. ID_Sucursal: %, ID_Manga: %, Cantidad: %', id_sucursal, id_manga, cantidad;
    END IF;
    
    -- Paso 3: Asignar el manga a la ubicación física
    UPDATE UbicacionFisica
    SET estanteria = estanteria - cantidad
    WHERE idSucursal = id_sucursal
    AND idUbicacion = (
        SELECT idUbicacion 
        FROM Mangas 
        WHERE idManga = id_manga 
        LIMIT 1
    );
    
    -- Paso 4: Reducir el stock del manga en la tabla Mangas
    UPDATE Mangas
    SET stock = stock - cantidad
    WHERE idManga = id_manga;

    -- Paso 5: Notificar que la asignación fue exitosa
    RAISE NOTICE 'Mangas asignados correctamente a la sucursal.';
END;
$$ LANGUAGE plpgsql;

-- Uso del Procedimiento:
CALL asignar_manga_a_sucursal(1, 2, 1);



-- ---------------------------------------------------------------------------------------------------
SELECT * FROM Mangas;
SELECT * FROM Sucursales;
SELECT * FROM UbicacionFisica;


SELECT 
    m.idManga,
    m.nombreManga,
    m.stock AS stock_disponible,
    uf.idSucursal,
    uf.seccion,
    uf.pasillo,
    uf.estanteria AS espacio_disponible
FROM Mangas m
JOIN UbicacionFisica uf ON m.idUbicacion = uf.idUbicacion
WHERE m.idManga = 2 AND uf.idSucursal = 1 ;

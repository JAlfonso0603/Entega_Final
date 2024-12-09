-- ---------------------------------------------------------------------------------------------------

-- Operación creada por: Jose Antonio Gonzalez Cardenas
-- Funcionamiento: Gestionar asignación y préstamo de mangas en sucursales
-- Condiciones:
-- 1. Verificar Stock Disponible en Sucursal
-- 2. Asignar Mangas a Ubicación Física
-- 3. Verificar la Ubicación Física Disponible

-- ---------------------------------------------------------------------------------------------------

-- 1. Verificar Stock Disponible en Sucursal
CREATE OR REPLACE FUNCTION verificar_stock_sucursal(
    _idSucursal INT,
    _cantidad INT
) RETURNS BOOLEAN
AS $$
DECLARE
    _totalDisponible INT := 0;
    _idDistribuidor INT;
BEGIN
    -- Obtener el distribuidor de la sucursal
    SELECT idDistribuidor INTO _idDistribuidor
    FROM Sucursales 
    WHERE idSucursal = _idSucursal;

    -- Sumar la cantidad de mangas disponibles en los lotes asignados al distribuidor de la sucursal
    SELECT SUM(L.cantidadMangas) INTO _totalDisponible
    FROM Lotes L
    WHERE L.idImprenta IN (
        SELECT idImprenta FROM DetalleLotes DL
        WHERE DL.idDistribuidor = _idDistribuidor
    ) AND L.cantidadMangas > 0;

    -- Comprobar si el stock es suficiente
    IF _totalDisponible >= _cantidad THEN
        RAISE NOTICE 'Stock disponible suficiente: % mangas.', _totalDisponible;
        RETURN TRUE;
    ELSE
        RAISE NOTICE 'Stock insuficiente. Disponible: %, Requerido: %.', _totalDisponible, _cantidad;
        RETURN FALSE;
    END IF;
END;
$$
LANGUAGE plpgsql;




-- 2. Asignar Mangas a Ubicación Física
CREATE OR REPLACE PROCEDURE asignar_mangas_a_ubicacion(
    _idSucursal INT,
    _cantidad INT,
    _seccion VARCHAR(10),
    _pasillo VARCHAR(5),
    _estanteria INT
)
AS $$
DECLARE
    _cantidadRestante INT := _cantidad;
    _stockLote INT;
    _idLote INT;
    _idDistribuidor INT;
BEGIN
    -- Obtener el distribuidor de la sucursal
    SELECT idDistribuidor INTO _idDistribuidor
    FROM Sucursales 
    WHERE idSucursal = _idSucursal;

    -- Obtener los lotes disponibles para el distribuidor
    FOR _idLote IN
        SELECT idLote
        FROM DetalleLotes
        WHERE idDistribuidor = _idDistribuidor
    LOOP
        -- Verificar el stock disponible en el lote
        SELECT cantidadMangas INTO _stockLote
        FROM Lotes
        WHERE idLote = _idLote;

        -- Si hay mangas disponibles en el lote, asignarlas a la ubicación física
        IF _stockLote > 0 THEN
            -- Asignar mangas a la ubicación física
            INSERT INTO UbicacionFisica (idSucursal, seccion, pasillo, estanteria)
            VALUES (_idSucursal, _seccion, _pasillo, _estanteria);

            -- Reducir la cantidad de mangas en el lote
            IF _stockLote >= _cantidadRestante THEN
                UPDATE Lotes SET cantidadMangas = cantidadMangas - _cantidadRestante WHERE idLote = _idLote;
                RAISE NOTICE 'Asignados % mangas al lote %.', _cantidadRestante, _idLote;
                _cantidadRestante := 0; -- Ya no hay mangas restantes por asignar
            ELSE
                UPDATE Lotes SET cantidadMangas = 0 WHERE idLote = _idLote;
                _cantidadRestante := _cantidadRestante - _stockLote;
                RAISE NOTICE 'Asignados % mangas al lote %. Restan % mangas.', _stockLote, _idLote, _cantidadRestante;
            END IF;
        END IF;

        -- Si no quedan mangas restantes, salir del ciclo
        IF _cantidadRestante = 0 THEN
            RAISE NOTICE 'Todas las mangas han sido asignadas.';
            RETURN;
        END IF;
    END LOOP;

    -- Si al final del ciclo aún hay mangas sin asignar
    IF _cantidadRestante > 0 THEN
        RAISE NOTICE 'No se pudieron asignar todas las mangas. Restan % mangas sin asignar.', _cantidadRestante;
    END IF;
END;
$$
LANGUAGE plpgsql;


-- Llamada al procedimiento "asignar_mangas_a_ubicacion"
CALL asignar_mangas_a_ubicacion(
    _idSucursal => 1,         -- ID de la sucursal donde se asignarán los mangas
    _cantidad => 50,          -- Cantidad de mangas a asignar
    _seccion => 'A',          -- Sección de la ubicación física
    _pasillo => 'P1',         -- Pasillo de la ubicación física
    _estanteria => 3          -- Número de la estantería de la ubicación física
);




-- 3. Verificar la Ubicación Física Disponible
CREATE OR REPLACE FUNCTION verificar_ubicacion_disponible(
    _idSucursal INT,
    _seccion VARCHAR(10),
    _pasillo VARCHAR(5),
    _estanteria INT
) RETURNS BOOLEAN
AS $$
DECLARE
    _espacioDisponible INT := 100; -- Supongamos que cada estantería tiene 100 mangas disponibles por defecto
BEGIN
    -- Verificar si hay espacio suficiente en la ubicación física
    SELECT COUNT(*) INTO _espacioDisponible
    FROM UbicacionFisica
    WHERE idSucursal = _idSucursal
    AND seccion = _seccion
    AND pasillo = _pasillo
    AND estanteria = _estanteria;

    IF _espacioDisponible >= 0 THEN
        RAISE NOTICE 'Espacio disponible en la ubicación %-%-%: % mangas.', _seccion, _pasillo, _estanteria, _espacioDisponible;
        RETURN TRUE;
    ELSE
        RAISE NOTICE 'No hay suficiente espacio en la ubicación %-%-% para almacenar mangas.', _seccion, _pasillo, _estanteria;
        RETURN FALSE;
    END IF;
END;
$$
LANGUAGE plpgsql;

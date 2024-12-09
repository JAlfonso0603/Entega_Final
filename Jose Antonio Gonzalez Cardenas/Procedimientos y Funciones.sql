-- ---------------------------------------------------------------------------------------------------

-- Operación creada por: Jose Antonio Gonzalez Cardenas
-- Funcionamiento: Gestionar asignación mangas en sucursales
-- Condiciones:
-- 1. Verificar Stock Disponible en Sucursal
-- 2. Verificar la Ubicación Física Disponible
-- 3. Asignar Mangas a Ubicación Física

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
    SELECT SUM(cantidadMangas) INTO _totalDisponible
    FROM Lotes
    WHERE idImprenta IN (
        SELECT idImprenta 
        FROM DetalleLotes 
        WHERE idDistribuidor = _idDistribuidor
    ) AND cantidadMangas > 0;
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

-- Uso de la Función:
SELECT verificar_stock_sucursal(1, 50);




-- 2. Verificar la Ubicación Física Disponible
CREATE OR REPLACE FUNCTION verificar_ubicacion_disponible(
    _idSucursal INT,
    _seccion VARCHAR(10),
    _pasillo VARCHAR(5),
    _estanteria INT,
    _cantidad INT
) RETURNS BOOLEAN
AS $$
DECLARE
    _capacidadDisponible INT := 100;  -- Capacidad total por defecto de la ubicación
    _mangasAlmacenadas INT := 0;
    _espacioDisponible INT;
BEGIN
    -- Verificar cuántas mangas están almacenadas en la ubicación física
    SELECT COALESCE(SUM(Lotes.cantidadMangas), 0) INTO _mangasAlmacenadas
    FROM Lotes
    JOIN DetalleLotes ON DetalleLotes.idLote = Lotes.idLote
    WHERE DetalleLotes.idDistribuidor IN (
        SELECT idDistribuidor
        FROM Sucursales
        WHERE idSucursal = _idSucursal
    )
    AND EXISTS (SELECT 1 FROM UbicacionFisica WHERE idSucursal = _idSucursal 
		AND seccion = _seccion
        AND pasillo = _pasillo
        AND estanteria = _estanteria
    );
    -- Calcular el espacio disponible en la ubicación
    _espacioDisponible := _capacidadDisponible - _mangasAlmacenadas;
    -- Verificar si hay suficiente espacio en la ubicación física
    IF _espacioDisponible >= _cantidad THEN
        RAISE NOTICE 'Espacio disponible en la ubicación %-%-%: % mangas.', _seccion, _pasillo, _estanteria, _espacioDisponible;
        RETURN TRUE;
    ELSE
        RAISE NOTICE 'No hay suficiente espacio en la ubicación %-%-% para almacenar % mangas. Espacio disponible: %.', _seccion, _pasillo, _estanteria, _cantidad, _espacioDisponible;
        RETURN FALSE;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Uso de la Función:
SELECT verificar_ubicacion_disponible(1, 'A', '1', 3, 50);




-- 3. Asignar Mangas a Ubicación Física
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

-- Uso del Procedimiento:
CALL asignar_mangas_a_ubicacion(
    _idSucursal => 1,         -- ID de la sucursal donde se asignarán los mangas
    _cantidad => 50,          -- Cantidad de mangas a asignar
    _seccion => 'A',          -- Sección de la ubicación física
    _pasillo => '1',         -- Pasillo de la ubicación física
    _estanteria => 3          -- Número de la estantería de la ubicación física
);


-- ---------------------------------------------------------------------------------------------------
SELECT * FROM Lotes;
SELECT * FROM DetalleLotes;
SELECT * FROM Distribuidores;
SELECT * FROM Sucursales;
SELECT * FROM UbicacionFisica;

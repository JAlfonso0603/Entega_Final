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
    _idSucursal INT,  -- ID de la sucursal
    _cantidad INT     -- Cantidad de mangas que se quiere verificar
) RETURNS BOOLEAN
AS $$
DECLARE
    _totalDisponible INT := 0;  -- Variable para almacenar el total de mangas disponibles
    _idDistribuidor INT;        -- Variable para almacenar el ID del distribuidor
BEGIN
    -- Paso 1: Obtener el distribuidor asociado a la sucursal
    SELECT idDistribuidor INTO _idDistribuidor
    FROM Sucursales 
    WHERE idSucursal = _idSucursal;
	
    -- Paso 2: Sumar la cantidad total de mangas disponibles en los lotes del distribuidor
    SELECT SUM(cantidadMangas) INTO _totalDisponible
    FROM Lotes
    WHERE idImprenta IN (
        -- Subconsulta para obtener los lotes asignados al distribuidor
        SELECT idImprenta 
        FROM DetalleLotes 
        WHERE idDistribuidor = _idDistribuidor
    ) AND cantidadMangas > 0;  -- Asegurarse de contar solo los lotes con mangas disponibles

    -- Paso 3: Verificar si hay suficiente stock disponible para la cantidad solicitada
    IF _totalDisponible >= _cantidad THEN
        RAISE NOTICE 'Stock disponible suficiente: % mangas.', _totalDisponible;
        RETURN TRUE;  -- Stock suficiente, se puede proceder con la asignación
    ELSE
        RAISE NOTICE 'Stock insuficiente. Disponible: %, Requerido: %.', _totalDisponible, _cantidad;
        RETURN FALSE;  -- No hay suficiente stock
    END IF;
END;
$$
LANGUAGE plpgsql;


-- Uso de la Función:
SELECT verificar_stock_sucursal(1, 3500);




-- 2. Verificar la Ubicación Física Disponible
CREATE OR REPLACE FUNCTION verificar_ubicacion_disponible(
    _idSucursal INT,        -- ID de la sucursal donde se verifica la ubicación
    _seccion VARCHAR(10),   -- Sección de la ubicación
    _pasillo VARCHAR(5),    -- Pasillo de la ubicación
    _estanteria INT,        -- Estantería de la ubicación
    _cantidad INT           -- Cantidad de mangas que se quieren almacenar
) RETURNS BOOLEAN
AS $$
DECLARE
    _capacidadDisponible INT := 700;  -- Capacidad total por defecto de la ubicación (100 mangas)
    _mangasAlmacenadas INT := 0;      -- Variable para almacenar la cantidad de mangas ya almacenadas
    _espacioDisponible INT;           -- Variable para calcular el espacio disponible en la ubicación
BEGIN

    -- Paso 1: Verificar cuántas mangas están almacenadas en la ubicación física
    SELECT COALESCE(SUM(Lotes.cantidadMangas), 0) INTO _mangasAlmacenadas
    FROM Lotes
    JOIN DetalleLotes ON DetalleLotes.idLote = Lotes.idLote
    WHERE DetalleLotes.idDistribuidor IN (
        -- Subconsulta para obtener los lotes asociados a la sucursal
        SELECT idDistribuidor
        FROM Sucursales
        WHERE idSucursal = _idSucursal
    )
    AND EXISTS (
        -- Verificar si la ubicación especificada existe
        SELECT 1 FROM UbicacionFisica 
        WHERE idSucursal = _idSucursal 
        AND seccion = _seccion
        AND pasillo = _pasillo
        AND estanteria = _estanteria
    );
    
    -- Paso 2: Calcular el espacio disponible en la ubicación
    _espacioDisponible := _capacidadDisponible - _mangasAlmacenadas;

    -- Paso 3: Verificar si hay suficiente espacio en la ubicación física
    IF _espacioDisponible >= _cantidad THEN
        -- Si hay suficiente espacio
        RAISE NOTICE 'Espacio disponible en la ubicación %-%-%: % mangas.', _seccion, _pasillo, _estanteria, _espacioDisponible;
        RETURN TRUE;  -- Hay suficiente espacio para almacenar las mangas
    ELSE
        -- Si no hay suficiente espacio
        RAISE NOTICE 'No hay suficiente espacio en la ubicación %-%-% para almacenar % mangas. Espacio disponible: %.', 
            _seccion, _pasillo, _estanteria, _cantidad, _espacioDisponible;
        RETURN FALSE;  -- No hay suficiente espacio
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
    _cantidadRestante INT := _cantidad;  -- Inicializamos la cantidad restante a asignar
    _stockLote INT;  -- Variable para almacenar el stock disponible en el lote
    _idLote INT;  -- Variable para almacenar el ID del lote
    _idDistribuidor INT;  -- Variable para almacenar el ID del distribuidor
BEGIN

    -- Paso 1: Obtener el distribuidor asociado a la sucursal
    SELECT idDistribuidor INTO _idDistribuidor
    FROM Sucursales 
    WHERE idSucursal = _idSucursal;
	
    -- Paso 2: Obtener los lotes disponibles para el distribuidor de la sucursal
    FOR _idLote IN
        SELECT idLote
        FROM DetalleLotes
        WHERE idDistribuidor = _idDistribuidor
    LOOP
	
        -- Paso 3: Verificar el stock disponible en cada lote
        SELECT cantidadMangas INTO _stockLote
        FROM Lotes
        WHERE idLote = _idLote;
		
        -- Paso 4: Si hay mangas disponibles en el lote, proceder a asignarlas a la ubicación física
        IF _stockLote > 0 THEN
            -- Asignar mangas a la ubicación física
            INSERT INTO UbicacionFisica (idSucursal, seccion, pasillo, estanteria)
            VALUES (_idSucursal, _seccion, _pasillo, _estanteria);
			
            -- Paso 5: Si el lote tiene suficiente stock, asignar la cantidad restante
            IF _stockLote >= _cantidadRestante THEN
                -- Si el stock en el lote es suficiente para satisfacer la cantidad restante, restar esa cantidad
                UPDATE Lotes 
                SET cantidadMangas = _stockLote - _cantidadRestante
                WHERE idLote = _idLote;
                -- Notificar cuántas mangas se han asignado
                RAISE NOTICE 'Asignados % mangas al lote %.', _cantidadRestante, _idLote;
                -- Ya no hay mangas restantes por asignar
                _cantidadRestante := 0; 
            ELSE
                -- Si no hay suficiente stock en el lote, asignar todo lo que haya en el lote
                UPDATE Lotes 
                SET cantidadMangas = 0  -- El lote queda vacío
                WHERE idLote = _idLote;
                -- Restar la cantidad que se ha asignado del total de mangas restantes
                _cantidadRestante := _cantidadRestante - _stockLote;
                -- Notificar cuántas mangas se han asignado y cuántas quedan por asignar
                RAISE NOTICE 'Asignados % mangas al lote %. Restan % mangas.', _stockLote, _idLote, _cantidadRestante;
            END IF;
        END IF;

        -- Paso 6: Si no quedan mangas restantes por asignar, salir del ciclo
        IF _cantidadRestante = 0 THEN
            RAISE NOTICE 'Todas las mangas han sido asignadas.';
            RETURN;  -- Sale del ciclo si ya no quedan mangas para asignar
        END IF;
    END LOOP;

    -- Paso 7: Si al final del ciclo aún hay mangas sin asignar, notificar el restante
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

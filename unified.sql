----------------------------------------------------------------------------------------------------------
-- Procedimiento de: Emmanuel Saldaña Álvarez
----------------------------------------------------------------------------------------------------------

CREATE OR REPLACE PROCEDURE obtener_autores_top_mangas()
AS $$
DECLARE
    _resultado RECORD;
    _existen BOOLEAN;
BEGIN
    -- Verificar si existen registros en las tablas involucradas
    SELECT EXISTS (
        SELECT 1
        FROM DetallePrestamos DP
        INNER JOIN Mangas M ON DP.idManga = M.idManga
        INNER JOIN Autores A ON M.idAutor = A.idAutor
    ) INTO _existen;

    IF NOT _existen THEN
        RAISE NOTICE 'No existen registros de autores o mangas relacionados con préstamos.';
        RETURN;
    END IF;

    -- Consulta para obtener los IDs de autores de los mangas más prestados
    FOR _resultado IN 
        SELECT 
            A.idAutor, 
            M.nombreManga, 
            SUM(DP.cantidad) AS totalPrestados
        FROM DetallePrestamos DP
        INNER JOIN Mangas M ON DP.idManga = M.idManga
        INNER JOIN Autores A ON M.idAutor = A.idAutor
        GROUP BY A.idAutor, M.nombreManga
        ORDER BY totalPrestados DESC
        LIMIT 3
    LOOP
        -- Mostrar los resultados
        RAISE NOTICE 'ID Autor: %, Manga: %, Total Prestados: %', 
            _resultado.idAutor, _resultado.nombreManga, _resultado.totalPrestados;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

CALL obtener_autores_top_mangas();

----------------------------------------------------------------------------------------------------------
-- Fin del procedimiento
----------------------------------------------------------------------------------------------------------

----------------------------------------------------------------------------------------------------------
-- Procedimiento de: Jose Antonio Gonzalez Cardenas
----------------------------------------------------------------------------------------------------------

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

----------------------------------------------------------------------------------------------------------
-- Fin del procedimiento
----------------------------------------------------------------------------------------------------------

----------------------------------------------------------------------------------------------------------
-- Procedimiento de: Jesús Alfonso Cuevas Ávila
----------------------------------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION check_user(
	_idUsuario INTEGER
) RETURNS BOOLEAN
AS $$
DECLARE
	_grupo CHARACTER VARYING(30);	
BEGIN
-- Comprobación de existencia de usuario.
	IF EXISTS(SELECT 1 FROM Usuarios WHERE idUsuario = _idUsuario) THEN
		SELECT 
			G.nombreGrupo
		FROM Usuarios U INNER JOIN Grupos G ON U.idGrupo = G.idGrupo
		WHERE U.idUsuario = _idUsuario
		INTO _grupo;

	 -- Confirmación de pertenencia a grupo 'Clientes'.
		IF (_grupo = 'Clientes') THEN
			RAISE NOTICE '<< User >> Check successful for user %.', _idUsuario;
			RETURN TRUE;
		ELSE
			RAISE NOTICE 'El usuario % no está registrado como cliente.', _idUsuario;
			RETURN FALSE;
		END IF;
		
	ELSE
		RAISE NOTICE 'El usuario % no existe.', _idUsuario;
		RETURN FALSE;
	END IF;
	
END;
$$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION check_history (
	_idUsuario INTEGER
) RETURNS BOOLEAN
AS $$
DECLARE
BEGIN
	IF EXISTS(
		SELECT 1
		FROM Usuarios U INNER JOIN Prestamos P ON U.idUsuario = P.idUsuario
		WHERE U.idUsuario = _idUsuario AND P.estadoPre = 'Atrasado'
	) THEN
		RAISE NOTICE 'Préstamo rechazado: El usuario % tiene préstamos atrasados.', _idUsuario;
		RETURN TRUE;
	ELSE
		RAISE NOTICE '<< History >> Check successful for user %.', _idUsuario;
		RETURN FALSE;
	END IF;
END;
$$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION check_pending (
	_idUsuario INTEGER
) RETURNS BOOLEAN
AS $$
DECLARE
	_authorized BOOLEAN;
	_pending INTEGER;
BEGIN
	SELECT 
		COUNT(*)
	FROM Prestamos P INNER JOIN Usuarios U ON P.idUsuario = U.idUsuario
	WHERE P.idUsuario = _idUsuario AND P.estadoPre = 'Pendiente'
	INTO _pending;

	IF (_pending < 5) THEN
		RAISE NOTICE '<< Pending >> Check Successful for user: %.', _idUsuario;
		RETURN TRUE;
	ELSE
		RAISE NOTICE 'Lo sentimos, no se pueden tener más de 5 préstamos pendientes simultáneos.';
		RAISE NOTICE 'Por favor, espera a la fecha de término o anticipa tu devolución.';
		RETURN FALSE;
	END IF;
END;
$$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION check_available (
	_nombreManga CHARACTER VARYING(50),
	_cantidad INTEGER
) RETURNS BOOLEAN
AS $$
DECLARE
	_stock INTEGER;	
BEGIN
 -- Comprobar existencia relativa del manga
	IF EXISTS (SELECT 1 FROM Mangas M WHERE nombreManga ~~* _nombreManga) THEN

	 -- Comrpobar existencia real del manga
		IF(SELECT habilitado FROM Mangas WHERE nombreManga ~~* _nombreManga) THEN
			 -- Comprobación de Stock
				SELECT stock FROM Mangas WHERE nombreManga ~~* _nombreManga INTO _stock;

				IF(_stock >= _cantidad) THEN
					RAISE NOTICE '<< Available >> Check successful for manga: %.', _nombreManga;
					RETURN TRUE;
				ELSE
					RAISE NOTICE 'Lo sentimos, stock insuficiente.';
					RAISE NOTICE 'Stock disponible: %', _stock;
					RETURN FALSE;
				END IF;
		ELSE
			RAISE NOTICE 'El manga especificado no está disponible, ¡Pero volverá pronto!';
			RETURN FALSE;
		END IF;
	ELSE
		RAISE NOTICE 'Lo sentimos: No existe el manga especificado, o el nombre no es correcto.';
		RETURN FALSE;
	END IF;
END;
$$
LANGUAGE plpgsql;

CREATE OR REPLACE PROCEDURE update_stock (
	_idManga INTEGER,
	_cantidad INTEGER
) 
AS $$
DECLARE
	_currentStock INTEGER;
BEGIN
	UPDATE Mangas SET stock = stock - _cantidad WHERE idManga = _idManga;
	UPDATE Mangas SET disponible = disponible - _cantidad WHERE idManga = _idManga;
	SELECT stock FROM Mangas WHERE idManga = _idManga INTO _currentStock;
	IF (_currentStock = 0) THEN
		UPDATE Mangas SET habilitado = 'FALSE' WHERE idManga = _idManga;
	END IF;
END;
$$
LANGUAGE plpgsql;

CREATE OR REPLACE PROCEDURE realizar_prestamo (
	_idUsuario INTEGER,
	_idSucursal INTEGER,
	_nombreManga CHARACTER VARYING (50), 
	_cantidad INTEGER
)
AS $$
DECLARE
	_idManga INTEGER;
	_idPrestamo INTEGER;
	_fechaPrestamo DATE;
	_fechaEstDev DATE;
BEGIN
 -- Comprobación de datos de usuario
	IF(check_user(_idUsuario) = 'TRUE') THEN
		-- Comprobación de préstamos atrasados
		IF(check_history(_idUsuario) != 'TRUE') THEN
			-- Comprobación de préstamos activos.
			IF(check_pending(_idUsuario) = 'TRUE') THEN
				-- Comprobación de disponibilidad del manga
				IF(check_available(_nombreManga, _cantidad) = 'TRUE') THEN
				 -- Proceder con la operación de préstamo.
				 
				 	SELECT idManga FROM Mangas WHERE nombreManga ~~* _nombreManga INTO _idManga;
					SELECT CURRENT_DATE INTO _fechaPrestamo;
					SELECT CURRENT_DATE + interval '30 days' INTO _fechaEstDev;
					
					INSERT INTO Prestamos (idSucursal, idUsuario, totalMangas, fechaPres, fechaDevSR, fechaDev, estadoPre) 
					VALUES(
						_idSucursal, 
						_idUsuario, 
						_cantidad, 
						_fechaPrestamo, 
						_fechaEstDev, 
						NULL, 
						'Pendiente'
					);
					
					SELECT COALESCE(MAX(idPrestamo), 0) FROM Prestamos INTO _idPrestamo;
					
					INSERT INTO DetallePrestamos (idPrestamo, idManga, cantidad) 
					VALUES(
						_idPrestamo, 
						_idManga, 
						_cantidad
					);

					CALL update_stock(_idManga, _cantidad);

				END IF;
			END IF;
		END IF;
	END IF;
END;
$$
LANGUAGE plpgsql;

-- Ejemplo

CALL realizar_prestamo(7, 1, 'manga b', 6);

----------------------------------------------------------------------------------------------------------
-- Fin del procedimiento
----------------------------------------------------------------------------------------------------------

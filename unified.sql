---------------------------------------------------------------------------------------------------------
-- Procedimiento de: Jesús Alfonso Cuevas Ávila
---------------------------------------------------------------------------------------------------------

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
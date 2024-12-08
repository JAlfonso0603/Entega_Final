-- Procedimiento creado por: Jesús Alfonso Cuevas Ávila
-- Funcionamiento: Realizar un préstamo a nombre de un usuario ya existente que no cuente con adeudos.

-- Cuerpo del procedimiento:

SELECT * FROM Usuarios


CREATE OR REPLACE FUNCTION info_usuario(
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
			RAISE NOTICE 'El usuario % existe.', _idUsuario;
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

CREATE OR REPLACE FUNCTION history_flags (
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
		RETURN TRUE;
	ELSE
		RETURN FALSE;
	END IF;
END;
$$
LANGUAGE plpgsql;

CREATE OR REPLACE PROCEDURE realizar_prestamo (
	_idUsuario INTEGER,
	_nombreManga CHARACTER VARYING (50), 
	_cantidad INTEGER,
	_stock INTEGER,
)
AS $$
DECLARE
BEGIN
	
	IF(info_usuario(_idUsuario) = 'TRUE') THEN
			 -- Comprobación de préstamos atrasados
				IF(history_flags(_idUsuario) != 'TRUE') THEN
				 -- Comprobar existencia relativa de manga
					IF EXISTS (
						SELECT 1
						FROM Mangas M
						WHERE nombreManga ~~* _nombreManga
					) THEN

						-- Comrpobar existencia real del manga
						IF(SELECT habilitado FROM Mangas WHERE nombreManga = _nombreManga) THEN
						 -- Comprobación de Stock
							SELECT stock FROM Mangas WHERE nombreManga = _nombreManga INTO _stock;
						ELSE
							RAISE NOTICE 'El manga especificado no está disponible: ¡Pero volverá pronto!';
						END IF;
					ELSE
						RAISE NOTICE 'No existe el manga especificado, o el nombre no es correcto.';
					END IF;
				ELSE
					RAISE NOTICE 'Préstamo rechazado: El usuario % tiene préstamos pendientes', _idUsuario;
				END IF;
	END IF;
END;
$$
LANGUAGE plpgsql;
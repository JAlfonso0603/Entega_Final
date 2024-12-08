-- Procedimiento creado por: Jesús Alfonso Cuevas Ávila
-- Funcionamiento: Realizar un préstamo a nombre de un usuario ya existente que no cuente con adeudos.

-- Cuerpo del procedimiento:

SELECT * FROM Usuarios

CREATE OR REPLACE PROCEDURE realizar_prestamo (
	_idUsuario INTEGER, 
	_nombreManga CHARACTER VARYING (50), 
	_cantidad INTEGER,
	_stock INTEGER
)
AS $$
DECLARE
	_grupo CHARACTER VARYING(30);
	_adeudos BOOLEAN;
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
			 -- Comprobación de préstamos atrasados
				SELECT 1
				FROM Usuarios U INNER JOIN Prestamos P ON U.idUsuario = P.idUsuario
				WHERE U.idUsuario = _idUsuario AND P.estadoPre = 'Atrasado'
				INTO _adeudos;

				IF(_adeudos != 0) THEN
				 -- Comprobar existencia relativa de manga
					IF EXISTS (
						SELECT 1
						FROM Mangas M
						WHERE nombreManga ~~* _nombreManga
					) THEN

						-- Comrpobar existencia real del manga
						IF(SELECT habilitado FROM Mangas WHERE nombreManga = _nombreManga) THEN
						 -- Comprobación de Stock
							SELECT stock FROM Mangas WHERE nombreManga = _nombreManga INTO _stock)
							
							
						ELSE
							RAISE NOTICE 'El manga especificado no está disponible: ¡Pero volverá pronto!'
						END IF;
					ELSE
						RAISE NOTICE 'No existe el manga especificado, o el nombre no es correcto.'
					END IF;
				ELSE
					RAISE NOTICE 'Préstamo rechazado: El usuario % tiene préstamos pendientes', _idUsuario;
				END IF;
		ELSE
			RAISE NOTICE 'El usuario % no está registrado como cliente.', _idUsuario;
		END IF;
	ELSE
		RAISE NOTICE 'El usuario % no existe.', _idUsuario;
	END IF;
END;
$$
LANGUAGE plpgsql;
-- Procedimiento creado por: Jesús Alfonso Cuevas Ávila
-- Funcionamiento: Realizar un préstamo a nombre de un usuario ya existente que no cuente con adeudos.

-- Cuerpo del procedimiento:

SELECT * FROM Usuarios

CREATE OR REPLACE PROCEDURE realizar_prestamo (
	_idUsuario INTEGER, 
	_idManga INTEGER, 
	_cantidad INTEGER
)
AS $$
DECLARE
	_grupo CHARACTER VARYING(30);
	_adeudos BOOLEAN;
BEGIN
	IF EXISTS(SELECT 1 FROM Usuarios WHERE idUsuario = _idUsuario) THEN
		SELECT 
			G.nombreGrupo
		FROM Usuarios U INNER JOIN Grupos G ON U.idGrupo = G.idGrupo
		WHERE U.idUsuario = _idUsuario
		INTO _grupo;
		
		IF (_grupo = 'Clientes') THEN
				SELECT 1
				FROM Usuarios U INNER JOIN Prestamos P ON U.idUsuario = P.idUsuario
				WHERE U.idUsuario = _idUsuario AND P.estadoPre = 'Atrasado'
				INTO _adeudos;

				IF(_adeudos != 0) THEN

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

-- Operación creada por: Emmanuel Saldaña Álvarez
-- Funcionamiento: Mostrar los 3 autores con los mangas mas prestados
-- Condicion:
-- 1. Verificar si existen registros en las tablas

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
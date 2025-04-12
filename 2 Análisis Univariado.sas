/* --------------------------------------------------------------------------------------------------------------------------------- */
/* C8 PARTE 1 */

/* EL ANALISIS UNIVARIADO SE DIVIDIRA PARA VARIABLES CUANTITATIVAS Y CUALITATIVAS
/* VARIABLES CUANTITATIVAS: PARTIREMOS DE LOS RANGOS GENERADOS CON EL PROC UNIVARIATE. BUSCAREMOS COMBINAR RANGO ADYACENTES DE TAL MANERA QUE EL PORCENTAJE DE MALOS SEA MONOTONO CRECIENTE O MONOTONO DECRECIENTE. */
/* VARIABLES CUALITATIVAS: 	BUSCAREMOS COMBINAR CATEGORIAS ADYACENTES DE TAL MANERA QUE EL PORCENTAJE DE MALOS SEA MONOTONO CRECIENTE O MONOTONO DECRECIENTE.*/
/* NOTA: CADA CATEGORIA DEBE TENER AL MENOS UN 5% DEL TOTAL DE OBSERVACIONES, DE LO CONTRARIO COMBINAR CON UNA CATEGORIA ADYACENTE. */

/**************************************** ANALISIS UNIVARIADO PARA VARIABLES CUANTITATIVAS /****************************************/

/**************************************** VARIABLE MONTO SOLICITADO ****************************************/

/* TABLA AUXILIAR PARA SUSTITUIR POSIBLES VALORES NA */
PROC SQL;											
CREATE TABLE WORK.TEMPORAL AS
SELECT 		S.CLIENTE,
			MONTO_SOLICITADO as MONTO_SOLICITADO_ORIGINAL,
			CASE 
				WHEN	MONTO_SOLICITADO IS NULL THEN .
				ELSE 	MONTO_SOLICITADO
			END AS MONTO_SOLICITADO,
			F.BAD
FROM		ORIGINA.SOLICITUD 		AS S
INNER JOIN	ORIGINA.FLAG_G_B 		AS F ON F.CLIENTE=S.CLIENTE
INNER JOIN  ORIGINA.DEMOGRAFICOS 	AS D ON D.CLIENTE=S.CLIENTE
INNER JOIN  ORIGINA.BURO 			AS B ON B.CLIENTE=S.CLIENTE;
QUIT;

/* GENERAR RANGOS CON AL MENOS EL 5% DE POBLACION EN ELLOS */
PROC UNIVARIATE DATA=WORK.TEMPORAL NOPRINT;			
VAR MONTO_SOLICITADO;
OUTPUT OUT=WORK.RANGOS PCTLPRE=P_ PCTLPTS=0 TO 100 BY 5;		
RUN;

/* CREAR RANGOS DEFINIDOS POR PROC UNIVARIATE */
PROC SQL;											
CREATE TABLE WORK.UNIV_MONTO_SOLICITADO AS 
SELECT 	RANGO_MONTO_SOLICITADO,
		COUNT(CLIENTE) AS CLIENTES,
		SUM(BAD) AS BADS,
		AVG(BAD) AS PORCENTAJE_BADS
FROM
(   	
	SELECT 	CLIENTE,
			BAD,
			MONTO_SOLICITADO,
			CASE 
			WHEN MONTO_SOLICITADO >= 1500  AND MONTO_SOLICITADO < 3000  THEN '00 1500 - 3000'
			WHEN MONTO_SOLICITADO >= 3000  AND MONTO_SOLICITADO < 5000  THEN '01 3000 - 5000'
			WHEN MONTO_SOLICITADO >= 5000  AND MONTO_SOLICITADO < 6000  THEN '02 5000 - 6000'
			WHEN MONTO_SOLICITADO >= 6000  AND MONTO_SOLICITADO < 7000  THEN '03 6000 - 7000'
			WHEN MONTO_SOLICITADO >= 7000  AND MONTO_SOLICITADO < 8000  THEN '04 7000 - 8000'
			WHEN MONTO_SOLICITADO >= 8000  AND MONTO_SOLICITADO < 9000  THEN '05 8000 - 9000'
			WHEN MONTO_SOLICITADO >= 9000  AND MONTO_SOLICITADO < 10000 THEN '06 9000 - 10000'
			WHEN MONTO_SOLICITADO >= 10000 AND MONTO_SOLICITADO < 15000 THEN '07 10000 - 15000'
			WHEN MONTO_SOLICITADO >= 15000 AND MONTO_SOLICITADO < 20000 THEN '08 15000 - 20000'
			WHEN MONTO_SOLICITADO >= 20000 								THEN '09 20000 - MAS'
			END AS RANGO_MONTO_SOLICITADO
		FROM	WORK.TEMPORAL
) AS Z	
GROUP BY 1
ORDER BY 1
;QUIT;

/* RANGOS NUEVOS A PARTIR DEL ANALISIS UNIVARIADO */
PROC SQL;											
CREATE TABLE ORIGINA.UNIV_MONTO_SOLICITADO AS 
SELECT 	RANGO_MONTO_SOLICITADO,
		COUNT(CLIENTE) AS CLIENTES,
		SUM(BAD) AS BADS,
		AVG(BAD) AS PORCENTAJE_BADS
FROM
(   	
	SELECT 	CLIENTE,
			BAD,
			MONTO_SOLICITADO,
			CASE 
			WHEN MONTO_SOLICITADO >= 1500  AND MONTO_SOLICITADO < 3000  THEN '00 1500 - 3000'
			WHEN MONTO_SOLICITADO >= 3000  AND MONTO_SOLICITADO < 5000  THEN '01 3000 - 5000'			
			WHEN MONTO_SOLICITADO >= 5000  AND MONTO_SOLICITADO < 8000  THEN '02 5000 - 8000'
			WHEN MONTO_SOLICITADO >= 8000     							THEN '03 8000 - MAS'
			END AS RANGO_MONTO_SOLICITADO
		FROM	WORK.TEMPORAL
) AS Z	
GROUP BY 1
ORDER BY 1
;QUIT;


/* INSUMO REGRESION */
/* EL SIGUIENTE PASO ES MAPEAR LAS VARIABLES ORIGINALES PARA QUE SIRVAN COMO INSUMO DE LA REGRESION LOGISTICA.
SE SUSTITUIRAN LOS VALORES DE LAS VARIABLES ORIGINALES POR SU CORRESPONDIENTE PORCENTAJE DE BADS DE ACUERDO A LOS RANGOS RECIEN CALCULADOS, 
POR LO QUE TENDREMOS UN MODELO CUYOS REGRESORES SON PORCENTAJES (VALORES ENTRE 0 y 1), ES DECIR, SE MAPEARAN LAS VARIABLES CUANTITATIVAS 
Y CUALITATIVAS HACIA UN NUEVO ESPACIO [0-1] */

/* CREAR LA VARIABLE INSUMO PARA LA REGRESION */
PROC SQL;											
CREATE TABLE ORIGINA.R_MONTO_SOLICITADO AS 
SELECT 	CLIENTE,
		PORCENTAJE_BADS AS R_MONTO_SOLICITADO
FROM
(   	
	SELECT 	CLIENTE,
			BAD,
			MONTO_SOLICITADO,
			CASE 
			WHEN MONTO_SOLICITADO >= 1500  AND MONTO_SOLICITADO < 3000  THEN '00 1500 - 3000'
			WHEN MONTO_SOLICITADO >= 3000  AND MONTO_SOLICITADO < 5000  THEN '01 3000 - 5000'			
			WHEN MONTO_SOLICITADO >= 5000  AND MONTO_SOLICITADO < 8000  THEN '02 5000 - 8000'
			WHEN MONTO_SOLICITADO >= 8000     							THEN '03 8000 - MAS'
			END AS RANGO_MONTO_SOLICITADO
		FROM	WORK.TEMPORAL
) AS Z
LEFT JOIN ORIGINA.UNIV_MONTO_SOLICITADO AS U
ON Z.RANGO_MONTO_SOLICITADO=U.RANGO_MONTO_SOLICITADO
;QUIT;


/**************************************** VARIABLE EDAD ****************************************/

/* TABLA AUXILIAR PARA SUSTITUIR POSIBLES VALORES NA */
PROC SQL;
CREATE TABLE WORK.TEMPORAL AS
SELECT 		S.CLIENTE,
			INTCK('YEAR',FECHA_NACIMIENTO,S.FECHA_SOLICITUD) AS EDAD_ORIGINAL,
			CASE 
				WHEN	INTCK('YEAR',FECHA_NACIMIENTO,S.FECHA_SOLICITUD) 	 IS NULL 	   THEN .
				ELSE 	INTCK('YEAR',FECHA_NACIMIENTO,S.FECHA_SOLICITUD)
			END AS EDAD,
			BAD
FROM		ORIGINA.SOLICITUD 		AS S
INNER JOIN	ORIGINA.FLAG_G_B 		AS F ON F.CLIENTE=S.CLIENTE
INNER JOIN  ORIGINA.DEMOGRAFICOS 	AS D ON D.CLIENTE=S.CLIENTE
INNER JOIN  ORIGINA.BURO 			AS B ON B.CLIENTE=S.CLIENTE;
QUIT;

/* GENERAR RANGOS CON AL MENOS EL 5% DE POBLACION EN ELLOS */
PROC UNIVARIATE DATA=WORK.TEMPORAL NOPRINT;			
VAR EDAD;
OUTPUT OUT=WORK.RANGOS PCTLPRE=P_ PCTLPTS=0 TO 100 BY 5;		
RUN;

/* CREAR RANGOS DEFINIDOS POR PROC UNIVARIATE */
PROC SQL;											
CREATE TABLE WORK.UNIV_EDAD AS 
SELECT 	RANGO_EDAD,
		COUNT(CLIENTE) AS CLIENTES,
		SUM(BAD) AS BADS,
		AVG(BAD) AS PORCENTAJE_BADS
FROM
(   	
	SELECT 	CLIENTE,
			BAD,
			EDAD,
			CASE 
				WHEN EDAD >= 18 AND EDAD < 21 THEN '00 18 - 21'
				WHEN EDAD >= 21 AND EDAD < 23 THEN '01 21 - 23'
				WHEN EDAD >= 23 AND EDAD < 25 THEN '02 23 - 25'
				WHEN EDAD >= 25 AND EDAD < 26 THEN '03 25 - 26'
				WHEN EDAD >= 26 AND EDAD < 28 THEN '04 26 - 28'
				WHEN EDAD >= 28 AND EDAD < 30 THEN '05 28 - 30'
				WHEN EDAD >= 30 AND EDAD < 31 THEN '06 30 - 31'
				WHEN EDAD >= 31 AND EDAD < 33 THEN '07 31 - 33'
				WHEN EDAD >= 33 AND EDAD < 35 THEN '08 33 - 35'
				WHEN EDAD >= 35 AND EDAD < 37 THEN '09 35 - 37'
				WHEN EDAD >= 37 AND EDAD < 39 THEN '10 37 - 39'
				WHEN EDAD >= 39 AND EDAD < 41 THEN '11 39 - 41'
				WHEN EDAD >= 41 AND EDAD < 42 THEN '12 41 - 42'
				WHEN EDAD >= 42 AND EDAD < 45 THEN '13 42 - 45'
				WHEN EDAD >= 45 AND EDAD < 47 THEN '14 45 - 47'
				WHEN EDAD >= 47 AND EDAD < 49 THEN '15 47 - 49'
				WHEN EDAD >= 49 AND EDAD < 52 THEN '16 49 - 52'
				WHEN EDAD >= 52 AND EDAD < 55 THEN '17 52 - 55'
				WHEN EDAD >= 55 AND EDAD < 60 THEN '18 55 - 60'
				WHEN EDAD >= 60 AND EDAD < 71 THEN '19 60 - 71'
				WHEN EDAD >= 71 THEN '20 71 - MAS'
			END AS RANGO_EDAD
		FROM	WORK.TEMPORAL
) AS Z	
GROUP BY 1
ORDER BY 1
;QUIT;

/* RANGOS NUEVOS A PARTIR DEL ANALISIS UNIVARIADO */
PROC SQL;											
CREATE TABLE ORIGINA.UNIV_EDAD AS 
SELECT 	RANGO_EDAD,
		COUNT(CLIENTE) AS CLIENTES,
		SUM(BAD) AS BADS,
		AVG(BAD) AS PORCENTAJE_BADS
FROM
(   	
	SELECT 	CLIENTE,
			BAD,
			EDAD,
			CASE 
			WHEN EDAD >= 18  AND EDAD < 23  THEN '00 18 - 23'
			WHEN EDAD >= 23  AND EDAD < 39  THEN '01 23 - 39'			
			WHEN EDAD >= 39  AND EDAD < 49  THEN '02 39 - 49'
			WHEN EDAD >= 49     			THEN '03 49 - MAS'
			END AS RANGO_EDAD
		FROM	WORK.TEMPORAL
) AS Z	
GROUP BY 1
ORDER BY 1
;QUIT;

/* CREAR LA VARIABLE INSUMO PARA LA REGRESION */
PROC SQL;											
CREATE TABLE ORIGINA.R_EDAD AS 
SELECT 	CLIENTE,
		PORCENTAJE_BADS AS R_EDAD
FROM
(   	
	SELECT 	CLIENTE,
			BAD,
			EDAD,
			CASE 
			WHEN EDAD >= 18  AND EDAD < 23  THEN '00 18 - 23'
			WHEN EDAD >= 23  AND EDAD < 39  THEN '01 23 - 39'			
			WHEN EDAD >= 39  AND EDAD < 49  THEN '02 39 - 49'
			WHEN EDAD >= 49     			THEN '03 49 - MAS'
			END AS RANGO_EDAD
		FROM	WORK.TEMPORAL
) AS Z
LEFT JOIN ORIGINA.UNIV_EDAD AS U
ON Z.RANGO_EDAD=U.RANGO_EDAD
;QUIT;



/* --------------------------------------------------------------------------------------------------------------------------------- */
/* C8 Parte 2 */

/**************************************** ANALISIS UNIVARIADO PARA VARIABLES CUALITATIVAS ****************************************/

/**************************************** VARIABLE NIVEL ESTUDIOS ****************************************/

/* TABLA AUXILIAR PARA SUSTITUIR POSIBLES VALORES NA */
PROC SQL;																		
CREATE TABLE WORK.TEMPORAL AS
SELECT 		F.CLIENTE,
			NIVEL_ESTUDIOS AS NIVEL_ESTUDIO_ORIGINAL,
			CASE
				WHEN NIVEL_ESTUDIOS IS NULL THEN "NA"
			ELSE NIVEL_ESTUDIOS
			END AS NIVEL_ESTUDIOS,
			BAD
FROM 		ORIGINA.DEMOGRAFICOS AS D
INNER JOIN 	ORIGINA.FLAG_G_B AS F ON D.CLIENTE = F.CLIENTE;
QUIT;


/* TABLA PARA OBTENER EL PORCENTAJE DE MALOS POR CADA CATEGORIA */
PROC SQL;
CREATE TABLE ORIGINA.UNIV_NIVEL_ESTUDIOS AS
SELECT 		NIVEL_ESTUDIOS AS RANGO_NIVEL_ESTUDIOS,
			COUNT(CLIENTE) AS CLIENTES,
			SUM(BAD) AS BADS,
			(SUM(BAD)/COUNT(CLIENTE)) AS PORCENTAJE_BADS
FROM 		WORK.TEMPORAL
GROUP BY 1;
QUIT;


/* RANGOS NUEVOS CREADOS A PARTIR DEL ANALISIS UNIVARIADO */
PROC SQL;
CREATE TABLE ORIGINA.UNIV_NIVEL_ESTUDIOS AS
SELECT 	RANGO_NIVEL_ESTUDIOS,  														
		COUNT(CLIENTE) AS CLIENTES,
		SUM(BAD) AS BADS,
		( SUM(BAD) / COUNT(CLIENTE) ) AS PORCENTAJE_BADS
FROM
( 		
SELECT 		CLIENTE,
			CASE
				WHEN NIVEL_ESTUDIOS IN ("Licenciatura","Postgrado") THEN "Lic o Mas"
				ELSE NIVEL_ESTUDIOS
			END AS RANGO_NIVEL_ESTUDIOS,
			BAD
FROM 		WORK.TEMPORAL
) AS Z	
GROUP BY 1;
QUIT;

/*INSUMO REGRESION*/

PROC SQL;
CREATE TABLE ORIGINA.R_NIVEL_ESTUDIOS AS
SELECT 	CLIENTE,
		PORCENTAJE_BADS AS R_NIVEL_ESTUDIOS
FROM
( 		
	SELECT 		CLIENTE,
			CASE
				WHEN NIVEL_ESTUDIOS IN ("Licenciatura","Postgrado") THEN "Lic o Mas"
				ELSE NIVEL_ESTUDIOS
			END AS RANGO_NIVEL_ESTUDIOS,
			BAD
	FROM 		WORK.TEMPORAL
) AS Z
LEFT JOIN ORIGINA.UNIV_NIVEL_ESTUDIOS AS U
ON Z.RANGO_NIVEL_ESTUDIOS=U.RANGO_NIVEL_ESTUDIOS
;	
QUIT;

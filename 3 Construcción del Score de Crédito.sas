/* C10 MARZO */
/**************************************** CONSTRUCCIÓN DEL SCORE DE CRÉDITO ****************************************/

/* UNIR LAS TABLAS DE INSUMO REGRESION DE LAS VARIABLES SELECCIONADAS */
PROC SQL;
CREATE TABLE ORIGINA.INSUMO_REGRESION AS
SELECT 	M.CLIENTE,
		M.R_MONTO_SOLICITADO,
		N.R_NIVEL_ESTUDIOS,
		E.R_EDAD,
		F.BAD
FROM ORIGINA.R_MONTO_SOLICITADO AS M 
LEFT JOIN ORIGINA.FLAG_G_B AS F ON M.CLIENTE=F.CLIENTE
LEFT JOIN ORIGINA.R_NIVEL_ESTUDIOS AS N ON M.CLIENTE=N.CLIENTE
LEFT JOIN ORIGINA.R_EDAD AS E ON M.CLIENTE=E.CLIENTE
;QUIT;


/* REGRESION LOGISTICA */ 									/* MODELAREMOS LA PROBABILIDAD DEL EVENTO '0' DE LA COLUMNA BAD */
PROC LOGISTIC DATA=ORIGINA.INSUMO_REGRESION;		        /* Por defecto, SAS modela la probabilidad de que la variable dependiente sea igual al valor más bajo (orden alfanumérico o numérico). En regresión logística binaria (ej. 0 y 1), sin DESCENDING, SAS predeciría la probabilidad de 0 (el evento "no éxito"). Con PROC LOGISTIC DATA=ORIGINA.INSUMO_REGRESION DESCENDING; le indicas a SAS que modeles la probabilidad del evento de interés (generalmente 1 o el valor más alto). También puedes lograr lo mismo usando la instrucción MODEL BAD(EVENT='1')=R_MONTO_SOLICITADO R_NIVEL_ESTUDIOS R_EDAD; */
MODEL BAD=R_MONTO_SOLICITADO R_NIVEL_ESTUDIOS R_EDAD		/* SLSTAY := SIGNIFICANCIA MINIMA PARA QUE UNA VARIABLE PERMANEZCA EN AL MODELO.*/
/SELECTION=BACKWARD SLENTRY=0.1 SLSTAY=0.1;					/* SLENTRY:= SIGNIFICANCIA MINIMA PARA QUE UNA VARIABLE ENTRE AL MODELO.*/
RUN; 

/* CONSTRUCCION DEL SCORE EN SAS */
/* UNA VEZ CALCULADOS EL OFFSET Y PDO EN EXCEL, PODEMOS CALCULAR EL SCORE EN SAS */
PROC SQL;
CREATE TABLE ORIGINA.SCORE AS 
SELECT 	CLIENTE,
		R_MONTO_SOLICITADO,
		R_EDAD,
		BAD,
		105+(109/LOG(2))*(5.455-25.0333*R_MONTO_SOLICITADO-18.905*R_EDAD) AS SCORE
FROM ORIGINA.INSUMO_REGRESION AS A
;QUIT;

/* CREAR RANGOS POR CADA DECIL LA VARIABLE SCORE */
PROC UNIVARIATE DATA=ORIGINA.SCORE NOPRINT;
VAR SCORE;
OUTPUT PCTLPRE=P_ PCTLPTS = 0 TO 100 BY 10;
RUN;

/* REPORTE DE PREDICTIBILIDAD DEL MODELO */
PROC SQL;
CREATE TABLE ORIGINA.REPORTE_SCORE AS
SELECT 	RANGO_SCORE,
		COUNT(CLIENTE) AS CLIENTE,
		SUM(BAD) AS BADS,
		SUM(BAD)/COUNT(CLIENTE) AS POR_BADS
FROM
(
SELECT 	CLIENTE,
		SCORE,
		CASE 
			WHEN SCORE >= 400.1164530  AND SCORE < 498.59275439 THEN '01 400.11645303 - 498.59275439'
			WHEN SCORE >= 498.59275439 AND SCORE < 523.67433315 THEN '02 498.59275439 - 523.67433315'
			WHEN SCORE >= 523.67433315 AND SCORE < 565.44619802 THEN '03 523.67433315 - 565.44619802'
			WHEN SCORE >= 565.44619802 AND SCORE < 590.52777679 THEN '04 565.44619802 - 590.52777679'
			WHEN SCORE >= 590.52777679 AND SCORE < 643.47431076 THEN '05 590.52777679 - 643.47431076'
			WHEN SCORE >= 643.47431076 AND SCORE < 668.55588953 THEN '06 643.47431076 - 668.55588953'
			WHEN SCORE >= 668.55588953                          THEN '07 668.55588953 - MAS'
		END AS RANGO_SCORE,
		BAD
FROM ORIGINA.SCORE AS S
) AS Z
GROUP BY 1
;QUIT;

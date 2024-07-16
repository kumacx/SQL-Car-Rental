--
--Jakub Makowski 331713 14.03.2024r. czwartek godz: 12.15
--Z7 
--



------TWORZENIE TABEL------


--Na pocz¹tku upewnie siê, ¿e baza jest czysta
--Robiê to aby w fazie testowania ka¿dy Execute ca³ej bazy zwraca³ wyniki niezale¿ne od poprzednich wywo³añ
IF EXISTS (
	SELECT 1
		FROM sysobjects o
		WHERE (OBJECTPROPERTY(o.[id],'IsUserTable') = 1)
		AND o.[name] = 'WYNAJEM'
)
BEGIN
	DROP TABLE WYNAJEM
END
GO
IF EXISTS (
	SELECT 1
		FROM sysobjects o
		WHERE (OBJECTPROPERTY(o.[id],'IsUserTable') = 1)
		AND o.[name] = 'ZWROT'
)
BEGIN
	DROP TABLE ZWROT
END
GO
IF EXISTS (
	SELECT 1
		FROM sysobjects o
		WHERE (OBJECTPROPERTY(o.[id],'IsUserTable') = 1)
		AND o.[name] = 'AUTA'
)
BEGIN
	DROP TABLE AUTA
END
GO



--Tabela AUTA
IF NOT EXISTS (  --Dla upewnienia siê ¿e nie ma tych tabel, wiem ¿e niepotrzebne w tej chwili,
	SELECT 1     --ale dziêki nim mo¿na usun¹æ powy¿sze czyszczenie bazy.
		FROM sysobjects o
		WHERE (OBJECTPROPERTY(o.[id],'IsUserTable') = 1)
		AND o.[name] = 'AUTA'
)
BEGIN
	CREATE TABLE dbo.AUTA
	(	
	ID_AUTA INT NOT NULL IDENTITY CONSTRAINT PK_AUTA PRIMARY KEY,
	MODEL_AUTA NVARCHAR(100) NOT NULL,
	LICZBA_ZAK INT NOT NULL,
	LICZBA_DOSTEPNYCH INT NOT NULL DEFAULT 0
	)
END
GO

--Tabela ZWROT
IF NOT EXISTS (
	SELECT 1
		FROM sysobjects o
		WHERE (OBJECTPROPERTY(o.[id],'IsUserTable') = 1)
		AND o.[name] = 'ZWROT'
)
BEGIN
	CREATE TABLE dbo.ZWROT
	(	
	ID_ZAK INT NOT NULL IDENTITY CONSTRAINT PK_ZWROT PRIMARY KEY,
	ID_AUTA INT NOT NULL CONSTRAINT FK_AUTA__ZWROT FOREIGN KEY REFERENCES AUTA(ID_AUTA),
	LICZBA INT NOT NULL
	)
END
GO

--Tabela WYNAJEM
IF NOT EXISTS (
	SELECT 1
		FROM sysobjects o
		WHERE (OBJECTPROPERTY(o.[id],'IsUserTable') = 1)
		AND o.[name] = 'WYNAJEM'
)
BEGIN
	CREATE TABLE dbo.WYNAJEM
	(	
	ID_WY INT NOT NULL IDENTITY CONSTRAINT PK_WYNAJEM PRIMARY KEY,
	ID_AUTA INT NOT NULL CONSTRAINT FK_AUTA__WYNAJEM FOREIGN KEY REFERENCES AUTA(ID_AUTA),
	LICZBA INT NOT NULL
	)
END
GO



------TWORZENIE TRIGGERÓW------


----Triggery na auta

--Trigger na insert:

--Usuniêcie jeœli ju¿ istnieje
IF EXISTS (SELECT 1 FROM sys.triggers WHERE name = 'TR_AUTA_INS' AND parent_class_desc = 'OBJECT_OR_COLUMN')
BEGIN
	drop trigger TR_AUTA_INS
END

GO

CREATE TRIGGER dbo.TR_AUTA_INS ON AUTA FOR INSERT 
AS

--Upewnienie siê, ¿e nie próbowano uzupe³niæ liczby dostêpnych rêcznie
	IF EXISTS (SELECT 1 FROM inserted WHERE LICZBA_DOSTEPNYCH NOT IN(0))
		BEGIN
			RAISERROR (N'Liczba dostêpnych aut jest okreœlana automatycznie!', 16, 1)
			ROLLBACK TRAN
		END

	IF EXISTS 
	( SELECT 1
		FROM inserted i
		WHERE i.LICZBA_DOSTEPNYCH = 0
	) 
	BEGIN
		UPDATE AUTA SET LICZBA_DOSTEPNYCH = I.LICZBA_ZAK
		FROM AUTA
		JOIN inserted I ON (AUTA.ID_AUTA = I.ID_AUTA)
	END
GO


--Trigger na update:

--Usuniêcie jeœli ju¿ istnieje
IF EXISTS (SELECT 1 FROM sys.triggers WHERE name = 'TR_AUTA_UPT' AND parent_class_desc = 'OBJECT_OR_COLUMN')
BEGIN
	drop trigger TR_AUTA_UPT
END

GO

CREATE TRIGGER dbo.TR_AUTA_UPT ON AUTA FOR UPDATE
AS
	IF UPDATE(LICZBA_ZAK) 
	BEGIN
		UPDATE AUTA SET AUTA.LICZBA_DOSTEPNYCH = AUTA.LICZBA_DOSTEPNYCH + (I.LICZBA_ZAK - D.LICZBA_ZAK)
		FROM AUTA
		JOIN inserted I ON (AUTA.ID_AUTA = I.ID_AUTA)
		JOIN deleted D ON (AUTA.ID_AUTA = D.ID_AUTA)
	END

	IF EXISTS (SELECT 1 FROM AUTA WHERE LICZBA_DOSTEPNYCH < 0)
		BEGIN
			RAISERROR (N'Liczba dostêpnych aut nie mo¿e byæ mniejsza od 0!', 16, 1)
			ROLLBACK TRAN
		END
		IF EXISTS (SELECT 1 FROM AUTA WHERE LICZBA_DOSTEPNYCH > LICZBA_ZAK)
		BEGIN
			RAISERROR (N'Liczba dostêpnych aut nie mo¿e byæ wiêksza ni¿ liczba zakupionych!', 16, 1)
			ROLLBACK TRAN
		END
GO




----Trigger na wynajem:

--Usuniêcie jeœli ju¿ istnieje
IF EXISTS (SELECT 1 FROM sys.triggers WHERE name = 'TR_WYN_AUTA' AND parent_class_desc = 'OBJECT_OR_COLUMN')
BEGIN
	drop trigger TR_WYN_AUTA
END
GO

CREATE TRIGGER dbo.TR_WYN_AUTA ON WYNAJEM FOR UPDATE, INSERT, DELETE 
AS	
BEGIN
    -- Obs³uga zwiêkszenia (przy usuniêciu wynajmu)
    IF EXISTS (SELECT 1 FROM deleted d WHERE d.LICZBA > 0)
    BEGIN
        UPDATE AUTA
        SET LICZBA_DOSTEPNYCH = LICZBA_DOSTEPNYCH + (SELECT SUM(d.LICZBA) FROM deleted d WHERE d.ID_AUTA = AUTA.ID_AUTA)
        FROM AUTA
        JOIN deleted d ON AUTA.ID_AUTA = d.ID_AUTA;
    END

    -- Obs³uga zmniejszenia
    IF EXISTS (SELECT 1 FROM inserted i WHERE i.LICZBA > 0)
    BEGIN
	select * from inserted
        UPDATE AUTA
        SET LICZBA_DOSTEPNYCH = LICZBA_DOSTEPNYCH - (SELECT SUM(i.LICZBA) FROM inserted i WHERE i.ID_AUTA = AUTA.ID_AUTA)
        FROM AUTA
        JOIN inserted i ON AUTA.ID_AUTA = i.ID_AUTA;
    END
END

GO



----Trigger na zwrot:

--Usuniêcie jeœli ju¿ istnieje
IF EXISTS (SELECT 1 FROM sys.triggers WHERE name = 'TR_ZWR_AUTA' AND parent_class_desc = 'OBJECT_OR_COLUMN')
BEGIN
	drop trigger TR_ZWR_AUTA
END
GO

CREATE TRIGGER dbo.TR_ZWR_AUTA ON ZWROT FOR UPDATE, INSERT, DELETE 
AS	
BEGIN
    -- Obs³uga zmniejszenia (przy usuniêciu zwrotu)
    IF EXISTS (SELECT 1 FROM deleted d WHERE d.LICZBA > 0)
    BEGIN
        UPDATE AUTA
		SET LICZBA_DOSTEPNYCH = LICZBA_DOSTEPNYCH - (SELECT SUM(d.LICZBA) FROM deleted d WHERE d.ID_AUTA = AUTA.ID_AUTA)
        FROM AUTA
        JOIN deleted d ON AUTA.ID_AUTA = d.ID_AUTA;
    END

    -- Obs³uga zwiêkszenia
    IF EXISTS (SELECT 1 FROM inserted i WHERE i.LICZBA > 0)
    BEGIN
	select * from inserted
        UPDATE AUTA
	    SET LICZBA_DOSTEPNYCH = LICZBA_DOSTEPNYCH + (SELECT SUM(i.LICZBA) FROM inserted i WHERE i.ID_AUTA = AUTA.ID_AUTA)
        FROM AUTA
        JOIN inserted i ON AUTA.ID_AUTA = i.ID_AUTA;
    END
END

GO






------TESTOWANIE------




--Wstawienie dwóch modeli do AUTA:

INSERT INTO AUTA (MODEL_AUTA, LICZBA_ZAK) 
	SELECT 'Audi', 100 
	UNION ALL 
	SELECT 'Mercedes', 50

--Wynik:
select ID_AUTA, LEFT(MODEL_AUTA, 22) as MODEL, LICZBA_ZAK, LICZBA_DOSTEPNYCH from auta
select * from wynajem
select * from zwrot
/*
ID_AUTA     MODEL                  LICZBA_ZAK  LICZBA_DOSTEPNYCH
----------- ---------------------- ----------- -----------------
1           Audi                   100         100
2           Mercedes               50          50

(2 row(s) affected)

ID_WY       ID_AUTA     LICZBA
----------- ----------- -----------

(0 row(s) affected)

ID_ZAK      ID_AUTA     LICZBA
----------- ----------- -----------

(0 row(s) affected)
*/


----------------------------------------------------------------------


--Modyfikacja liczby zakupionych dla 'Audi':

UPDATE auta SET LICZBA_ZAK = 60 where MODEL_AUTA = 'Audi'

--Wynik:
select ID_AUTA, LEFT(MODEL_AUTA, 22) as MODEL, LICZBA_ZAK, LICZBA_DOSTEPNYCH from auta
select * from wynajem
select * from zwrot
/*
ID_AUTA     MODEL                  LICZBA_ZAK  LICZBA_DOSTEPNYCH
----------- ---------------------- ----------- -----------------
1           Audi                   60          60
2           Mercedes               50          50

(2 row(s) affected)

ID_WY       ID_AUTA     LICZBA
----------- ----------- -----------

(0 row(s) affected)

ID_ZAK      ID_AUTA     LICZBA
----------- ----------- -----------

(0 row(s) affected)
*/


----------------------------------------------------------------------


--Zapisuje sobie id aut w zmeinne do dalszych testów
declare @id_audi int
SET @id_audi = (select ID_AUTA from AUTA where MODEL_AUTA = 'Audi')
declare @id_merc int
SET @id_merc = (select ID_AUTA from AUTA where MODEL_AUTA = 'Mercedes')


----------------------------------------------------------------------


--Wstawianie wielu rekordów na raz do WYNAJEM

INSERT INTO WYNAJEM (ID_AUTA, LICZBA) 
	SELECT @id_audi, 25 
	UNION ALL 
	SELECT @id_merc, 13

--Wynik:
select ID_AUTA, LEFT(MODEL_AUTA, 22) as MODEL, LICZBA_ZAK, LICZBA_DOSTEPNYCH from auta
select * from wynajem
select * from zwrot
/*
ID_AUTA     MODEL                  LICZBA_ZAK  LICZBA_DOSTEPNYCH
----------- ---------------------- ----------- -----------------
1           Audi                   60          35
2           Mercedes               50          37

(2 row(s) affected)

ID_WY       ID_AUTA     LICZBA
----------- ----------- -----------
1           1           25
2           2           13

(2 row(s) affected)

ID_ZAK      ID_AUTA     LICZBA
----------- ----------- -----------

(0 row(s) affected)
*/


----------------------------------------------------------------------


--Teraz usuniemy poprzednie wynajêcie Mercedesa

DELETE WYNAJEM WHERE ID_AUTA = @id_merc

--Wynik:
select ID_AUTA, LEFT(MODEL_AUTA, 22) as MODEL, LICZBA_ZAK, LICZBA_DOSTEPNYCH from auta
select * from wynajem
select * from zwrot
/*
ID_AUTA     MODEL                  LICZBA_ZAK  LICZBA_DOSTEPNYCH
----------- ---------------------- ----------- -----------------
1           Audi                   60          35
2           Mercedes               50          50

(2 row(s) affected)

ID_WY       ID_AUTA     LICZBA
----------- ----------- -----------
1           1           25

(1 row(s) affected)

ID_ZAK      ID_AUTA     LICZBA
----------- ----------- -----------

(0 row(s) affected)
*/


----------------------------------------------------------------------


--Wstawienie na raz dwóch wynajêæ dla Merdecesa:

INSERT INTO WYNAJEM (ID_AUTA, LICZBA) 
	SELECT @id_merc, 10
	UNION ALL 
	SELECT @id_merc, 22

--Wynik:
select ID_AUTA, LEFT(MODEL_AUTA, 22) as MODEL, LICZBA_ZAK, LICZBA_DOSTEPNYCH from auta
select * from wynajem
select * from zwrot
/*
ID_AUTA     MODEL                  LICZBA_ZAK  LICZBA_DOSTEPNYCH
----------- ---------------------- ----------- -----------------
1           Audi                   60          35
2           Mercedes               50          18

(2 row(s) affected)

ID_WY       ID_AUTA     LICZBA
----------- ----------- -----------
1           1           25
3           2           10
4           2           22

(3 row(s) affected)

ID_ZAK      ID_AUTA     LICZBA
----------- ----------- -----------

(0 row(s) affected)
*/


----------------------------------------------------------------------


--Zmodyfikujemy dwa powy¿sze wynajmy z Mercedesa na Audi

UPDATE WYNAJEM SET ID_AUTA = @id_audi WHERE ID_AUTA = @id_merc

--Wynik:
select ID_AUTA, LEFT(MODEL_AUTA, 22) as MODEL, LICZBA_ZAK, LICZBA_DOSTEPNYCH from auta
select * from wynajem
select * from zwrot
/*
ID_AUTA     MODEL                  LICZBA_ZAK  LICZBA_DOSTEPNYCH
----------- ---------------------- ----------- -----------------
1           Audi                   60          3
2           Mercedes               50          50

(2 row(s) affected)

ID_WY       ID_AUTA     LICZBA
----------- ----------- -----------
1           1           25
3           1           10
4           1           22

(3 row(s) affected)

ID_ZAK      ID_AUTA     LICZBA
----------- ----------- -----------

(0 row(s) affected)
*/


----------------------------------------------------------------------


--Przechodzimy do testowania zwrotów

--Zwrócê na raz 22 i 25 Audi
INSERT INTO ZWROT(ID_AUTA, LICZBA) 
	SELECT @id_audi, 22
	UNION ALL 
	SELECT @id_audi, 25

--Wynik:
select ID_AUTA, LEFT(MODEL_AUTA, 22) as MODEL, LICZBA_ZAK, LICZBA_DOSTEPNYCH from auta
select * from wynajem
select * from zwrot
/*
ID_AUTA     MODEL                  LICZBA_ZAK  LICZBA_DOSTEPNYCH
----------- ---------------------- ----------- -----------------
1           Audi                   60          50
2           Mercedes               50          50

(2 row(s) affected)

ID_WY       ID_AUTA     LICZBA
----------- ----------- -----------
1           1           25
3           1           10
4           1           22

(3 row(s) affected)

ID_ZAK      ID_AUTA     LICZBA
----------- ----------- -----------
1           1           22
2           1           25

(2 row(s) affected)
*/


----------------------------------------------------------------------


--Teraz wynajme troche Mercedesów ¿eby móc zmieniæ powy¿sze zwroty z Audi na Mercedes
INSERT INTO WYNAJEM (ID_AUTA, LICZBA) SELECT @id_merc, 47 --47 bo tyle bylo zwrotów Audi wiec powinny Mercedesy wyjœæ na zero

UPDATE ZWROT SET ID_AUTA = @id_merc WHERE ID_AUTA = @id_audi

--Wynik:
select ID_AUTA, LEFT(MODEL_AUTA, 22) as MODEL, LICZBA_ZAK, LICZBA_DOSTEPNYCH from auta
select * from wynajem
select * from zwrot
/*
ID_AUTA     MODEL                  LICZBA_ZAK  LICZBA_DOSTEPNYCH
----------- ---------------------- ----------- -----------------
1           Audi                   60          3
2           Mercedes               50          50

(2 row(s) affected)

ID_WY       ID_AUTA     LICZBA
----------- ----------- -----------
1           1           25
3           1           10
4           1           22
5           2           47

(4 row(s) affected)

ID_ZAK      ID_AUTA     LICZBA
----------- ----------- -----------
1           2           22
2           2           25

(2 row(s) affected)
*/


----------------------------------------------------------------------


--Usunê oba zwroty Mercedesów
DELETE ZWROT WHERE ID_AUTA = @id_merc

--Wynik:
select ID_AUTA, LEFT(MODEL_AUTA, 22) as MODEL, LICZBA_ZAK, LICZBA_DOSTEPNYCH from auta
select * from wynajem
select * from zwrot
/*
ID_AUTA     MODEL                  LICZBA_ZAK  LICZBA_DOSTEPNYCH
----------- ---------------------- ----------- -----------------
1           Audi                   60          3
2           Mercedes               50          3

(2 row(s) affected)

ID_WY       ID_AUTA     LICZBA
----------- ----------- -----------
1           1           25
3           1           10
4           1           22
5           2           47

(4 row(s) affected)

ID_ZAK      ID_AUTA     LICZBA
----------- ----------- -----------

(0 row(s) affected)
*/


----------------------------------------------------------------------


--Przetestujmy jeszcze zmianê LICZBY_DOSTEPNYCH gdy zmienimy LICZBE_ZAK gdy s¹ jakieœ wynajête 

UPDATE AUTA SET LICZBA_ZAK = 120 where ID_AUTA = @id_audi

--Wczeœniej LICZBA_ZAK dla Audi by³a 60 wiêc jak zmieniliœmy j¹ na 120 to powinno przybyæ 60 dostêpnych
--I tak te¿ siê sta³o:

--Wynik:
select ID_AUTA, LEFT(MODEL_AUTA, 22) as MODEL, LICZBA_ZAK, LICZBA_DOSTEPNYCH from auta
select * from wynajem
select * from zwrot
/*
ID_AUTA     MODEL                  LICZBA_ZAK  LICZBA_DOSTEPNYCH
----------- ---------------------- ----------- -----------------
1           Audi                   120         63
2           Mercedes               50          3

(2 row(s) affected)

ID_WY       ID_AUTA     LICZBA
----------- ----------- -----------
1           1           25
3           1           10
4           1           22
5           2           47

(4 row(s) affected)

ID_ZAK      ID_AUTA     LICZBA
----------- ----------- -----------

(0 row(s) affected)
*/


--A teraz w drug¹ stronê (zmniejszenie LICZBA_ZAK)

UPDATE AUTA SET LICZBA_ZAK = 90 where ID_AUTA = @id_audi

--Teraz zmniejszyliœmy LICZBA_ZAK do 90 (zmniejszenie o 30) wiêc LICZBA_DOSTEPNYCH zmniejszy³a siê o 30:

--Wynik:
select ID_AUTA, LEFT(MODEL_AUTA, 22) as MODEL, LICZBA_ZAK, LICZBA_DOSTEPNYCH from auta
select * from wynajem
select * from zwrot
/*
ID_AUTA     MODEL                  LICZBA_ZAK  LICZBA_DOSTEPNYCH
----------- ---------------------- ----------- -----------------
1           Audi                   90          33
2           Mercedes               50          3

(2 row(s) affected)

ID_WY       ID_AUTA     LICZBA
----------- ----------- -----------
1           1           25
3           1           10
4           1           22
5           2           47

(4 row(s) affected)

ID_ZAK      ID_AUTA     LICZBA
----------- ----------- -----------

(0 row(s) affected)
*/



----------------------------------------------------------------------



----Zosta³y do przetestowania triggery sprawdzaj¹ce poprawnoœæ LICZBA_DOSTEPNYCH


--Spróbujmy zwróciæ na raz tyle Audi aby by³o ich wiêcej ni¿ ich LICZBA_ZAKUPIONYCH

INSERT INTO ZWROT (ID_AUTA, LICZBA) SELECT @id_audi, 1000

--Wynik:
/*
Msg 50000, Level 16, State 1, Procedure TR_AUTA_UPT, Line 20
Liczba dostêpnych aut nie mo¿e byæ wiêksza ni¿ liczba zakupionych!
Msg 3609, Level 16, State 1, Procedure TR_ZWR_AUTA, Line 18
The transaction ended in the trigger. The batch has been aborted.
*/

--Wyskoczy³ Error powiadamiaj¹cy o b³êdzie a tablice zgodnie z oczekiwaniami nie zosta³y zmienione

select ID_AUTA, LEFT(MODEL_AUTA, 22) as MODEL, LICZBA_ZAK, LICZBA_DOSTEPNYCH from auta
select * from wynajem
select * from zwrot

/*
ID_AUTA     MODEL                  LICZBA_ZAK  LICZBA_DOSTEPNYCH
----------- ---------------------- ----------- -----------------
1           Audi                   60          3
2           Mercedes               50          3

(2 row(s) affected)

ID_WY       ID_AUTA     LICZBA
----------- ----------- -----------
1           1           25
3           1           10
4           1           22
5           2           47

(4 row(s) affected)

ID_ZAK      ID_AUTA     LICZBA
----------- ----------- -----------

(0 row(s) affected)
*/



--Teraz druga mo¿liwoœæ, wydanie tyle aut aby licznik dostêpnych by³ ujemny:

INSERT INTO WYNAJEM (ID_AUTA, LICZBA) SELECT @id_merc, 220

--Wynik:
/*
Msg 50000, Level 16, State 1, Procedure TR_AUTA_UPT, Line 15
Liczba dostêpnych aut nie mo¿e byæ mniejsza od 0!
Msg 3609, Level 16, State 1, Procedure TR_WYN_AUTA, Line 18
The transaction ended in the trigger. The batch has been aborted.
*/

--Wyskoczy³ Error powiadamiaj¹cy o b³êdzie a tablice zgodnie z oczekiwaniami nie zosta³y zmienione

select ID_AUTA, LEFT(MODEL_AUTA, 22) as MODEL, LICZBA_ZAK, LICZBA_DOSTEPNYCH from auta
select * from wynajem
select * from zwrot
/*
ID_AUTA     MODEL                  LICZBA_ZAK  LICZBA_DOSTEPNYCH
----------- ---------------------- ----------- -----------------
1           Audi                   60          3
2           Mercedes               50          3

(2 row(s) affected)

ID_WY       ID_AUTA     LICZBA
----------- ----------- -----------
1           1           25
3           1           10
4           1           22
5           2           47

(4 row(s) affected)

ID_ZAK      ID_AUTA     LICZBA
----------- ----------- -----------

(0 row(s) affected)
*/

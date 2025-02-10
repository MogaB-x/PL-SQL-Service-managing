CREATE TABLE programare (
    id_programare           INTEGER NOT NULL,
    data_prog               DATE NOT NULL,
    ora_prog                DATE NOT NULL,
    id_client               INTEGER NOT NULL,
    masina_id_masina        INTEGER NOT NULL,
    procedura_id_procedura  INTEGER NOT NULL,
    ora_finalizare          DATE NOT NULL
)
LOGGING;

ALTER TABLE programare
    ADD CONSTRAINT programare_pk PRIMARY KEY ( id_programare,
                                               id_client,
                                               masina_id_masina,
                                               procedura_id_procedura );

CREATE TABLE masina (
    id_masina         INTEGER NOT NULL,
    marca             VARCHAR2(40) NOT NULL,
    model             VARCHAR2(50),
    serie_vin         VARCHAR2(17) NOT NULL,
    client_id_client  INTEGER NOT NULL
)
LOGGING;

ALTER TABLE masina ADD CONSTRAINT masina_pk PRIMARY KEY ( id_masina,
                                                          client_id_client );

CREATE TABLE detalii_client (
    email             VARCHAR2(40) NOT NULL,
    telefon           INTEGER NOT NULL,
    adresa            VARCHAR2(80),
    client_id_client  INTEGER NOT NULL
)
LOGGING;

ALTER TABLE detalii_client
    ADD CONSTRAINT email_ck CHECK ( REGEXP_LIKE ( email,
                                                  '[a-z0-9._%-]+@[a-z0-9._%-]+\.[a-z]{2,4}' ) );

CREATE UNIQUE INDEX detalii_client__idx ON
    detalii_client (
        client_id_client
    ASC )
        LOGGING;

ALTER TABLE detalii_client ADD CONSTRAINT detalii_client_pk PRIMARY KEY ( client_id_client );

ALTER TABLE detalii_client ADD CONSTRAINT detalii_client_telefon_un UNIQUE ( telefon );

CREATE TABLE client (
    id_client    INTEGER NOT NULL,
    nume_client  VARCHAR2(40) NOT NULL
)
LOGGING;

ALTER TABLE client ADD CONSTRAINT client_pk PRIMARY KEY ( id_client );

CREATE OR REPLACE PACKAGE delete_client_package AS
  PROCEDURE delete_client(p_id_client IN INTEGER);
END delete_client_package;
/

CREATE OR REPLACE PACKAGE BODY delete_client_package AS
  PROCEDURE delete_client(p_id_client IN INTEGER) IS
  BEGIN
    -- Check if there are any appointments linked to the client, and if so, delete them  
    DELETE FROM programare WHERE id_client = p_id_client;
    
    -- Delete child records from the 'vehicle' table that are linked to the parent client
    DELETE FROM masina WHERE client_id_client = p_id_client;

    -- Delete client details 
    DELETE FROM detalii_client WHERE client_id_client = p_id_client;

    -- Delete the client  
    DELETE FROM client WHERE id_client = p_id_client;
  END delete_client;
END delete_client_package;
/

CREATE OR REPLACE FUNCTION numar_schimburi_ulei RETURN INTEGER IS

    v_numar_schimburi INTEGER := 0;
    CURSOR c_programari IS
    SELECT
        COUNT(*) AS numar_schimburi
    FROM
        programare
    WHERE
        procedura_id_procedura IN ( 1, 2, 10, 11 )  -- IDs of oil change procedures 
        AND EXTRACT(MONTH FROM data_prog) = EXTRACT(MONTH FROM sysdate)
        AND EXTRACT(YEAR FROM data_prog) = EXTRACT(YEAR FROM sysdate);

BEGIN
    OPEN c_programari;
    FETCH c_programari INTO v_numar_schimburi;
    CLOSE c_programari;
    RETURN v_numar_schimburi;
END;
/

CREATE TABLE procedura (
    id_procedura    INTEGER NOT NULL,
    nume_procedura  VARCHAR2(80) NOT NULL,
    durata          INTEGER NOT NULL
)
LOGGING;

ALTER TABLE procedura ADD CONSTRAINT procedura_pk PRIMARY KEY ( id_procedura );

ALTER TABLE detalii_client
    ADD CONSTRAINT detalii_client_client_fk FOREIGN KEY ( client_id_client )
        REFERENCES client ( id_client )
    NOT DEFERRABLE;

ALTER TABLE masina
    ADD CONSTRAINT masina_client_fk FOREIGN KEY ( client_id_client )
        REFERENCES client ( id_client )
    NOT DEFERRABLE;

ALTER TABLE programare
    ADD CONSTRAINT programare_client_fk FOREIGN KEY ( id_client )
        REFERENCES client ( id_client )
    NOT DEFERRABLE;

ALTER TABLE programare
    ADD CONSTRAINT programare_masina_fk FOREIGN KEY ( masina_id_masina,
                                                      id_client )
        REFERENCES masina ( id_masina,
                            client_id_client )
    NOT DEFERRABLE;

ALTER TABLE programare
    ADD CONSTRAINT programare_procedura_fk FOREIGN KEY ( procedura_id_procedura )
        REFERENCES procedura ( id_procedura )
    NOT DEFERRABLE;

CREATE OR REPLACE TRIGGER trigger_completare_ora_finalizare 
    BEFORE INSERT OR UPDATE ON Programare 
    FOR EACH ROW 
DECLARE
  durata_procedura INTEGER;
BEGIN
  -- Get the procedure duration based on procedure ID 
  SELECT durata INTO durata_procedura
  FROM procedura
  WHERE id_procedura = :NEW.procedura_id_procedura;

  -- Calculate the completion time based on the appointment time and procedure duration
  :NEW.ora_finalizare := :NEW.ora_prog + (durata_procedura / 60 / 24);

END; 
/

CREATE OR REPLACE TRIGGER trigger_stergere_client 
    BEFORE DELETE ON Client 
    FOR EACH ROW 
DECLARE
  numar_programari INTEGER;
BEGIN
  -- Check if the client has any associated appointments
  SELECT COUNT(*) INTO numar_programari
  FROM programare
  WHERE id_client = :OLD.id_client
    AND data_prog >= SYSDATE;

  IF numar_programari > 0 THEN
    -- The client has scheduled appointments, throw an exception or display an error message
    RAISE_APPLICATION_ERROR(-20001, 'Nu se poate sterge clientul deoarece are programari asociate!');
  END IF;
END; 
/

CREATE OR REPLACE TRIGGER trigger_validare_programare 
    BEFORE INSERT OR UPDATE ON Programare 
    FOR EACH ROW 
DECLARE
  data_curenta DATE;
BEGIN
  -- Get the current date 
  data_curenta := TRUNC(SYSDATE);

  -- Check if the appointment date is in the past
  IF :NEW.data_prog < data_curenta THEN
    -- The appointment date is in the past, throw an exception or display an error message
    RAISE_APPLICATION_ERROR(-20001, 'Nu este permisa adaugarea unei programari în trecut!');
  END IF;
END; 
/

CREATE OR REPLACE TRIGGER trigger_verificare_suprapunere 
    BEFORE INSERT OR UPDATE ON Programare 
    FOR EACH ROW 
DECLARE
    numar_programari INTEGER;
BEGIN
    -- Check if there are overlapping appointments with the new one
    SELECT COUNT(*) INTO numar_programari
    FROM programare
    WHERE id_programare <> :NEW.id_programare  -- Exclude the current appointment (if it's an update)
        AND data_prog = TRUNC(:NEW.data_prog)
        AND (
            -- Verify if the time slots overlap, considering the completion time as well
            (:NEW.ora_prog >= ora_prog AND :NEW.ora_prog < ora_finalizare)
            OR (:NEW.ora_finalizare > ora_prog AND :NEW.ora_finalizare <= ora_finalizare)
            OR (:NEW.ora_prog <= ora_prog AND :NEW.ora_finalizare >= ora_finalizare)
            OR (:NEW.ora_prog <= ora_prog AND :NEW.ora_finalizare > ora_prog)
        );

    IF numar_programari > 0 THEN
        -- Overlapping appointments detected, throw an exception or display an error message
        RAISE_APPLICATION_ERROR(-20001, 'Nu este permisa adaugarea sau actualizarea programarii. Locul este ocupat în intervalul specificat!');
    END IF;
END; 
/
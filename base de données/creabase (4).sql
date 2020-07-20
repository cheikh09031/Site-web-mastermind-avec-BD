SET SERVEROUTPUT ON ;

drop table solution;
drop table coups;
drop table partie;
drop table composer;
drop table couleur;
drop table joueur;
drop table difficulte;
drop sequence idCoup; 
drop sequence IdPartie;

create table difficulte
(NivDiff number,
NbreX number,
NbreY number,
NbrCoulPalette number,
constraint pk_difficulte primary key(NIvDiff),
constraint ck_nivdiff check( NivDiff BETWEEN 1 AND 3)
);

create table joueur
(pseudo varchar(20),
mot_de_passe varchar(20) not null,
niveau_diff not null,
heureblocage NUMBER,
constraint pk_joueur primary key(pseudo),
constraint fk_nivdiff foreign key (niveau_diff) references difficulte(NIvDiff),
constraint ck_mdptaille check(length(mot_de_passe)>4)
);



create table couleur
(NomCouleur varchar(20),
NumCouleur NUMBER(1),
constraint pk_couleur primary key(NumCouleur),
constraint ck_numCouleur check (numCouleur <=7 AND numCouleur >=0)
);

create table composer
(NivDiff number not null,
NumCouleur NUMBER not null,
constraint pk_composer primary key(NivDiff, NumCouleur),
constraint fk_compo_nivdiff foreign key (NivDiff) references difficulte(NIvDiff),
constraint fk_compo_nomcouleur foreign key (NumCouleur) references couleur(NumCouleur)
);

create table partie
(IdPartie varchar(20),
gagne NUMBER,
fini NUMBER,
score number default 0,
date_part date DEFAULT sysdate,
heuredeb_part NUMBER,
heurefin_part NUMBER,
NivDiff number not null,
pseudo varchar(20) not null,
constraint pk_partie primary key(IdPartie),
constraint fk_part_NivDiff foreign key (NivDiff) references difficulte(NIvDiff),
constraint fk_part_pseudo foreign key (pseudo) references joueur(pseudo),
constraint ck_gagne check ( gagne = 1 OR gagne = 0),
constraint ck_fini check ( fini = 1 OR fini = 0)
);


create table coups
(ligne number,
colonne  number,
numcouleur NUMBER not null,
idpartie varchar(20) not null,
constraint pk_coups primary key(ligne, colonne, idpartie),
constraint fk_coups_nomcouleur foreign key (numcouleur) references couleur(NumCouleur),
constraint fk_coups_idpartie foreign key (idpartie) references partie(IdPartie),
constraint ck_ligne check (ligne >=0 AND ligne <= 9),
constraint ck_colonne check (colonne >=0 AND colonne <= 3)
);

create table solution
( IdPartie varchar(20),
numcouleur NUMBER,
positionX number,
constraint pk_solution primary key(IdPartie, numcouleur, positionX),
constraint fk_solution_idpartie foreign key (IdPartie) references partie(IdPartie),
constraint fk_solution_nomcouleur foreign key (numcouleur) references couleur(NumCouleur),
constraint ck_position check (positionX BETWEEN 0 AND 3)
);

/*Remplissage table couleur*/
insert into couleur values ('rouge',0);
insert into couleur values ('vert',1);
insert into couleur values ('noir',2);
insert into couleur values ('blanc',3);
insert into couleur values ('jaune',4);
insert into couleur values ('violet',5);
insert into couleur values ('orange',6);
insert into couleur values ('brun',7);

/*Remplissage table difficulte*/
insert into difficulte values(1,4,10,4);
insert into difficulte values(2,4,8,6);
insert into difficulte values(3,4,6,8);

/* TRIIIIIIIIIIGGGGER */


/* TRIGGER NIvEAU AUTORISE */

CREATE OR REPLACE TRIGGER niveauAutorise BEFORE INSERT ON Partie FOR EACH ROW

DECLARE
niveauMax NUMBER;

BEGIN
SELECT niveau_diff INTO niveauMax FROM Joueur WHERE pseudo = :NEW.pseudo;

IF (:NEW.NivDiff >  niveauMax) THEN
    raise_application_error(-20000,'Niveau pas autorisé');
    
END IF;
END;
/

/* TRIGGER PAS PLUS 5 PARTIE */


CREATE OR REPLACE TRIGGER PasPlus5partiePerdu BEFORE INSERT ON Partie FOR EACH ROW
Declare

si NUMBER;
heureinterdit number;
heureactuelle NUMBER;

Begin
SELECT DBMS_UTILITY.GET_TIME INTO heureactuelle FROM DUAL; 
SELECT count(heureblocage) INTO si FROM JOUEUR WHERE PSEUDO = :NEW.PSEUDO;
IF si != 0 THEN
    SELECT heureblocage INTO heureinterdit FROM JOUEUR WHERE pseudo = :NEW.pseudo;
    IF heureactuelle - heureinterdit < 4*3600000 THEN
        raise_application_error(-20001,'Quota de parties perdu en 1h atteint');
    END IF;
END IF;

END;
/

/* TRIGGER COUPS INTERDIT */

CREATE OR REPLACE TRIGGER coupsInderdit BEFORE INSERT ON Coups FOR EACH ROW
DECLARE

niveau NUMBER;

BEGIN
SELECT nivdiff INTO niveau FROM PARTIE WHERE IdPartie = :new.IdPartie;
IF (niveau = 2 AND :new.ligne > 8 ) OR (niveau =3 AND :new.ligne > 6) THEN
    raise_application_error(-20002,'Plus de tentatives permises'); 
END IF;
END;
/

/* PROCEEEEDUUURE */

/* PROCEDURE Niveau max permi +CREER PARTIE + GENERER SOLUTION */

CREATE OR REPLACE PROCEDURE niveauMaxPermi(vpseudo JOUEUR.Pseudo%TYPE, nivmax out number, retour out number) as
BEGIN
select niveau_diff into nivmax from joueur where pseudo=vpseudo;
retour:=0;
exception
when NO_Data_found then
    retour:=1;
WHEN OTHERS THEN
    retour :=2;
end;
/

CREATE SEQUENCE IdPartie start with 1;

CREATE OR REPLACE PROCEDURE creerPartie( vIdJoueur JOUEUR.Pseudo%TYPE, vNivDiff DIFFICULTE.NivDiff%TYPE, 
                                            retour OUT NUMBER, idP OUT NUMBER, tex out VARCHAR) AS


x NUMBER;
NbrePalette NUMBER;
solCouleur number;
flag number;
compteniv number;
comptecoul number;
continuer number;
fk exception;
partiemax exception;
niveauautorise exception;
pragma exception_init(niveauautorise, -20000);
pragma exception_init(partiemax, -20001);
pragma exception_init(fk, -2291);

BEGIN 
flag :=1;
SELECT nivdiff into compteniv FROM DIFFICULTE WHERE vNivDiff = NivDiff;
flag:=2;
idP := IdPartie.nextval;
INSERT INTO PARTIE VALUES( idP, null, 0, 0, sysdate,DBMS_UTILITY.GET_TIME,NULL, vNivDiff, vIdJoueur);
/*solution de la partie*/
IF vNivDIff = 1 THEN 
	NbrePalette := 3;
ELSIF vNivDiff = 2 then
	NbrePalette := 5;
ELSE 
	NbrePalette := 7;
END IF ;
x := 0;
WHILE ( x < 4 ) LOOP
    SELECT NumCouleur into solCouleur FROM Couleur WHERE NumCouleur = round(dbms_random.value(0,NbrePalette));
    INSERT INTO Solution VALUES (idP,solCouleur, x );
    x := x+1;
END LOOP;
COMMIT;
retour:=0;

EXCEPTION 
when NO_Data_found then
    if flag = 2 then
        dbms_output.put_line('Le numéro de couleur n existe pas');
        retour :=1;
    else
        dbms_output.put_line('Le niveau de difficulté n est pas reconnu');
        retour:=2;
    end if;
when fk then
    dbms_output.put_line('Le joueur n existe pas');
    retour:=3;
when partiemax then
    dbms_output.put_line('Plus de 5 partie perdus en 1h');
    retour:=4;
when niveauautorise then
    dbms_output.put_line('Ce niveau n est pas encore accessible');
    retour :=5;
WHEN OTHERS THEN
    retour :=6;
    tex:=sqlerrm;
END;
/

/* PROCEDURE INSCRIPTION */

CREATE OR REPLACE PROCEDURE inscription (vpseudo IN JOUEUR.pseudo%TYPE, vmot_de_passe IN JOUEUR.mot_de_passe%TYPE, retour OUT NUMBER) IS

BEGIN
INSERT INTO joueur(pseudo,mot_de_passe, niveau_diff) values (vpseudo,vmot_de_passe, 1);
commit;
retour := 0;

EXCEPTION
WHEN DUP_VAL_ON_INDEX THEN
    DBMS_OUTPUT.PUT_LINE('joueur déjà existant');
    retour := 1;
WHEN OTHERS THEN
    if (SQLERRM LIKE '%CK_MDPTAILLE%') THEN
    DBMS_OUTPUT.PUT_LINE('mot de passe trop court');
    retour:=2;
    else
    DBMS_OUTPUT.PUT_LINE(sqlerrm||' '||sqlcode);
    retour := 3;
    end if;
END;
/

/* PROCEDURE FIN DE PARTIE */

CREATE OR REPLACE PROCEDURE finPartie (vidPartie Partie.IdPartie%TYPE, vgagne Partie.gagne %TYPE, vscore Partie.score%TYPE,vpseudo partie.pseudo%TYPE, vniveau Joueur.niveau_diff%type, retour OUT NUMBER, niveauMaxPermi out number) IS 

nombrepartie NUMBER;
verifpseudo JOUEUR.pseudo%TYPE;
flag NUMBER;
niveaumax number;
nivPermi number;

BEGIN 
flag :=1;
SELECT PSEUDO into verifpseudo FROM JOUEUR WHERE PSEUDO = vpseudo;
UPDATE PARTIE 
SET gagne = vgagne, fini = 1, score = vscore, heurefin_part = DBMS_UTILITY.GET_TIME WHERE idPartie = vIdPartie;
flag := 2;
SELECT COUNT(IdPARTIE) INTO nombrepartie FROM Partie WHERE (pseudo = vpseudo )AND (gagne = 0) AND (DBMS_UTILITY.GET_TIME - heurefin_part) < 3600000;

IF nombrepartie >4 THEN
    UPDATE JOUEUR SET
    heureblocage = DBMS_UTILITY.GET_TIME WHERE pseudo = vpseudo;
END IF ;
select niveau_diff into niveaumax from joueur where pseudo=vpseudo;
nivPermi:=vniveau;/*niveau du jeu*/
if vgagne=1 then
nivPermi:=vniveau+1; /*s'il gagne on augmente le niveau permi*/
end if;
if vgagne=1 and niveaumax<nivPermi and nivPermi<=3 then
update joueur set niveau_diff=nivPermi where pseudo=vpseudo;
end if;
select niveau_diff into niveauMaxPermi from joueur where pseudo=vpseudo;
COMMIT;
retour :=0;
EXCEPTION 

WHEN NO_DATA_FOUND THEN
    IF flag = 1 THEN
        DBMS_OUTPUT.PUT_LINE('Ce joueur n existe pas');
        retour :=1;
    ELSE
        DBMS_OUTPUT.PUT_LINE('Cette partie n existe pas');
        retour :=2;
    END IF;
WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE(sqlerrm||' '||sqlcode);
    retour :=3;
    
END;
/

/*VUUUUE*/

/* Classement Journalier */

create or replace view ClassementJour as
select * from
(SELECT pseudo, nivdiff, score FROM partie WHERE  trunc(date_part)=TO_DATE(sysdate,'dd/mm/yy') and fini=1 and gagne=1 ORDER BY  score desc)
where rownum <= 5;

/* Classement toujours */

create or replace view Classement_Always as
select * from
(select pseudo, nivdiff, score FROM partie WHERE fini=1 and gagne=1 order by score desc)
where rownum <= 5;

/*Mes parties*/
create or replace view Partiesfinies as
select pseudo, idpartie,gagne, score, nivdiff 
from partie where fini=1;

grant select, update, insert, delete on solution to zgf2829a;
grant select, update, insert, delete on coups to zgf2829a; 
grant select, update, insert, delete on partie to zgf2829a; 
grant select, update, insert, delete on composer to zgf2829a; 
grant select, update, insert, delete on couleur to zgf2829a; 
grant select, update, insert, delete on joueur to zgf2829a; 
grant select, update, insert, delete on difficulte to zgf2829a; 

grant execute on creerPartie to zgf2829a;
grant execute on inscription to zgf2829a;
grant execute on finPartie to zgf2829a;


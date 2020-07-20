#!/usr/bin/env python
# coding: utf-8

# PREMIER SITE ESSAI

from flask import Flask, render_template, Markup, request
import cx_Oracle
import datetime
from sqlalchemy import create_engine
from gevent.pywsgi import WSGIServer
engine = create_engine('oracle://dpc2146a:F@ctoriserr97@telline.univ-tlse3.fr:1521/etupre')

app=Flask(__name__)
@app.route('/')#connexion
def connexion():
    return render_template('pages/menuConnexion.html')

@app.route('/inscription')
def inscription():
    return render_template("pages/menuInscription.html")

@app.route('/home/', methods = ['POST'])
def home(): 
    motdepasse = request.form['login_password']
    identifiant = request.form['login_login']
    strSQL = "select mot_de_passe from joueur where pseudo = '" + identifiant + "'" 
    with engine.connect() as con:
        mdp = con.execute(strSQL)
        for row in mdp :
            for element in row : 
                if (element == motdepasse):
                    return render_template("pages/home.html", pseudo=identifiant)
    return render_template("pages/menuConnexion.html", content = -1)

@app.route('/inscrit/', methods = ['POST'])
def inscrit():
    motdepasse = request.form['login_password']
    identifiant = request.form['login_login']
    connection = engine.raw_connection()
    try:
        cursor = connection.cursor()
        a = cursor.var(cx_Oracle.NUMBER)  # variable OUT
        cursor.callproc("inscription", [identifiant,motdepasse,a])
        cursor.close()
        connection.commit()
    finally:
        connection.close()
    return render_template("pages/menuInscription.html", content = a.values[0] )

@app.route('/jeu/')
def jeu():
    pseudo=request.args.get('pseudo')
    connection = engine.raw_connection()
    cursor = connection.cursor()
    r = cursor.var(cx_Oracle.NUMBER)
    nivMax = cursor.var(cx_Oracle.NUMBER)
    cursor.callproc("niveauMaxPermi", [pseudo,nivMax ,r])
    cursor.close()
    connection.close()
    nivMax=nivMax.values[0]
    retour=r.values[0]
    if retour==1:
        nivMax=98
    elif retour==2:
        nivMax=99
    return render_template('pages/jeu.html',nivmax=nivMax, pseudo=pseudo)

@app.route('/jeu/solution')
def jeuSolution():
    pseudo=request.args.get('pseudo')
    niveau=request.args.get('niveau')
    connection = engine.raw_connection()
    cursor = connection.cursor()
    r = cursor.var(cx_Oracle.NUMBER)
    idp = cursor.var(cx_Oracle.NUMBER)
    tex=cursor.var(cx_Oracle.STRING)
    cursor.callproc("creerPartie", [pseudo,niveau ,r, idp, tex])
    cursor.close()
    connection.commit()
    connection.close()
    retour=r.values[0]
    idp=idp.values[0]
    if retour==0:
        solution=[]
        strSQL = "SELECT numcouleur FROM solution where idpartie="+str(idp)+' order by positionx'
        with engine.connect() as con:
            rs = con.execute(strSQL)
            for row in rs:
                for value in row:
                    solution.append(int(value))
        sol=''
        print(solution)
        for i in solution:
            sol+=str(i)
        sol+=str(int(idp)) #on y ajoute idpartie
        return sol
    #gestion des erreurs    
    elif retour==1 or retour==3 or retour==6 or retour==2:
        return "-99"
    elif retour==4:
        return "-4"
    elif retour==5:
        return "-5"

@app.route('/jeu/finpartie', methods=["POST"])
def finpartie():
    pseudo=request.args.get('pseudo')
    score=request.args.get('score')
    niveau=request.args.get('niveau')
    idp=request.args.get('idp')
    gagne=request.args.get('gagne')
    table=request.form['tabl']
    connection = engine.raw_connection()
    cursor = connection.cursor()
    r = cursor.var(cx_Oracle.NUMBER)
    niveauMaxPermi = cursor.var(cx_Oracle.NUMBER)
    cursor.callproc("finPartie", [idp,gagne, score, pseudo,niveau ,r, niveauMaxPermi])
    cursor.close()
    connection.commit()
    connection.close()
    retour=r.values[0]
    if retour==0:
        niveauMaxPermi=niveauMaxPermi.values[0]
        s=table.split(" ")
        s.pop(0)#suppression 1er élément qui est un espace
        print(s)
        ligne=-1
        for l in s:
            ligne+=1
            colonne=-1
            print(ligne)
            for numcoul in l:
                colonne+=1
                strSQL='insert into coups values ('+ str(ligne)+','+ str(colonne)+','+str(numcoul)+','+ str(idp)+' )'
                with engine.connect() as con:
                    print(strSQL)
                    con.execute(strSQL)
        with engine.connect() as con:
                    con.execute("commit")
        return str(niveauMaxPermi)
    #gestion des erreurs
    else:
        print(retour)
        return "-99"

@app.route('/classementjour/')
def classementjour():
    pseudo=request.args.get('pseudo')
    code_html = ""
    strSQL = 'select * from ClassementJour'
    with engine.connect() as con:
      rs = con.execute(strSQL)
      for row in rs:
         code_html += "<tr>"
         for value in row:
            code_html += "<td>"+str(value)+"</td>"
    return render_template('pages/classementJour.html', content=Markup(code_html), pseudo=pseudo)

@app.route('/classementcomplet/')
def classementcomplet():
    pseudo=request.args.get('pseudo')
    code_html = ""
    strSQL = 'select * from Classement_Always'
    with engine.connect() as con:
      rs = con.execute(strSQL)
      for row in rs:
         code_html += "<tr>"
         for value in row:
            code_html += "<td>"+str(value)+"</td>"
    return render_template('pages/classementComplet.html', content=Markup(code_html), pseudo=pseudo)

@app.route('/mesparties/')
def mesparties():
    pseudo=request.args.get('pseudo')
    code_html = ""
    strSQL = "select * from partiesfinies where pseudo='"+str(pseudo)+"'"
    with engine.connect() as con:
        rs = con.execute(strSQL)
        j=0 #les lignes
        for row in rs:
            code_html += "<tr>"
            i=0#les colonnes, on donne des coordonnées à chaque bouton rejouer et à idp pour les retrouver plus facilement
            for value in row:
                code_html += "<td class='l"+str(j)+"c"+str(i)+"'>"+str(value)+"</td>"
                i+=1
            code_html += "<td class='caseRejouer' l='"+str(j)+"'> <div class='btnRejouer'>REJOUER</div> </td>"
            j+=1
    print(code_html)
    return render_template('pages/mesParties.html', content=Markup(code_html), pseudo=pseudo)

@app.route('/mesparties/rejouerpartie/')
def rejouerpartie():
    pseudo=request.args.get('pseudo')
    idp=request.args.get('idp')
    print(idp)
    #regenerer le tableau des reponses
    strSQL="select * from coups where idpartie="+str(idp)
    tableau=""
    with engine.connect() as con:
        rs = con.execute(strSQL)
        for row in rs:
            tableau+=" "
            for value in row:
                tableau+=str(value)
    s=tableau.split(" ")
    s.pop(0)
    reponse=[[] for i in range (len(s))]
    for i in range (len(s)):
        for rep in s[i]:
            reponse[i].append(int(rep))
    
    #le niveau
    strSQL="select nivdiff from partie where idpartie="+str(idp)
    with engine.connect() as con:
        rs = con.execute(strSQL)
        for row in rs:
            for value in row:
                niv=int(value)

    #chercher la solution
    strSQL="select nivdiff from partie where idpartie=2 "
    sol=""
    strSQL = "SELECT numcouleur FROM solution where idpartie="+str(idp)+' order by positionx'
    with engine.connect() as con:
        rs = con.execute(strSQL)
        for row in rs:
            for value in row:
                sol+=(str(value))
    return render_template('pages/rejouerPartie.html', tabreponse=reponse, nivchoisi=niv,solution=sol, pseudo=pseudo)


if __name__=='__main__':
    app.run(debug=False)
    http_server = WSGIServer(('', 5000), app)
    http_server.serve_forever()
















# In[ ]:





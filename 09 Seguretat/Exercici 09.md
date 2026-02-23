<div style="display: flex; width: 100%;">
    <div style="flex: 1; padding: 0px;">
        <p>© Albert Palacios Jiménez, 2024</p>
    </div>
    <div style="flex: 1; padding: 0px; text-align: right;">
        <img src="./assets/ieti.png" height="32" alt="Logo de IETI" style="max-height: 32px;">
    </div>
</div>
<br/>

# Exercici 09, Encriptació

Fes una aplicació Flutter que permeti encriptar arxius a través del sistema de *clau pública* i *clau privada*, per compartir-los de manera segura.

L'aplicació a de denir dues vites: 

**Encriptar**

- ha de permetre escollir una clau pública 'rsa' per encriptar 
- ha de permetre escollir un arxiu per encriptar 

**Desencriptar** 

- ha de permetre escollir una clau privada però per defecte ha de mostrar la ~/.ssh/id_rsa 

- ha de permetre escollir l'arxiu a desencriptar 

- ha de permetre escollir l'arxiu destí on es desencriptarà

Aquest és un disseny de les funcionalitats que s'esperen:

<center>
    <img src="./assets/appmockup.png" style="width: 100%; max-width: 800px;">
</center>
## Seguretat

L’encriptació de **clau pública (asimètrica)** funciona amb **dues claus diferents però matemàticament relacionades**:

* **Clau pública** → es pot compartir amb tothom
* **Clau privada** → només la coneix el propietari

### Funcionament

1. Si vols enviar un missatge a algú:

   * Encriptes el missatge amb la **seva clau pública**
   * Només ell el podrà desencriptar amb la **seva clau privada**

2. Si vols signar un missatge:

   * El signes amb la **teva clau privada**
   * Qualsevol pot verificar la signatura amb la **teva clau pública**

---

## 📂 Directoris habituals de claus RSA (Linux / macOS)

Quan generes claus amb:

```bash
ssh-keygen -t rsa
```

Normalment es guarden a:

```
~/.ssh/
```

### Fitxers típics:

| Fitxer            | Contingut                                |
| ----------------- | ---------------------------------------- |
| `id_rsa`          | 🔐 Clau privada                          |
| `id_rsa.pub`      | 🔓 Clau pública                          |
| `authorized_keys` | Claus públiques autoritzades per accedir |
| `known_hosts`     | Hosts coneguts                           |

---


## Important

* **La clau privada mai s’ha de compartir**
* Normalment té permisos 600:

  ```
  chmod 600 id_rsa
  ```


Synchronise les documents de conception avec la discussion en cours.

1. Lire les specs de format : `.project/docs/formats.md`

2. Analyser la conversation pour identifier :
   - Nouvelles user stories mentionnées
   - Modifications du flow/sitemap
   - Changements de schéma DB
   - Nouveaux écrans/wireframes à créer

3. Mettre à jour les fichiers concernés :
   - `.project/user-stories.md`
   - `.project/sitemap.mmd`
   - `.project/database.mmd`
   - `.project/features/<feature>/wireframes/*.html`
   - `.project/features/<feature>/manifest.json`

4. Confirmer chaque modification :
   ```
   ✓ user-stories.md modifié : ajout US-C25, US-C26
   ✓ sitemap.mmd modifié : ajout noeud EXPORT
   ✓ wireframe créé : customer-export.html
   ✓ manifest.json modifié : ajout entrée customer-export
   ```

Feature cible (si connue) : $ARGUMENTS

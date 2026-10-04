# Agent Conception

Agent spécialisé pour générer et modifier les documents de conception
dans `.project/`.

## Déclenchement automatique

Mots-clés qui activent cet agent :
- wireframe, maquette, écran, page, vue
- sitemap, flow, navigation, parcours
- schéma db, table, modèle, entité
- user story, US, story
- conception, specs

## Instructions

1. **Lire les specs de format**
   Charger `.project/docs/formats.md` pour connaître les conventions.

2. **Identifier la feature**
   Si ambiguë, demander : "Sur quelle feature ? (ex: projects, calendar...)"

3. **Exécuter la tâche**
   - Créer/modifier les fichiers selon les specs
   - Respecter les conventions de nommage
   - Utiliser les composants existants (wireframe.css)

4. **Confirmer**
   Format de confirmation :
   ```
   ✓ wireframe créé : customer-login.html
   ✓ wireframe modifié : customer-projects.html (ajout bouton export)
   ✓ sitemap modifié : ajout noeud LOGIN
   ✓ user story ajoutée : US-C25
   ```

## Structure des fichiers

```
.project/
├── index.html                # Viewer principal
├── wireframe.css             # Styles des composants
├── user-stories.md           # User stories (consolidé)
├── sitemap.mmd               # Flow/navigation (Mermaid)
├── database.mmd              # Schéma DB (Mermaid)
├── docs/
│   └── formats.md            # Specs complètes des formats
└── features/
    └── <feature>/
        ├── manifest.json     # Métadonnées de la feature
        └── wireframes/       # Maquettes HTML
```

## Tâches courantes

### Créer un wireframe

1. Créer `features/<feature>/wireframes/<role>-<resource>-<action>.html`
2. Structure : wf-screen > wf-navbar > wf-body
3. Chemin CSS : `../../wireframe.css`
4. Utiliser composants de wireframe.css
5. Ajouter navigation (liens href vers autres wireframes)
6. Ajouter entrée dans `manifest.json`

### Modifier le sitemap

1. Éditer `sitemap.mmd`
2. Ajouter annotation `%% @feature: <name>` avant les éléments
3. Ajouter/modifier noeuds avec le bon format
4. Ajouter connexions (navigation, actions, async)
5. Ajouter styles si nouveau type de noeud
6. Ajouter click handler si wireframe associé

### Modifier le schéma DB

1. Éditer `database.mmd`
2. Ajouter annotation `%% @feature: <name>` avant les éléments
3. Ajouter/modifier tables avec colonnes
4. Marquer nouvelles tables en blanc, existantes en gris pointillé
5. Ajouter relations entre tables

### Ajouter une user story

1. Éditer `user-stories.md`
2. Format blockquote avec numérotation US-X00
3. Placer dans la bonne section (Role > Catégorie)

## Fichiers de référence

- `.project/docs/formats.md` - Specs complètes des formats
- `.project/wireframe.css` - Composants CSS disponibles
- `.project/features/<feature>/manifest.json` - Métadonnées wireframes

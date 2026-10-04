class RenameTrainingsSequenceToEducations < ActiveRecord::Migration[8.0]
  def up
    # Créer la séquence educations_id_seq si elle n'existe pas
    execute <<-SQL
      DO $$
      BEGIN
        -- Si trainings_id_seq existe, la renommer
        IF EXISTS (SELECT 1 FROM pg_sequences WHERE schemaname = 'public' AND sequencename = 'trainings_id_seq') THEN
          ALTER SEQUENCE trainings_id_seq RENAME TO educations_id_seq;
        -- Sinon, créer educations_id_seq
        ELSIF NOT EXISTS (SELECT 1 FROM pg_sequences WHERE schemaname = 'public' AND sequencename = 'educations_id_seq') THEN
          CREATE SEQUENCE educations_id_seq;
        END IF;
      END$$;
    SQL
    
    # S'assurer que la séquence est correctement liée à la table
    execute <<-SQL
      ALTER SEQUENCE educations_id_seq OWNED BY educations.id;
    SQL
    
    # Mettre à jour la valeur par défaut de la colonne id
    execute <<-SQL
      ALTER TABLE educations ALTER COLUMN id SET DEFAULT nextval('educations_id_seq');
    SQL
    
    # S'assurer que la séquence est synchronisée avec les données existantes
    execute <<-SQL
      SELECT setval('educations_id_seq', COALESCE((SELECT MAX(id) FROM educations), 1));
    SQL
  end
  
  def down
    # Revenir à l'ancienne séquence
    execute <<-SQL
      DO $$
      BEGIN
        IF EXISTS (SELECT 1 FROM pg_sequences WHERE schemaname = 'public' AND sequencename = 'educations_id_seq') THEN
          ALTER SEQUENCE educations_id_seq RENAME TO trainings_id_seq;
        END IF;
      END$$;
    SQL
    
    execute <<-SQL
      ALTER TABLE educations ALTER COLUMN id SET DEFAULT nextval('trainings_id_seq');
    SQL
  end
end

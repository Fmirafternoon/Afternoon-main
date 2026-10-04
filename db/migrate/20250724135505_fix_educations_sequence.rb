class FixEducationsSequence < ActiveRecord::Migration[8.0]
  def up
    # Créer la séquence si elle n'existe pas
    execute <<-SQL
      DO $$
      BEGIN
        IF NOT EXISTS (SELECT 1 FROM pg_sequences WHERE schemaname = 'public' AND sequencename = 'trainings_id_seq') THEN
          CREATE SEQUENCE trainings_id_seq;
        END IF;
      END$$;
    SQL
    
    # S'assurer que la séquence est correctement liée à la table educations
    execute <<-SQL
      ALTER SEQUENCE trainings_id_seq OWNED BY educations.id;
    SQL
    
    # Mettre à jour la valeur de la séquence
    execute <<-SQL
      SELECT setval('trainings_id_seq', COALESCE((SELECT MAX(id) FROM educations), 1));
    SQL
  end
  
  def down
    # Ne rien faire dans le down car on ne veut pas casser la table educations
  end
end

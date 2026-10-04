namespace :pg do
  desc "Pulls production database via docker"
  task :pull do
    # Vérifier Docker
    unless system("docker info > /dev/null 2>&1")
      print "Docker n'est pas lancé. Voulez-vous le démarrer ? (y/n): "
      if $stdin.gets.strip.downcase == "y"
        puts "Démarrage de Docker..."
        system("open -a Docker")
        print "En attente de Docker..."
        sleep 3
        10.times do
          break if system("docker info > /dev/null 2>&1")
          print "."
          sleep 2
        end
        puts
      else
        abort "Docker est requis pour cette tâche"
      end
    end

    database_name = Rails.configuration.database_configuration[Rails.env]["database"]

    # Vérifier les connexions actives
    active_connections = `psql -t -c "SELECT COUNT(*) FROM pg_stat_activity WHERE datname = '#{database_name}' AND pid != pg_backend_pid();" postgres 2>/dev/null`.strip.to_i

    if active_connections > 0
      puts "\n⚠️  #{active_connections} connexion(s) active(s) détectée(s):\n\n"
      system("psql -c \"SELECT pid, usename, application_name, state FROM pg_stat_activity WHERE datname = '#{database_name}' AND pid != pg_backend_pid();\" postgres")
      print "\nVoulez-vous les terminer ? (y/n): "
      if $stdin.gets.strip.downcase == "y"
        system("psql -c \"SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '#{database_name}' AND pid != pg_backend_pid();\" postgres")
        puts "Connexions terminées"
      else
        abort "Impossible de continuer avec des connexions actives"
      end
    end

    print "Pulling production database..."
    `docker run --rm --network=host -v "#{Rails.root}:/tmp/dump" postgres:16 pg_dump --no-owner --no-privileges --dbname=#{ENV.fetch("PRODUCTION_DATABASE_URL")} > production.pgsql`
    puts "done"

    print "Restoring local database..."
    `DISABLE_DATABASE_ENVIRONMENT_CHECK=1 rake db:drop && rake db:create && psql #{database_name} < production.pgsql`
    `rm production.pgsql`
    puts "done"
  end
end

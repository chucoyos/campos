namespace :db do
  namespace :seed do
    desc "Carga el catálogo del patio (bloques, posiciones y áreas) sin tocar otras tablas"
    task yard: :environment do
      load Rails.root.join("db/seeds/yard.rb")
    end
  end
end

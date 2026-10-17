namespace :db do
  namespace :seed do
    desc "Carga el catálogo de la bodega (naves y ubicaciones) sin tocar otras tablas"
    task warehouse: :environment do
      load Rails.root.join("db/seeds/warehouse.rb")
    end
  end
end

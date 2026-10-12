# Las subidas directas a S3 solo se firman para usuarios autenticados.
Rails.application.config.to_prepare do
  ActiveStorage::DirectUploadsController.before_action :authenticate_user!
end

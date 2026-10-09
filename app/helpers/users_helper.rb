module UsersHelper
  ROLE_BADGES = {
    "admin" => "bg-indigo-50 text-indigo-700",
    "cliente" => "bg-sky-50 text-sky-700",
    "transporte" => "bg-amber-50 text-amber-700",
    "seguridad" => "bg-rose-50 text-rose-700",
    "grua" => "bg-emerald-50 text-emerald-700",
    "montacargas" => "bg-violet-50 text-violet-700"
  }.freeze

  def role_badge(role)
    tag.span(t("users.roles.#{role}"), class: "inline-flex rounded-full px-3 py-1 text-xs font-medium #{ROLE_BADGES.fetch(role, 'bg-slate-100 text-slate-700')}")
  end
end

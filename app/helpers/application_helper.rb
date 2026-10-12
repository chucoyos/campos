module ApplicationHelper
  def material_icon(name, classes: nil)
    tag.span(name, class: [ "material-symbols-outlined", classes ], aria: { hidden: true })
  end

  # Ruta del listado sin el filtro indicado; solo conserva filtros conocidos y per_page.
  def filter_removal_path(removed_name)
    allowed = filter_fields.map { |field| field[:name] }
    kept = allowed.without(removed_name).filter_map { |name| [ name, params[name].to_s ] if params[name].present? }.to_h
    kept["per_page"] = per_page.to_s if params[:per_page].present?
    url_for(kept.merge(only_path: true))
  end

  def nav_link_classes(active)
    base = "flex min-h-12 items-center gap-2 rounded-2xl px-4 text-sm font-medium transition-colors"
    state = active ? "bg-indigo-50 text-indigo-700" : "text-slate-600 hover:bg-slate-100"
    "#{base} #{state}"
  end
end

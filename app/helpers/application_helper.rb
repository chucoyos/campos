module ApplicationHelper
  def material_icon(name, classes: nil)
    tag.span(name, class: [ "material-symbols-outlined", classes ], aria: { hidden: true })
  end

  def nav_link_classes(active)
    base = "flex min-h-12 items-center gap-2 rounded-2xl px-4 text-sm font-medium transition-colors"
    state = active ? "bg-indigo-50 text-indigo-700" : "text-slate-600 hover:bg-slate-100"
    "#{base} #{state}"
  end
end

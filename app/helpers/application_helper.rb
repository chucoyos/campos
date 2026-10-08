module ApplicationHelper
  def material_icon(name, classes: nil)
    tag.span(name, class: [ "material-symbols-outlined", classes ], aria: { hidden: true })
  end
end

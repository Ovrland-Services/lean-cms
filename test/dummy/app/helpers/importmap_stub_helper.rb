# importmap-rails isn't bundled in the dummy app.
module ImportmapStubHelper
  def javascript_importmap_tags(*) = "".html_safe
end

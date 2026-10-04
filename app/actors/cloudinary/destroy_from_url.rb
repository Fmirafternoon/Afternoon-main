class Cloudinary::DestroyFromUrl < Actor
  CLOUDINARY_REGEX = /^.+\.cloudinary\.com\/(?:[^\/]+\/)(?:(image|video|raw)\/)?(?:(upload|fetch|private|authenticated|sprite|facebook|twitter|youtube|vimeo)\/)?(?:(?:[^_\/]+_[^,\/]+,?)*\/)?(?:v(\d+|\w{1,2})\/)?([^\.^\s]+)(?:\.(.+))?$/

  input :url

  def call
    Cloudinary::Uploader.destroy(extract_public_id(url), type: :upload)
  end

  private

  def extract_public_id(link)
    return "" if link.nil? || link.empty?
    m = CLOUDINARY_REGEX.match(link)
    m && m[4] ? m[4] : link
  end
end

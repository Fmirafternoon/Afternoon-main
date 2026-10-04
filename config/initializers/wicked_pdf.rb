WickedPdf.config ||= {}
WickedPdf.config.merge!({
  enable_local_file_access: true,
  layout: "layout",
  # On macOS, use the system binary; on Linux (Heroku), fall through to the gem's bundled binary
  exe_path: RUBY_PLATFORM.include?("darwin") ? "/usr/local/bin/wkhtmltopdf" : WickedPdf.config[:exe_path]
})

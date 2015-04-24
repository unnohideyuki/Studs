def detect_mimetype(path)
  dict = { 
    ".png" => "image/png",
    ".pdf" => "application/pdf"
  }
  dict[File.extname(path)] || "application/octet-stream"
end

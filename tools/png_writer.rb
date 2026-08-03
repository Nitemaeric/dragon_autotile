# Minimal RGBA PNG encoder for the dev-time generator tools. Plain Ruby (zlib),
# never shipped to games.

require "zlib"

module PngWriter
  def self.chunk(type, data)
    [data.bytesize].pack("N") + type + data + [Zlib.crc32(type + data)].pack("N")
  end

  def self.write(path, w, h, pixels)
    raw = +""
    h.times do |y|
      raw << "\x00"
      w.times { |x| raw << pixels[y * w + x].pack("C4") }
    end

    png = "\x89PNG\r\n\x1a\n".b
    png << chunk("IHDR", [w, h, 8, 6, 0, 0, 0].pack("NNC5"))
    png << chunk("IDAT", Zlib::Deflate.deflate(raw))
    png << chunk("IEND", "")
    File.binwrite(path, png)
  end
end

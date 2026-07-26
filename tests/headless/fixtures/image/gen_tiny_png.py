import zlib, struct, base64
def chunk(typ, data):
    return struct.pack(">I", len(data)) + typ + data + struct.pack(">I", zlib.crc32(typ+data) & 0xffffffff)
W=H=4
# RGBA rows, filter byte 0 each row; distinct non-symmetric pixel values so invert is observable
raw=b""
for y in range(H):
    raw+=b"\x00"
    for x in range(W):
        raw+=bytes([(x*40)&0xff,(y*50)&0xff,(x*y*10)&0xff,255])
png=b"\x89PNG\r\n\x1a\n"
png+=chunk(b"IHDR",struct.pack(">IIBBBBB",W,H,8,6,0,0,0))
png+=chunk(b"IDAT",zlib.compress(raw,9))
png+=chunk(b"IEND",b"")
b64=base64.b64encode(png).decode()
print(b64)
# Provenance: generates the 4x4 RGBA PNG whose base64 is inlined as image_data=
# in image_embedded.sch (a GRIDLAYER xRECT with flags=image,unscaled). Distinct
# non-symmetric pixels so `xschem image invert write_back` produces an observably
# different image_data. Regenerate: python3 gen_tiny_png.py  (no PIL needed).

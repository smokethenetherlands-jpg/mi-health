import struct, zlib, sys

def make_png(size, r, g, b):
    def chunk(name, data):
        c = zlib.crc32(name + data) & 0xffffffff
        return struct.pack('>I', len(data)) + name + data + struct.pack('>I', c)
    raw = b''.join(b'\x00' + bytes([r, g, b, 255] * size) for _ in range(size))
    ihdr = struct.pack('>IIBBBBB', size, size, 8, 2, 0, 0, 0)
    return b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', ihdr) + chunk(b'IDAT', zlib.compress(raw)) + chunk(b'IEND', b'')

app_path = sys.argv[1]
src = '/tmp/icon_src.png'

with open(src, 'wb') as f:
    f.write(make_png(1024, 52, 199, 89))

print(f'Source icon written to {src}')
print(f'App path: {app_path}')

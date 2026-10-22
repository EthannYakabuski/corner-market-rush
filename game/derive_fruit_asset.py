"""Split actual CC0 Kenney fruit geometry into six stock-visible child nodes.

Run from any directory using Python3. No engine, texture changes or new shapes.
The original GLB is preserved; original position/normal/UV arrays are reused.
"""
from pathlib import Path
from collections import defaultdict
import json
import struct

root = Path(__file__).resolve().parents[1]
source = root / 'assets/kenney/market/display-fruit.glb'
destination = source.with_name('display-fruit-stock.glb')
raw = source.read_bytes()
length = struct.unpack_from('<I', raw, 12)[0]
gltf = json.loads(raw[20:20 + length])
offset = 20 + length
binary_length = struct.unpack_from('<I', raw, offset)[0]
binary = bytearray(raw[offset + 8:offset + 8 + binary_length])
original = gltf['meshes'][0]['primitives'][0]

def accessor_data(index, fmt, components):
    accessor = gltf['accessors'][index]
    view = gltf['bufferViews'][accessor['bufferView']]
    start = view.get('byteOffset', 0) + accessor.get('byteOffset', 0)
    stride = view.get('byteStride', struct.calcsize(fmt) * components)
    return [struct.unpack_from('<' + fmt * components, binary, start + i * stride)
            for i in range(accessor['count'])]

points = accessor_data(original['attributes']['POSITION'], 'f', 3)
kind = gltf['accessors'][original['indices']]['componentType']
indices = [item[0] for item in accessor_data(original['indices'], 'H' if kind == 5123 else 'I', 1)]
keys = [tuple(round(value, 4) for value in point) for point in points]
graph = defaultdict(set)
for i in range(0, len(indices), 3):
    triangle = [keys[index] for index in indices[i:i+3]]
    for vertex in triangle:
        graph[vertex].update(triangle)
components, membership = [], {}
for vertex in graph:
    if vertex in membership:
        continue
    part = len(components)
    todo, component = [vertex], []
    membership[vertex] = part
    while todo:
        current = todo.pop()
        component.append(current)
        for neighbor in graph[current]:
            if neighbor not in membership:
                membership[neighbor] = part
                todo.append(neighbor)
    components.append(component)

def bounds(part):
    return ([min(point[axis] for point in part) for axis in range(3)],
            [max(point[axis] for point in part) for axis in range(3)])

fruit, stems = [], []
for part, values in enumerate(components):
    low, high = bounds(values)
    if low[1] > .25 and high[0] - low[0] < .23:
        (fruit if high[0] - low[0] > .09 else stems).append(part)
assert len(fruit) == 6 and len(stems) == 6, 'Reviewed source geometry changed'
group_for_part = {part: index + 1 for index, part in enumerate(fruit)}
for stem in stems:
    a, b = bounds(components[stem])
    center = [(a[i] + b[i]) / 2 for i in range(3)]
    nearest = min(fruit, key=lambda p: sum((center[i] - sum(bounds(components[p])[j][i] for j in range(2)) / 2) ** 2 for i in range(3)))
    group_for_part[stem] = group_for_part[nearest]
groups = [[] for _ in range(7)]
for i in range(0, len(indices), 3):
    triangle = indices[i:i+3]
    group = group_for_part.get(membership[keys[triangle[0]]], 0)
    assert all(group_for_part.get(membership[keys[index]], 0) == group for index in triangle)
    groups[group].extend(triangle)

gltf['meshes'] = []
gltf['nodes'][0]['children'] = []
gltf['nodes'][0]['mesh'] = 0
for index, values in enumerate(groups):
    while len(binary) % 4:
        binary.append(0)
    start = len(binary)
    binary.extend(struct.pack('<' + 'I' * len(values), *values))
    view = len(gltf['bufferViews'])
    gltf['bufferViews'].append({'buffer': 0, 'byteOffset': start, 'byteLength': len(values) * 4, 'target': 34963})
    accessor = len(gltf['accessors'])
    gltf['accessors'].append({'bufferView': view, 'componentType': 5125, 'count': len(values), 'type': 'SCALAR', 'min': [min(values)], 'max': [max(values)]})
    primitive = dict(original)
    primitive['indices'] = accessor
    gltf['meshes'].append({'name': 'tray' if index == 0 else f'produce_fruit_{index}', 'primitives': [primitive]})
    if index:
        node = len(gltf['nodes'])
        gltf['nodes'].append({'name': f'produce_fruit_{index}', 'mesh': index})
        gltf['nodes'][0]['children'].append(node)
gltf['buffers'][0]['byteLength'] = len(binary)
gltf['asset']['extras'] = {'derivation': 'Original Kenney CC0 geometry split into stock-visible components; original arrays/textures preserved.'}
document = json.dumps(gltf, separators=(',', ':')).encode()
document += b' ' * (-len(document) % 4)
binary += b'\x00' * (-len(binary) % 4)
output = struct.pack('<III', 0x46546C67, 2, 12 + 8 + len(document) + 8 + len(binary))
output += struct.pack('<II', len(document), 0x4E4F534A) + document
output += struct.pack('<II', len(binary), 0x004E4942) + binary
destination.write_bytes(output)
print(f'Wrote {destination.name}: original tray plus six original fruit/stem groups; {len(output)} bytes')

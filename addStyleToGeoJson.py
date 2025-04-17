import json
import sys


with open(sys.argv[1]) as geojson_file:
  file_contents = geojson_file.read()

parsed_json = json.loads(file_contents)
if sys.argv[2] == "fr":
    with open('/opt/scripts/flood-mapping-geojson-style-fr.json') as geojson_style_file:
        style_contents = geojson_style_file.read()
else:
    with open('/opt/scripts/flood-mapping-geojson-style-en.json') as geojson_style_file:
        style_contents = geojson_style_file.read()
  
parsed_style_json = json.loads(style_contents)

parsed_json['geoViewLayerConfig'] = parsed_style_json

with open(sys.argv[1], 'w') as geojson_file:
    geojson_file.write(json.dumps(parsed_json))
from xml.etree import ElementTree 

import sys

style_tidal = """
    <Style id="tidal">
      <LineStyle>
        <color>800000ff</color>
      </LineStyle>
      <PolyStyle>
        <color>800000ff</color>
        <fill>1</fill>
      </PolyStyle>
    </Style>

    """

style_flood = """
    <Style id="flood">
      <LineStyle>
        <color>80ff0000</color>
      </LineStyle>
      <PolyStyle>
        <color>80ff0000</color>
        <fill>1</fill>
      </PolyStyle>
    </Style>

"""


tree = ElementTree.parse(sys.argv[1])
root = tree.getroot()

document = root.findall('''.//*[@id='root_doc']''')[0]

ElementTree.register_namespace('kml', 'http://www.opengis.net/kml/2.2')

floodStyle = ElementTree.fromstring(style_flood)
tidalStyle = ElementTree.fromstring(style_tidal)

document.insert(0, floodStyle)
document.insert(0, tidalStyle)
namespaces = {'kml': 'http://www.opengis.net/kml/2.2'} 
xpath = ".//kml:SimpleData[@name='DN']"

for placeMark in root.findall(".//kml:Placemark", namespaces):
    simpleDataList = placeMark.findall(xpath, namespaces)
    if len(simpleDataList) > 0:
      simpleData = simpleDataList[0]
      if simpleData.text == "1":
          element = ElementTree.Element("styleUrl")
          element.text = "#tidal"
          placeMark.insert(0, element)
          element = ElementTree.Element("name")
          element.text = "Tide level"
          placeMark.insert(0, element)
          element = ElementTree.Element("description")
          element.text = "Increased tide level from the given rise in sea level."
          placeMark.insert(0, element)
      elif simpleData.text == "255":
          element = ElementTree.Element("styleUrl")
          element.text = "#flood"
          placeMark.insert(0, element)
          element = ElementTree.Element("name")
          element.text = "Flood level"
          placeMark.insert(0, element)
          element = ElementTree.Element("description")
          element.text = "Area covered by rise in sea level."
          placeMark.insert(0, element)

tree.write(sys.argv[1])







import json
import re

with open('lugares.json', 'r', encoding='utf-8') as f:
    data = json.load(f)

def slugify(text):
    text = text.lower()
    replacements = {
        'á':'a','é':'e','í':'i','ó':'o','ú':'u','ü':'u','ñ':'n',
        'à':'a','è':'e','ì':'i','ò':'o','ù':'u',
        ' ':'-', '/':'-', '.':'', ',':'', '(':'', ')':'', "'":''
    }
    for k, v in replacements.items():
        text = text.replace(k, v)
    text = re.sub(r'-+', '-', text)
    return text.strip('-')

def name_to_id(name):
    return slugify(name)

def img_id(nombre):
    return nombre.replace('.jpg', '').replace('.JPG', '')

prefixes = """@prefix momo: <http://momoest.gsic.uva.es/ontology/> .
@prefix mo: <http://moult.gsic.uva.es/ontology/> .
@prefix md: <http://moult.gsic.uva.es/data/> .
@prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .
@prefix schema: <http://schema.org/> .
@prefix skos: <http://www.w3.org/2004/02/skos/core#> .
@prefix geo: <http://www.w3.org/2003/01/geo/wgs84_pos#> .
@prefix foaf: <http://xmlns.com/foaf/0.1/> .
@prefix wd: <http://www.wikidata.org/entity/> .
@prefix osmw: <https://www.openstreetmap.org/way/> .

"""

lines = [prefixes]

for lugar in data['lugares']:
    titulo = lugar['titulo']
    slug = slugify(titulo)
    feature_id = f"docomomo-{slug}"

    # --- Feature block ---
    lines.append(f"md:{feature_id}")
    lines.append(f"    a momo:Feature ;")
    lines.append(f'    rdfs:label "{titulo}"@es ;')

    if 'descripcion' in lugar:
        desc = lugar['descripcion'].replace("'", "\\'").replace("\\", "\\\\")
        lines.append(f"    rdfs:comment '''{desc}'''@es ;")

    if 'fechas' in lugar:
        lines.append(f"    momo:startDate \"{lugar['fechas']['inicio']}\" ;")
        lines.append(f"    momo:endDate \"{lugar['fechas']['fin']}\" ;")

    if 'aka' in lugar:
        lines.append(f'    skos:altLabel "{lugar["aka"]}"@es ;')

    if 'uso' in lugar:
        for u in lugar['uso']:
            lines.append(f'    momo:use "{u}"@es ;')

    if 'arquitecto' in lugar and lugar['arquitecto']:
        arch_ids = []
        for arq in lugar['arquitecto']:
            arch_ids.append(f"md:docomomo-{name_to_id(arq['nombre'])}")
        lines.append(f"    momo:architect {', '.join(arch_ids)} ;")

    lines.append(f"    rdfs:seeAlso <{lugar['url']}> ;")

    if 'enlaces' in lugar:
        for enlace in lugar['enlaces']:
            lines.append(f"    rdfs:seeAlso <{enlace}> ;")

    # thumbnail = first image
    if 'imagenes' in lugar and lugar['imagenes']:
        thumb_id = img_id(lugar['imagenes'][0]['nombre'])
        lines.append(f"    momo:thumbnail md:{thumb_id} ;")

        all_img_ids = [f"md:{img_id(img['nombre'])}" for img in lugar['imagenes']]
        lines.append(f"    mo:media {', '.join(all_img_ids)} ;")

    point_id = f"docomomo-{slug}-point"
    lines.append(f"    mo:hasGeometry md:{point_id} .")
    lines.append("")

    # --- Architect blocks ---
    if 'arquitecto' in lugar:
        for arq in lugar['arquitecto']:
            arq_id = f"docomomo-{name_to_id(arq['nombre'])}"
            lines.append(f"md:{arq_id}")
            lines.append(f"    a mo:Person ;")
            lines.append(f'    foaf:name "{arq["nombre"]}" ;')
            lines.append(f"    rdfs:seeAlso <{arq['link']}> .")
            lines.append("")

    # --- Image blocks ---
    if 'imagenes' in lugar:
        for img in lugar['imagenes']:
            iid = img_id(img['nombre'])
            lines.append(f"md:{iid}")
            lines.append(f"    a mo:MediaObject ;")
            lines.append(f"    schema:urlContent <{img['url']}> ;")
            if 'autor' in img:
                lines.append(f'    rdfs:label "{img["autor"]}" ;')
            lines.append(f"    rdfs:sameAs <{img['url']}> .")
            lines.append("")

    # --- Point block ---
    lines.append(f"md:{point_id}")
    lines.append(f"    a mo:Point ;")
    lines.append(f"    geo:lat {lugar['localizacion']['latitud']} ;")
    lines.append(f"    geo:long {lugar['localizacion']['longitud']} .")
    lines.append("")

output = '\n'.join(lines)

with open('docomomo_output.ttl', 'w', encoding='utf-8') as f:
    f.write(output)

print("Done! Lines written:", len(lines))

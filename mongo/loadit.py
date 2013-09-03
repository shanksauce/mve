import json

DELIM = u'\u00d8'

j = None
with open('clean_ratings.json', 'r') as f:
    j = json.loads(f.read().decode('utf8'))

with open('clean_ratings.csv', 'w') as csv:
    for o in j:
        if 'value' in o:
            if 'author_ratings' in o['value']:
                for rating in o['value']['author_ratings']:
                    csv.write('{0}{3}{1}{3}{2}\r\n'.format(o['_id'], rating['author_id'].encode('utf8'), rating['rating'], DELIM.encode('ISO-8859-1')))

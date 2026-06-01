#!/usr/bin/env python3
import http.client, json
TOKEN = 'Rqafv0BZ5D1WT26XhdL0hhccSUqyXkvkNxB52Tlpluk'
conn = http.client.HTTPConnection('localhost',8000)
headers = {'Authorization': f'Bearer {TOKEN}', 'Content-Type': 'application/json'}
conn.request('PATCH','/technician/incidents/3/status', json.dumps({'status':'on_route'}), headers)
resp=conn.getresponse()
print(resp.status)
print(resp.read().decode())

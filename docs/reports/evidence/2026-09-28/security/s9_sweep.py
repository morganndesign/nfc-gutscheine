#!/usr/bin/env python3
"""S9: tenant-isolation sweep. As tenant B owner, hit every tenant-A resource id."""
import json, subprocess, urllib.parse

BASE="http://127.0.0.1:8200"; ORIGIN="http://127.0.0.1:3000"
RA="01a0e7b4-f042-70d2-9b49-e01174ebb524"; RB="01a0e7b4-f056-701f-9403-9ee15ebb649a"
# tenant A ids
A={'card':'01a0e7b4-f160-7341-a0d4-772c29728ec8','customer':'01a0e7b4-f0d8-7094-9744-c56ad74b19f7',
   'transaction':'01a0e7b4-f7c1-72a1-8063-e504a8eee3db','device':'01a0e7ba-6aeb-714d-91bb-fedecd2c816b',
   'user':'01a0e7b4-f06a-727e-b1c5-7cafc2f94925','restaurant':RA,'token':'8acb41df-463a-4304-8501-3b4bf127c1f4','key':'card_issued'}

JAR="/tmp/audit2/security/jarOwnB.txt"; DEV="ownerBdeviceGOLDEN01"

def xsrf():
    for l in open(JAR):
        if 'XSRF-TOKEN' in l: return l.split()[-1].replace('%3D','=')
    return ''

def call(method, uri):
    # substitute params with tenant A ids
    path=uri
    for p,val in A.items():
        path=path.replace('{'+p+'}', val)
    url=BASE+'/'+path
    h=['-H','Accept: application/json','-H','Origin: '+ORIGIN,'-H','X-Device-Id: '+DEV,'-b',JAR]
    if method in ('POST','PATCH','PUT','DELETE'):
        h+=['-H','Content-Type: application/json','-H','X-XSRF-TOKEN: '+xsrf(),'-d','{}','-X',method]
    cmd=['curl','-s','-o','/tmp/audit2/security/_body.json','-w','%{http_code}']+h+[url]
    code=subprocess.run(cmd,capture_output=True,text=True).stdout.strip()
    try: body=open('/tmp/audit2/security/_body.json').read()[:120]
    except: body=''
    return code, body

routes=json.load(open('/tmp/audit2/security/routes.json'))
params=[x for x in routes if '{' in x['uri'] and x['uri'].startswith('api/v1') and 'admin' not in x['uri'] and 'public' not in x['uri']]
print(f"{'METHOD':7} {'URI':45} CODE  note")
leaks=[]
for x in params:
    m=x['method'].replace('|HEAD','').split('|')[0]
    code,body=call(m, x['uri'])
    flag=''
    if code.startswith('2'):
        flag='<<< 2xx — INSPECT for tenant A data'
        leaks.append((m,x['uri'],code,body))
    print(f"{m:7} {x['uri']:45} {code}  {flag}")
print("\n=== 2xx responses (potential leaks) ===")
for m,u,c,b in leaks:
    print(m,u,c,b)
if not leaks: print("none")

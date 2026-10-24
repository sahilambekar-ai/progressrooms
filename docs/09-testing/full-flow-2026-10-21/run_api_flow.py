"""Repeatable HTTP acceptance probe against the isolated PostgreSQL test API only.
Run from progressrooms-api with its .venv Python. No production endpoints are accepted.
"""
import asyncio, json, uuid, sys
from pathlib import Path
from datetime import datetime, timedelta, timezone
from urllib.parse import urlparse, parse_qs
import httpx
from dotenv import load_dotenv
sys.path.insert(0,str(Path.cwd()))
load_dotenv('/private/tmp/progressrooms-full-flow.env',override=True)
from app.core.database import engine, AsyncSessionLocal
from app.core.config import settings
from app.models import Base
from sqlalchemy import inspect, select
from app.models.communication import CommunicationLog

ROOT=Path(__file__).parent
RUN=datetime.now(timezone.utc).strftime('%H%M%S')
TEACHER=f'flow.teacher.{RUN}@example.com'
STUDENT=f'flow.student.{RUN}@example.com'
PRECREATED=f'flow.precreated.{RUN}@example.com'
RESULTS=[]
IDS={}
PASSWORD='FlowTestOnly2026!'
OWNER='flow.owner.20261021@example.com'
async def main():
    assert settings.DATABASE_URL.endswith(':55433/progressrooms_full_flow_test')
    async with httpx.AsyncClient(base_url='http://127.0.0.1:8006/api/v1',timeout=40) as client:
        async def call(label,method,path,actor=None,body=None,expected=(200,201)):
            r=await client.request(method,path,headers={'Authorization':'Bearer '+actor} if actor else {},json=body)
            try: data=r.json()
            except ValueError: data={'text':r.text[:300]}
            RESULTS.append({'check':label,'status':'PASS' if r.status_code in expected else 'FAIL','http_status':r.status_code,'detail':data if r.status_code not in expected else None})
            print(label,r.status_code,flush=True)
            save()
            return data
        def save():
            (ROOT/'api-results.json').write_text(json.dumps({'run_at':datetime.now(timezone.utc).isoformat(),'checks':RESULTS,'ids':IDS},indent=2,default=str))
        owner=(await call('Owner password login','POST','/auth/login',body={'email':OWNER,'password':PASSWORD}))
        ot=owner['access_token']; org=owner['user']['organization_id']; IDS['studio_id']=org; IDS['slug']=owner['user']['organization_slug']
        # Migration/schema evidence before the explicitly recorded test-only workaround.
        async with engine.connect() as conn:
            tables=await conn.run_sync(lambda c:inspect(c).get_table_names())
        missing=sorted(set(Base.metadata.tables)-set(tables))
        RESULTS.append({'check':'Fresh migrated database contains all model tables','status':'FAIL' if missing else 'PASS','missing_tables':missing})
        teacher=await call('Owner adds new teacher (no password, same as UI)','POST','/teachers',ot,{'name':'Flow Test Teacher','email':TEACHER,'phone':'+919000000102','location':'Pune','title':'Test Yoga Teacher','bio':'Synthetic acceptance-test teacher'})
        mid=teacher['id']; IDS['teacher_id']=mid; IDS['teacher_code']=teacher['teacher_code']; IDS['teacher_email']=TEACHER; IDS['student_email']=STUDENT; IDS['precreated_email']=PRECREATED
        await call('Teacher password login after invitation (expected blocker)','POST','/auth/login',body={'email':teacher['email'],'password':PASSWORD},expected=(401,))
        code=await call('Teacher requests OTP login (available workaround)','POST','/auth/request-otp',body={'email':teacher['email']})
        teacher_login=await call('Teacher verifies login OTP','POST','/auth/verify-otp',body={'email':teacher['email'],'otp':code['otp_preview']})
        tt=teacher_login['access_token']
        typ=await call('Owner creates class category','POST',f'/organizations/{org}/class-types',ot,{'name':'Acceptance Yoga','slug':'acceptance-yoga-'+RUN})
        tomorrow=(datetime.now(timezone.utc)+timedelta(days=1)).date()
        payload={'class_type_id':typ['id'],'name':'Full Flow Morning Yoga','slug':'full-flow-morning-yoga-'+RUN,'session_type':'GROUP','instructor_member_ids':[mid],'capacity':10,'duration_minutes':45,'pricing':{'pricing_type':'PACKAGE','price':500,'total_classes':5,'validity_days':30},'schedule_rules':[{'day_of_week':tomorrow.weekday(),'start_time':'09:00','end_time':'09:45','effective_start_date':str(tomorrow),'effective_end_date':str(tomorrow+timedelta(days=14))}]}
        await call('Teacher tries to create a class (role limitation)','POST',f'/organizations/{org}/classes',tt,payload,expected=(403,))
        cls=await call('Owner creates scheduled class (see recorded schema baseline/workaround)' ,'POST',f'/organizations/{org}/classes',ot,payload)
        if 'id' not in cls and missing and RESULTS[-1]['http_status']==500:
            # Do not pass off model-created tables as a successful migration.
            async with engine.begin() as conn:
                await conn.run_sync(Base.metadata.create_all)
            RESULTS.append({'check':'TEST-ONLY continuation workaround','status':'WORKAROUND','detail':'Created missing model tables in disposable database; production migrations remain unchanged and release blocker remains open.'})
            cls=await call('Owner creates class after test-only missing-table workaround','POST',f'/organizations/{org}/classes',ot,payload)
        cid=cls['id']; IDS['class_id']=cid
        await call('Owner tries to add an unregistered student','POST','/students',ot,{'email':PRECREATED,'class_id':cid},expected=(422,))
        reg=await call('New student self-registers','POST','/auth/register',body={'full_name':'Flow Test Student','email':STUDENT,'password':PASSWORD,'phone':'+919000000103','location':'Pune','role':'STUDENT','privacy_accepted':True,'privacy_policy_version':'2026-09-27'})
        stud=await call('Student verifies registration OTP','POST','/auth/verify-otp',body={'email':STUDENT,'otp':reg['otp_preview'],'purpose':'EMAIL_VERIFICATION'})
        st=stud['access_token']; IDS['student_id']=stud['user']['id']
        await call('Student password login','POST','/auth/login',body={'email':STUDENT,'password':PASSWORD})
        lookup=await call('Student searches teacher by code','GET','/teachers/public/lookup?query='+teacher['teacher_code'],st)
        profile=await call('Public teacher profile lists classes','GET','/teachers/public/'+teacher['teacher_code'])
        tier=await call('Owner creates purchasable studio pass','POST',f'/organizations/{org}/membership-tiers',ot,{'name':'Full Flow Five-Class Pass','tier_type':'PACKAGE','price':450,'total_classes':5,'validity_days':30,'class_ids':[cid]})
        IDS['pass_id']=tier['id']
        await call('Teacher tries to create a pass (role limitation)','POST',f'/organizations/{org}/membership-tiers',tt,{'name':'Teacher pass attempt','price':200},expected=(403,))
        async def buy(kind,body):
            order=await call('Student buys '+kind,'POST','/commerce/orders',st,body)
            assert order['mock'] is True
            verification={'order_id':order['order_id'],'razorpay_order_id':order['razorpay_order_id'],'razorpay_payment_id':'dev_'+uuid.UUID(order['order_id']).hex,'razorpay_signature':'development-only'}
            paid=await call('Mock '+kind+' payment activates enrollment','POST','/commerce/payments/verify',st,verification)
            await call('Repeated '+kind+' payment verification is idempotent','POST','/commerce/payments/verify',st,verification)
            return paid
        await buy('class',{'session_id':cid})
        await buy('pass',{'tier_id':tier['id']})
        await call('Student sees active purchases','GET','/student/enrollments',st)
        await call('Owner sees paid student in roster','GET','/students',ot)
        # Alternate route: pre-add is blocked; register then owner-admit, never fabricate precreation success.
        reg2=await call('Previously rejected pre-add student registers normally','POST','/auth/register',body={'full_name':'Flow Previously Unregistered Student','email':PRECREATED,'password':PASSWORD,'phone':'+919000000104','location':'Pune','role':'STUDENT','privacy_accepted':True,'privacy_policy_version':'2026-09-27'})
        await call('Second student verifies registration','POST','/auth/verify-otp',body={'email':PRECREATED,'otp':reg2['otp_preview'],'purpose':'EMAIL_VERIFICATION'})
        await call('Owner admits now-registered student','POST','/students',ot,{'email':PRECREATED,'class_id':cid,'teacher_member_id':mid})
        request=await call('Owner creates teacher Zoom connection request','POST',f'/organizations/{org}/teachers/{mid}/zoom/authorization-request',ot,{})
        request_token=parse_qs(urlparse(request['request_url']).query)['request'][0]
        authorization=await call('Teacher redeems own Zoom connection request','POST','/integrations/zoom/request',tt,{'request':request_token})
        query=parse_qs(urlparse(authorization['authorization_url']).query)
        candidate=await call('Mock Zoom callback verifies teacher identity','POST','/integrations/zoom/callback',tt,{'state':query['state'][0],'code':query['code'][0]})
        await call('Teacher confirms mock Zoom account','POST','/integrations/zoom/confirm',tt,{'confirmation_id':candidate['confirmation_id']})
        prefs=await call('Owner reads Zoom settings','GET',f'/organizations/{org}/zoom/settings',ot)
        await call('Owner enables mock meeting creation with teacher host','PUT',f'/organizations/{org}/zoom/settings',ot,{'version':prefs['version'],'default_host_member_id':mid,'auto_meeting_enabled':True,'acknowledge_impact':True})
        start=datetime.now(timezone.utc); end=start+timedelta(days=20)
        occurrences=await call('Owner reads generated class dates','GET',f'/organizations/{org}/occurrences?start_date={start.isoformat().replace("+00:00","Z")}&end_date={end.isoformat().replace("+00:00","Z")}',ot)
        occ=next(o for o in occurrences if o['session_id']==cid); IDS['occurrence_id']=occ['id']
        join=await call('Teacher obtains persisted mock Zoom meeting','POST',f'/organizations/{org}/occurrences/{occ["id"]}/join-link',tt,{})
        RESULTS.append({'check':'Teacher meeting is explicitly mock','status':'PASS' if join.get('is_simulated') else 'FAIL','detail':{k:v for k,v in join.items() if k not in ('host_url','meeting_url')}})
        again=await call('Repeat meeting lookup reuses the same join URL','POST',f'/organizations/{org}/occurrences/{occ["id"]}/join-link',tt,{})
        assert join['join_url']==again['join_url']
        await call('Student upcoming classes contain purchased class','GET','/student/upcoming-classes',st)
        save()
    await engine.dispose()
if __name__=='__main__':
    asyncio.run(main())

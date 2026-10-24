"""Exercise reminder worker, capture rendered mock messages, validate join authorization.
This intentionally calls workers directly: it does not claim a scheduler is running.
"""
import asyncio, json, sys, uuid
from pathlib import Path
from datetime import datetime,timedelta,timezone
import httpx
from dotenv import load_dotenv
sys.path.insert(0,str(Path.cwd()))
load_dotenv('/private/tmp/progressrooms-full-flow.env',override=True)
from app.core.config import settings
from app.core.database import engine,AsyncSessionLocal
from app.models.communication import CommunicationLog,ClassReminderSchedule
from app.models.commerce import Payment,SessionEnrollment
from app.models.schedule import ClassOccurrence
from app.models.organization import OrganizationStudent
from app.models.user import User
from app.modules.communication import reminder_engine
from sqlalchemy import select,func
ROOT=Path(__file__).parent
ids=json.loads((ROOT/'api-results.json').read_text())['ids']
CAPTURE=[]; CHECKS=[]
for name in list(vars(reminder_engine)):
    if name.startswith('render_'):
        original=getattr(reminder_engine,name)
        def capture(*args,_original=original,_name=name,**kwargs):
            body=_original(*args,**kwargs)
            CAPTURE.append({'template':_name,'arguments':kwargs,'body':body})
            return body
        setattr(reminder_engine,name,capture)
def check(label,passed,detail=None):
    CHECKS.append({'check':label,'status':'PASS' if passed else 'FAIL','detail':detail})
async def main():
    assert settings.DATABASE_URL.endswith(':55433/progressrooms_full_flow_test')
    org=ids['studio_id']; occid=ids['occurrence_id']
    async with AsyncSessionLocal() as db:
        occ=await db.get(ClassOccurrence,uuid.UUID(occid))
        at=occ.actual_start_at-timedelta(hours=2)
        first=await reminder_engine.dispatch_pending_reminders(db,as_of_time=at,occurrence_id=occ.id)
        await db.commit()
        repeat=await reminder_engine.dispatch_pending_reminders(db,as_of_time=at,occurrence_id=occ.id)
        await db.commit()
        check('Two-hour reminder renders eligible student and teacher notifications',first>0,first)
        check('Rerunning the same reminder does not duplicate messages',repeat==0,repeat)
        logs=(await db.scalars(select(CommunicationLog).where(CommunicationLog.organization_id==uuid.UUID(org)))).all()
        users={str(u.id):{'name':u.full_name,'role':u.role,'email':u.email} for u in (await db.scalars(select(User))).all()}
        output=[{'id':str(l.id),'recipient':users.get(str(l.recipient_user_id)),'channel':l.channel,'type':l.message_type,'status':l.status,'suppression_reason':l.suppression_reason,'preview':l.body_preview,'metadata':l.metadata_json} for l in logs]
        (ROOT/'notification-logs.json').write_text(json.dumps(output,indent=2,default=str))
        check('Payment confirmation logs exist',any(l.message_type=='PAYMENT_RECEIVED' for l in logs))
        check('No teacher invitation log exists (invitation gap)',not any('INVIT' in l.message_type for l in logs), 'Absence is a product gap, not a delivered invitation.')
        # Read-only consistency checks prove account and roster association rather than HTTP status alone.
        count=await db.scalar(select(func.count(OrganizationStudent.id)).where(OrganizationStudent.organization_id==uuid.UUID(org),OrganizationStudent.user_id==uuid.UUID(ids['student_id'])))
        check('Purchased student has exactly one studio roster identity',count==1,count)
        payments=await db.scalar(select(func.count(Payment.id)).join(SessionEnrollment,SessionEnrollment.order_id==Payment.order_id).where(SessionEnrollment.user_id==uuid.UUID(ids['student_id'])))
        check('Two verified purchases remain two payment rows after verification retries',payments==2,payments)
        second=await db.scalar(select(User).where(User.email==ids['precreated_email']))
        second_count=await db.scalar(select(func.count(OrganizationStudent.id)).where(OrganizationStudent.organization_id==uuid.UUID(org),OrganizationStudent.user_id==second.id))
        check('Register-then-admit creates one linked student identity',second_count==1,second_count)
    async with httpx.AsyncClient(base_url='http://127.0.0.1:8006/api/v1',timeout=30) as client:
        async def login(email):
            r=await client.post('/auth/login',json={'email':email,'password':'FlowTestOnly2026!'})
            assert r.status_code==200,r.text
            return {'Authorization':'Bearer '+r.json()['access_token']}
        owner=await login('flow.owner.20261021@example.com'); student=await login(ids['student_email'])
        before=await client.get(f'/student/classes/{occid}/meeting-url',headers=student)
        check('Student cannot join earlier than 15 minutes before class',before.status_code==403,before.json())
        anon=await client.get(f'/student/classes/{occid}/meeting-url')
        check('Anonymous meeting access is rejected',anon.status_code in (401,403),anon.status_code)
        start=datetime.now(timezone.utc)+timedelta(minutes=10)
        response=await client.post(f'/organizations/{org}/occurrences/{occid}/reschedule',headers=owner,json={'new_start_at':start.isoformat(),'new_end_at':(start+timedelta(minutes=45)).isoformat(),'reason':'Isolated full-flow test: open join window'})
        check('Owner can reschedule a mock-hosted class into the join window',response.status_code==200,response.json())
        joined=await client.get(f'/student/classes/{occid}/meeting-url',headers=student)
        check('Enrolled student receives mock meeting URL during join window',joined.status_code==200 and joined.json().get('is_simulated') is True,joined.json())
        if joined.status_code==200:
            target=joined.json()['meeting_url']
            check('Mock room is local and has no host start credential','localhost:3006/integrations/zoom/mock-room' in target and 'host' not in target.split('?')[-1],target)
        # Real HTTP confirms current receipt links lead to a missing page.
        async with AsyncSessionLocal() as db:
            first_order=await db.scalar(select(SessionEnrollment.order_id).where(SessionEnrollment.user_id==uuid.UUID(ids['student_id'])))
        receipt=await client.get(f'http://localhost:3006/student/receipts/{first_order}')
        check('Payment receipt destination exists',receipt.status_code==200,{'status':receipt.status_code,'path':f'/student/receipts/{first_order}'})
    # Keep the complete render separate from delivery logs; SENT is only the app's DB status.
    (ROOT/'rendered-reminders.json').write_text(json.dumps(CAPTURE,indent=2,default=str))
    (ROOT/'notification-results.json').write_text(json.dumps(CHECKS,indent=2,default=str))
    print(json.dumps(CHECKS,indent=2,default=str))
    await engine.dispose()
asyncio.run(main())

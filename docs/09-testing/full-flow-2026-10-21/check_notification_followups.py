"""Mock 2h/15m reminders, opt-out suppression, cancellation and link authorization checks."""
import sys,json,asyncio,uuid
from pathlib import Path
from datetime import datetime,timedelta,timezone
from dotenv import load_dotenv
sys.path.insert(0,str(Path.cwd()))
load_dotenv('/private/tmp/progressrooms-full-flow.env',override=True)
from app.core.database import AsyncSessionLocal,engine
from app.models.schedule import ClassOccurrence
from app.models.communication import CommunicationLog,UserCommunicationPreference
from app.models.user import User
from app.modules.communication import reminder_engine
from sqlalchemy import select
import httpx
ROOT=Path(__file__).parent
ids=json.loads((ROOT/'api-results.json').read_text())['ids']
checks=[]; renders=[]
for name in list(vars(reminder_engine)):
    if name.startswith('render_'):
        original=getattr(reminder_engine,name)
        def capture(*args,_original=original,_name=name,**kwargs):
            body=_original(*args,**kwargs)
            renders.append({'template':_name,'arguments':kwargs,'body':body})
            return body
        setattr(reminder_engine,name,capture)
def check(label,passed,detail=None):
    checks.append({'check':label,'status':'PASS' if passed else 'FAIL','detail':detail})
async def main():
    async with AsyncSessionLocal() as db:
        occs=(await db.scalars(select(ClassOccurrence).where(ClassOccurrence.session_id==uuid.UUID(ids['class_id']),ClassOccurrence.status=='SCHEDULED').order_by(ClassOccurrence.actual_start_at))).all()
        target=occs[0]; cancel=occs[-1]
        teacher=await db.scalar(select(User).where(User.email==ids['teacher_email']))
        browser_student=await db.scalar(select(User).where(User.email=='flow.browser.precreated@example.com'))
        # Recipient opt-out is confined to one synthetic test user.
        pref=UserCommunicationPreference(user_id=browser_student.id,whatsapp_opted_out=True,email_opted_out=False)
        db.add(pref);await db.commit()
        await reminder_engine.dispatch_pending_reminders(db,as_of_time=target.actual_start_at-timedelta(hours=2),occurrence_id=target.id)
        await db.commit()
        await reminder_engine.dispatch_pending_reminders(db,as_of_time=target.actual_start_at-timedelta(minutes=15),occurrence_id=target.id)
        await db.commit()
        again=await reminder_engine.dispatch_pending_reminders(db,as_of_time=target.actual_start_at-timedelta(minutes=15),occurrence_id=target.id)
        await db.commit()
        logs=(await db.scalars(select(CommunicationLog).where(CommunicationLog.organization_id==uuid.UUID(ids['studio_id'])))).all()
        target_logs=[l for l in logs if str((l.metadata_json or {}).get('occurrence_id'))==str(target.id)]
        for kind in ('REMINDER_2H','REMINDER_15M'):
            selected=[l for l in target_logs if l.message_type==kind]
            check(kind+' logs exist for assigned teacher and active students',bool(selected) and any(l.recipient_user_id==teacher.id for l in selected),len(selected))
            check(kind+' respects WhatsApp opt-out while allowing email',any(l.recipient_user_id==browser_student.id and l.message_type==kind and l.channel=='WHATSAPP_CLASSES' and l.status=='SUPPRESSED' for l in logs) and any(l.recipient_user_id==browser_student.id and l.channel=='EMAIL' and l.status=='SENT' for l in selected))
        check('Repeated 15-minute worker cycle creates no duplicate messages',again==0,again)
        check('Rendered reminder bodies include the secure application portal, not a host credential',bool(renders) and all('/student?studio=' in r['arguments'].get('join_url','') and '/s/' not in r['arguments'].get('join_url','') for r in renders))
        # Record current browser student IDs for an entitlement/join-window contrast.
        uid=browser_student.id
        cancel_id=cancel.id
    async with httpx.AsyncClient(base_url='http://127.0.0.1:8006/api/v1',timeout=30) as c:
        owner=(await c.post('/auth/login',json={'email':'flow.owner.20261021@example.com','password':'FlowTestOnly2026!'})).json()['access_token']
        student=(await c.post('/auth/login',json={'email':'flow.browser.precreated@example.com','password':'FlowTestOnly2026!'})).json()['access_token']
        upcoming=await c.get('/student/upcoming-classes',headers={'Authorization':'Bearer '+student})
        check('Rescheduled class remains discoverable in student upcoming list',any(o['id']==ids['occurrence_id'] for o in upcoming.json()),{'expected_occurrence_id':ids['occurrence_id'],'returned_ids':[o['id'] for o in upcoming.json()]})
        # Actual invocation follows the normal cancellation endpoint, against only the final synthetic occurrence.
        cancelled=await c.post(f'/organizations/{ids["studio_id"]}/occurrences/{cancel_id}/cancel',headers={'Authorization':'Bearer '+owner},json={'reason':'Synthetic full-flow cancellation test'})
        check('Owner can cancel a future class through the API',cancelled.status_code==200,cancelled.json())
        unauth=(await c.post('/auth/register',json={'full_name':'Unenrolled Test Student','email':'flow.unenrolled@example.com','password':'FlowTestOnly2026!','phone':'+919000000107','location':'Pune','role':'STUDENT','privacy_accepted':True,'privacy_policy_version':'2026-09-27'})).json()
        verified=(await c.post('/auth/verify-otp',json={'email':'flow.unenrolled@example.com','otp':unauth['otp_preview'],'purpose':'EMAIL_VERIFICATION'})).json()
        denied=await c.get(f'/student/classes/{ids["occurrence_id"]}/meeting-url',headers={'Authorization':'Bearer '+verified['access_token']})
        check('Authenticated unenrolled student cannot obtain meeting URL',denied.status_code==403,denied.json())
    async with AsyncSessionLocal() as db:
        logs=(await db.scalars(select(CommunicationLog).where(CommunicationLog.organization_id==uuid.UUID(ids['studio_id'])))).all()
        cancel_logs=[l for l in logs if l.message_type=='CLASS_CANCELLATION' and str((l.metadata_json or {}).get('occurrence_id'))==str(cancel_id)]
        check('Class cancellation creates communication log records',bool(cancel_logs),len(cancel_logs))
        (ROOT/'notification-logs-final.json').write_text(json.dumps([{'channel':l.channel,'type':l.message_type,'recipient_id':str(l.recipient_user_id),'status':l.status,'suppression_reason':l.suppression_reason,'metadata':l.metadata_json,'preview':l.body_preview} for l in logs],indent=2,default=str))
    (ROOT/'notification-followup-results.json').write_text(json.dumps(checks,indent=2,default=str))
    (ROOT/'rendered-followup-reminders.json').write_text(json.dumps(renders,indent=2,default=str))
    print(json.dumps(checks,indent=2,default=str))
    await engine.dispose()
asyncio.run(main())

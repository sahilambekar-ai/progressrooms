"""Read-only DB and HTTP verification of records created through the browser."""
import sys,asyncio,json
from pathlib import Path
from dotenv import load_dotenv
sys.path.insert(0,str(Path.cwd()))
load_dotenv('/private/tmp/progressrooms-full-flow.env',override=True)
from app.core.database import engine,AsyncSessionLocal
from app.models.user import User
from app.models.organization import OrganizationStudent
from app.models.session import Session,SessionPricing
from app.models.membership_tier import MembershipTier
from app.models.commerce import SessionEnrollment,Payment,Order
from sqlalchemy import select,func
import httpx
ROOT=Path(__file__).parent
checks=[]
def check(label,passed,detail=None): checks.append({'check':label,'status':'PASS' if passed else 'FAIL','detail':detail})
async def main():
    async with AsyncSessionLocal() as db:
        student=await db.scalar(select(User).where(User.email=='flow.browser.precreated@example.com'))
        cls=await db.scalar(select(Session).where(Session.name=='Browser Created Yoga'))
        tier=await db.scalar(select(MembershipTier).where(MembershipTier.name=='Browser Created Practice Pass'))
        pricing=await db.scalar(select(SessionPricing).where(SessionPricing.session_id==cls.id))
        check('Browser-created class is active and has a one-session ₹100 package',cls.is_active and len(pricing.packages)==1 and pricing.packages[0]['total_classes']==1 and float(pricing.packages[0]['price'])==100)
        check('Browser-created pass includes that class package and one credit',tier.is_active and tier.total_classes==1 and any(x['session_id']==str(cls.id) for x in tier.class_packages),{'price':str(tier.price),'credits':tier.total_classes})
        count=await db.scalar(select(func.count(User.id)).where(User.email==student.email))
        roster=await db.scalar(select(func.count(OrganizationStudent.id)).where(OrganizationStudent.user_id==student.id,OrganizationStudent.organization_id==cls.organization_id))
        check('Student registration and owner admission retain one user and one roster identity',count==1 and roster==1,{'users':count,'studio_roster_records':roster})
        enrollment=await db.scalar(select(SessionEnrollment).where(SessionEnrollment.user_id==student.id,SessionEnrollment.session_id==cls.id))
        check('UI owner admission creates an active enrollment without inventing a payment',enrollment.status=='ACTIVE' and enrollment.order_id is None)
        orders=(await db.scalars(select(Order).where(Order.user_id==student.id))).all()
        check('Browser class and pass purchases persist two paid orders',len(orders)==2 and all(o.status=='PAID' for o in orders),{'count':len(orders),'amounts':[str(o.total_amount) for o in orders]})
        payments=(await db.scalars(select(Payment).join(Order).where(Order.user_id==student.id))).all()
        check('Browser payments are all explicitly MOCK',len(payments)==2 and all(p.payment_provider=='MOCK' for p in payments))
    async with httpx.AsyncClient(base_url='http://127.0.0.1:8006/api/v1') as c:
        signed=(await c.post('/auth/login',json={'email':'flow.browser.precreated@example.com','password':'FlowTestOnly2026!'})).json()
        h={'Authorization':'Bearer '+signed['access_token']}
        upcoming=(await c.get('/student/upcoming-classes',headers=h)).json()
        check('Owner-admitted browser class appears in student upcoming classes',any(x['session_name']==cls.name for x in upcoming))
        profile=(await c.get('/teachers/public/37537166')).json()
        classes=[x for studio in profile['studios'] for x in studio['classes']]
        passes=[x for studio in profile['studios'] for x in studio['passes']]
        check('Browser-created class and pass are discoverable through their teacher code',any(x['id']==str(cls.id) for x in classes) and any(x['id']==str(tier.id) for x in passes))
    (ROOT/'browser-record-results.json').write_text(json.dumps(checks,indent=2,default=str))
    print(json.dumps(checks,indent=2,default=str))
    await engine.dispose()
asyncio.run(main())

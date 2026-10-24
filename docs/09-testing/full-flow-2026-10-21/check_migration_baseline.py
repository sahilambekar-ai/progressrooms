"""Run migrations on a fresh disposable probe database and exercise communications unchanged."""
import sys,asyncio,json,os
from pathlib import Path
from dotenv import load_dotenv
load_dotenv('/private/tmp/progressrooms-full-flow.env',override=True)
os.environ['DATABASE_URL']='postgresql+asyncpg://sahil@127.0.0.1:55433/progressrooms_migration_probe_test'
os.environ['SYNC_DATABASE_URL']='postgresql://sahil@127.0.0.1:55433/progressrooms_migration_probe_test'
sys.path.insert(0,str(Path.cwd()))
from alembic import command
from alembic.config import Config
command.upgrade(Config('alembic.ini'),'head')
from app.core.database import AsyncSessionLocal,engine
from app.modules.communication.service import get_or_create_settings
async def main():
    async with AsyncSessionLocal() as db:
        try:
            await get_or_create_settings(db)
            result={'status':'PASS'}
        except Exception as exc:
            result={'status':'FAIL','error_type':type(exc).__name__,'error':str(exc).split('[SQL:')[0].strip(),'detail':'Fresh alembic upgrade head; no metadata.create_all workaround used in this probe.'}
    Path(__file__).with_name('migration-runtime-result.json').write_text(json.dumps(result,indent=2))
    print(result)
    await engine.dispose()
asyncio.run(main())

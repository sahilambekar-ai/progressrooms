"""Local-only instrumented API. Run from progressrooms-api; never deploy this file."""
import os
import sys
import json
from pathlib import Path
from datetime import datetime, timezone
from dotenv import load_dotenv

sys.path.insert(0, str(Path.cwd()))
load_dotenv('/private/tmp/progressrooms-full-flow.env', override=True)
assert os.environ['APP_ENV'] == 'test'
assert os.environ['DATABASE_URL'].endswith(':55433/progressrooms_full_flow_test')
from app.core.config import settings
assert not settings.BREVO_ENABLED and settings.ZOOM_PROVIDER_MODE == 'mock'
assert settings.RAZORPAY_KEY_ID == 'rzp_test_mock_progressrooms'
from app.modules.auth import service
OUTBOX = Path('/private/tmp/progressrooms-full-flow-outbox.jsonl')
async def capture_otp(**payload):
    with OUTBOX.open('a') as stream:
        stream.write(json.dumps({'captured_at': datetime.now(timezone.utc).isoformat(), 'kind': 'OTP', **payload}) + '\n')
    OUTBOX.chmod(0o600)
    return {'success': True, 'simulated': True}
service.send_otp_email = capture_otp
# Capture complete rendered notifications, including URLs beyond the DB preview limit.
from app.modules.communication import reminder_engine, billing_engine
for module in (reminder_engine, billing_engine):
    for name in list(vars(module)):
        if name.startswith('render_'):
            original = getattr(module, name)
            def capture(*args, _original=original, _name=name, **kwargs):
                body = _original(*args, **kwargs)
                with OUTBOX.open('a') as stream:
                    stream.write(json.dumps({'kind': 'RENDERED_NOTIFICATION', 'template': _name, 'arguments': kwargs, 'body': body}, default=str) + '\n')
                OUTBOX.chmod(0o600)
                return body
            setattr(module, name, capture)
import uvicorn
uvicorn.run('app.main:app', host='127.0.0.1', port=8006, access_log=True)

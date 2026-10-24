"""Generate local-only mock credentials; never overwrite a running test environment."""
from pathlib import Path
from cryptography.fernet import Fernet
p=Path('/private/tmp/progressrooms-full-flow.env')
if p.exists():
    raise SystemExit('Existing test environment preserved: ' + str(p))
p.write_text('\n'.join([
'APP_ENV=test','AUTH_SHOW_OTP_PREVIEW=true','DEV_TEST_LOGIN_ENABLED=true',
'DATABASE_URL=postgresql+asyncpg://sahil@127.0.0.1:55433/progressrooms_full_flow_test',
'SYNC_DATABASE_URL=postgresql://sahil@127.0.0.1:55433/progressrooms_full_flow_test',
'BREVO_ENABLED=false','BREVO_API_KEY=','RAZORPAY_KEY_ID=rzp_test_mock_progressrooms','RAZORPAY_KEY_SECRET=rzp_secret_mock_progressrooms','RAZORPAY_WEBHOOK_SECRET=rzp_webhook_secret_mock',
'ZOOM_PROVIDER_MODE=mock','ZOOM_CLIENT_ID=mock-full-flow','ZOOM_CLIENT_SECRET=mock-full-flow-secret', 'ZOOM_TOKEN_ENCRYPTION_KEY='+Fernet.generate_key().decode(),'ZOOM_WEBHOOK_SECRET=mock-full-flow-webhook',
'ZOOM_REDIRECT_URI=http://localhost:3006/integrations/zoom/callback','WEBSITE_PUBLIC_ORIGIN=http://localhost:3006','BACKEND_CORS_ORIGINS=["http://localhost:3006"]',
'SECRET_KEY=full-flow-test-only-local-auth-secret-not-for-deployment','']) )
p.chmod(0o600)

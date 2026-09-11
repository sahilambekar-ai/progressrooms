# Dependency baseline

Verified on **2026-09-09** against official release notes and live npm/PyPI metadata. The selection uses stable previous feature lines, with security and maintenance patches retained. Every application dependency must be pinned exactly, and lockfiles must be committed. A version being older is not evidence that it is safer.

## Runtime and frontend

| Component | Selected pin | Reason / evidence |
| --- | --- | --- |
| Python | `3.13.15` | Previous feature series; official maintenance release dated 2026-08-05. [Python release](https://www.python.org/downloads/release/python-31315/) |
| Node.js | `22.23.2` for containers and CI; installed Node `24.16.0` may build locally | Previous LTS series, released 2026-07-28; Next's engine range permits Node >=20. [Official release index](https://nodejs.org/dist/index.json) |
| Next.js | `15.5.25` | Maintenance LTS; current major is 16. Includes the August 2026 security fixes. [Release](https://github.com/vercel/next.js/releases/tag/v15.5.25), [registry metadata](https://registry.npmjs.org/next/15.5.25) |
| React / React DOM | `19.1.9` / `19.1.9` | Previous minor series; satisfies Next 15's React peer dependency. [React metadata](https://registry.npmjs.org/react/19.1.9), [React DOM metadata](https://registry.npmjs.org/react-dom/19.1.9) |
| TypeScript | `5.9.3` | Stable established series; registry latest is 7.0.2. [Metadata](https://registry.npmjs.org/typescript/5.9.3) |
| PostCSS override | `8.5.23` | Patched transitive Next dependency; npm audit is clean. [Maintainer advisory](https://github.com/postcss/postcss/security/advisories/GHSA-fxqj-rqcc-2cmp) |
| Biome | `2.4.16` | Prior minor; formatter and lint checks. [Official release](https://github.com/biomejs/biome/releases/tag/@biomejs%2Fbiome@2.4.16) |
| React types / React DOM types | `19.1.17` / `19.1.11` | Types aligned with React 19.1. [React types metadata](https://registry.npmjs.org/@types/react/19.1.17), [React DOM types metadata](https://registry.npmjs.org/@types/react-dom/19.1.11) |
| Node types | `22.20.1` | Types aligned with deployment runtime family. [Metadata](https://registry.npmjs.org/@types/node/22.20.1) |

Next 15's maintenance window ends approximately **2026-10-21**, inferred from its 2024-10-21 first release and the official two-year policy. Keep a Next upgrade review in the delivery backlog before that date. Next 14 is already unsupported. [Next support policy](https://nextjs.org/support-policy)

Do not use Next 15.5.23 or earlier: the August release fixed critical vulnerabilities in image optimization and certain Windows deployments. [August security release](https://nextjs.org/blog/august-2026-security-release)

Biome is selected because `eslint-config-next@15.5.25` only accepts ESLint 7–9, and ESLint 9 reached upstream end of life on 2026-08-06. Biome's previous minor is a deliberate stable pin, without claiming an LTS guarantee. Use TypeScript's own compiler for type checking and avoid experimental Biome options. [ESLint support policy](https://eslint.org/version-support/), [Biome 2.4 release](https://biomejs.dev/blog/biome-v2-4/)

Optional UI packages, only if needed: `lucide-react==0.577.0` in npm's exact-version syntax (`"0.577.0"`), `clsx==2.1.0`, and `zod==3.25.76`. All exist in the official registry. Avoid adding unused packages.

## Backend

| Package | Exact pin | Registry evidence |
| --- | --- | --- |
| FastAPI | `0.140.13` | [PyPI](https://pypi.org/pypi/fastapi/0.140.13/json) |
| Starlette (resolution constraint / lock) | `1.5.1` | [PyPI](https://pypi.org/pypi/starlette/1.5.1/json) |
| Pydantic | `2.12.5` | [PyPI](https://pypi.org/pypi/pydantic/2.12.5/json) |
| pydantic-settings | `2.14.2` | [PyPI](https://pypi.org/pypi/pydantic-settings/2.14.2/json) |
| SQLAlchemy (with `asyncio` extra) | `2.0.51` | [PyPI](https://pypi.org/pypi/sqlalchemy/2.0.51/json) |
| asyncpg | `0.30.0` | [PyPI](https://pypi.org/pypi/asyncpg/0.30.0/json) |
| Alembic | `1.18.5` | [PyPI](https://pypi.org/pypi/alembic/1.18.5/json) |
| Uvicorn (with `standard` extra) | `0.51.0` | [PyPI](https://pypi.org/pypi/uvicorn/0.51.0/json) |
| HTTPX | `0.27.2` | [PyPI](https://pypi.org/pypi/httpx/0.27.2/json) |
| email-validator | `2.2.0` | [PyPI](https://pypi.org/pypi/email-validator/2.2.0/json) |
| pytest | `9.0.3` | [PyPI](https://pypi.org/pypi/pytest/9.0.3/json) |
| pytest-asyncio | `1.3.0` | [PyPI](https://pypi.org/pypi/pytest-asyncio/1.3.0/json) |
| Ruff | `0.15.22` | [PyPI](https://pypi.org/pypi/ruff/0.15.22/json) |

These Python package versions are released, not yanked, compatible at their declared dependency boundaries with Python 3.13, and have no vulnerabilities listed in their PyPI version metadata at verification time. This metadata check does not establish that a package has no undiscovered flaws. The installation resolver, lockfile audit, and application tests remain required.

FastAPI `0.140.13` is the previous stable feature series; latest is `0.141.1`. Its metadata permits Starlette >=0.46.0 and Pydantic >=2.9.0, so the selected pins satisfy the framework. FastAPI does not advertise an old-version LTS policy; pin, test, and review updates routinely. Starlette is preferably a locked transitive dependency or resolver constraint, consistent with FastAPI's versioning guidance. [FastAPI releases](https://fastapi.tiangolo.com/release-notes/), [versioning guidance](https://fastapi.tiangolo.com/deployment/versions/)

Use `SQLAlchemy[asyncio]` to ensure greenlet is installed on ARM macOS as well as Linux. `asyncpg==0.30.0` supports Python 3.13; do not use the host's Python 3.14 for this baseline.

Authentication uses revocable opaque bearer tokens stored as hashes, so **PyJWT is not required**. Its older releases include published 2026 advisories fixed in `2.13.0`; do not add an older PyJWT pin merely to satisfy a non-latest preference. [Maintainer advisory](https://github.com/jpadilla/pyjwt/security/advisories/GHSA-xgmm-8j9v-c9wx)

Do not substitute pytest `8.4.2`: published temporary-directory vulnerability metadata identifies the fix as `9.0.3`. The selected `9.0.3` remains below current `9.1.1`. [Older pytest metadata](https://pypi.org/pypi/pytest/8.4.2/json)

Optional later-stage Python packages, checked with no version-level PyPI advisories: `redis==7.4.1`, `python-multipart==0.0.31`, `pwdlib[argon2]==0.3.0`, `argon2-cffi==23.1.0`, and `aiosqlite==0.21.0`. Add only for implemented functionality. Production persistence and integration tests should use PostgreSQL.

## Upgrade and verification policy

1. Commit exact direct pins and resolved `package-lock.json` / `uv.lock` files.
2. Resolve and test updates in isolation; exclude prereleases and floating `latest` tags.
3. Accept security patches within the selected feature line promptly.
4. Run frontend type checking, lint checks, and a production build; run API tests against the actual PostgreSQL model and migrations.
5. Recheck support windows and vulnerabilities before a public deployment. Review Next 15 before October 2026.

The implemented frontend uses native shared CSS rather than adding Tailwind/Autoprefixer. PostCSS 8.5.23 is an exact npm override because the Next 15 default resolution carried advisories. This keeps the requested prior Next major and a patched CSS processor; verified npm audit returned zero advisories.

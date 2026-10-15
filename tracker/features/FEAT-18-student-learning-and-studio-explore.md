# FEAT-18 — Student learning view and studio Explore selector

## Behavior

The student dashboard defaults to **My classes & passes**. A forest-green summary card above the two tabs highlights the first live or upcoming enrolled class, its studio, teacher, date/time, and join action. Joining unlocks 15 minutes before the class and remains available until its end. Classes already in progress remain in the API response. Empty states reflect real scheduling data.

The first tab contains upcoming classes and existing memberships/passes, including staff-assigned enrollments. **Explore classes & passes** is the second tab. Its top-right Studio dropdown switches the embedded catalog between the student's connected active studios. Solo-teacher studios use the same selection model.

A studio connection may come from an active staff-created student assignment or any existing enrollment. No purchase is required for an assigned studio to appear. Unrelated, inactive, and deleted studios are excluded. Selecting a studio fetches its public catalog with cancelled stale requests; its classes and passes reuse the existing checkout. Studio and purchase selection survive login or reload through `/student?studio=...&kind=...&buy=...`.

## Files

- Web: `src/app/(student)/student/page.tsx`, `src/components/StudioExplore.tsx`.
- API: `app/modules/student/router.py`: authenticated `GET /student/studios`; ongoing classes included in upcoming query.
- Tests: `tests/test_storefront.py`: assigned and enrolled studio selection, other-user isolation, inactive studio exclusion, login requirement, and ongoing-class visibility after start.

## Validation

Seven storefront tests passed, including the two new regression tests. TypeScript and production build verified. Browser checked the two tabs, top card, assigned memberships, embedded Explore catalog and top-right Studio selector for the current local student.

## Manual checks

1. Sign in as a student who has an active scheduled enrollment. `/student` should open the first tab and show the next class above the tabs; the join button opens 15 minutes before class.
2. Revisit while that class is live. It should remain the top card until its end; the server validates access when joining.
3. Connect the student to two active studios using staff assignment or enrollment. Open the second tab; select each studio in the top-right dropdown and confirm only its offerings appear.
4. Buy a pass from the selected studio. Verify the purchase review, login recovery when applicable, and the resulting purchase in the first tab.
5. Students without a scheduled class see an honest empty state; students with no connected studios receive instructions to obtain a studio link.

No database migration is required.
